import os
import yaml
from pymongo import MongoClient, UpdateOne
from datetime import datetime, timezone
import sys

# Configuración
MONGO_URI = "mongodb://edilakes:Mongodb.09@194.61.28.46:27017/"
DB_NAME = "itheca"
COLLECTION_NAME = "knowledge_base"
MARKDOWN_DIR = r"e:\OneDrive\MiCodigo\GitHub\ListarArchivos\Markdown"

def parse_markdown(filepath):
    """Separa el frontmatter del contenido."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error leyendo archivo {filepath}: {e}")
        return "", {}
    
    metadata = {}
    text_content = content
    
    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            try:
                metadata = yaml.safe_load(parts[1])
            except Exception:
                pass
            text_content = parts[2].strip()
            
    return text_content, metadata

def run_migration():
    try:
        client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        db = client[DB_NAME]
        collection = db[COLLECTION_NAME]
        
        # Verificar conexión
        client.admin.command('ping')
        
        # Limpieza de índices antiguos/erróneos
        indexes = collection.index_information()
        if "metadata.url_source_1" in indexes:
            print("Eliminando índice antiguo metadata.url_source_1...")
            collection.drop_index("metadata.url_source_1")
        
        # Crear índices correctos
        collection.create_index("metadata.root_folder")
        collection.create_index("metadata.url_origen", unique=True)
        
        print(f"--- Iniciando migración a MongoDB ({DB_NAME}.{COLLECTION_NAME}) ---")
        
        batch = []
        total_count = 0
        files_processed = 0
        
        for root, _, files in os.walk(MARKDOWN_DIR):
            for file in files:
                if not file.endswith(".md"):
                    continue
                
                filepath = os.path.join(root, file)
                relative_path = os.path.relpath(filepath, MARKDOWN_DIR)
                path_parts = relative_path.split(os.sep)
                root_folder = path_parts[0] if len(path_parts) > 1 else "root"
                
                content, metadata = parse_markdown(filepath)
                if not content and not metadata:
                    continue
                
                # Enriquecer metadatos
                metadata["root_folder"] = root_folder
                metadata["file_path"] = relative_path
                metadata["last_updated"] = datetime.now(timezone.utc)
                
                doc = {
                    "content": content,
                    "metadata": metadata
                }
                
                # Usar url_origen como identificador único
                url_id = metadata.get("url_origen", filepath)
                batch.append(UpdateOne(
                    {"metadata.url_origen": url_id},
                    {"$set": doc},
                    upsert=True
                ))
                
                files_processed += 1
                
                if len(batch) >= 500:
                    collection.bulk_write(batch, ordered=False)
                    total_count += len(batch)
                    print(f"Documentos subidos: {total_count}...")
                    batch = []

        if batch:
            collection.bulk_write(batch, ordered=False)
            total_count += len(batch)
            
        print(f"--- Migración finalizada con éxito ---")
        print(f"Total archivos escaneados: {files_processed}")
        print(f"Total documentos en DB (upserts): {total_count}")
        client.close()
    except Exception as e:
        print(f"ERROR FATAL en la migración: {e}")
        sys.exit(1)

if __name__ == "__main__":
    run_migration()
