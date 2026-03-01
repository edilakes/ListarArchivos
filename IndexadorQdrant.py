import os
import glob
import yaml
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_huggingface import HuggingFaceEndpointEmbeddings
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
import uuid
import time

# Configuración
QDRANT_URL = "http://194.61.28.46:6333"
QDRANT_API_KEY = "Qdrant.09"
COLLECTION_NAME = "doctrina_itheca"
MARKDOWN_DIR = r"e:\OneDrive\MiCodigo\GitHub\ListarArchivos\Markdown"
TEI_API_URL = "http://194.61.28.46:8080"
VECTOR_SIZE = 1024
BATCH_SIZE_POINTS = 100 # Número de vectores por cada envío a Qdrant

def parse_markdown_with_frontmatter(filepath):
    """Lee un archivo Markdown generado y separa el Frontmatter del contenido."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error leyendo {filepath}: {e}")
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

def get_markdown_files(directory):
    """Obtiene todos los archivos markdown de forma recursiva."""
    files = []
    for root, _, filenames in os.walk(directory):
        for filename in filenames:
            if filename.endswith(".md"):
                files.append(os.path.join(root, filename))
    return files

def main():
    print(f"--- Iniciando CARGA MASIVA en Qdrant ---")
    
    # 1. Configurar Embeddings
    embeddings_model = HuggingFaceEndpointEmbeddings(model=TEI_API_URL)
    
    # 2. Conectar a Qdrant
    client = QdrantClient(url=QDRANT_URL, api_key=QDRANT_API_KEY)
    
    # 3. Resetear colección (Eliminar y crear)
    if client.collection_exists(collection_name=COLLECTION_NAME):
        print(f"Borrando colección existente '{COLLECTION_NAME}' para limpieza total...")
        client.delete_collection(collection_name=COLLECTION_NAME)
    
    print(f"Creando nueva colección '{COLLECTION_NAME}'...")
    client.create_collection(
        collection_name=COLLECTION_NAME,
        vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE),
    )

    # 4. Obtener archivos
    files = get_markdown_files(MARKDOWN_DIR)
    total_files = len(files)
    print(f"Archivos totales a procesar: {total_files}")

    # 5. Configurar Chunking
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=1000,
        chunk_overlap=200,
        add_start_index=True,
    )

    # 6. Procesar e Indexar por lotes
    points = []
    total_chunks = 0
    start_time = time.time()

    for idx, filepath in enumerate(files, 1):
        text, metadata = parse_markdown_with_frontmatter(filepath)
        if not text: continue
        
        chunks = text_splitter.split_text(text)
        
        for i, chunk in enumerate(chunks):
            passage_text = f"passage: {chunk}"
            
            # Generar vector (vía API TEI remota)
            try:
                vector = embeddings_model.embed_query(passage_text)
            except Exception as e:
                print(f"Error generando embedding para {filepath}: {e}")
                continue
            
            # Preparar punto
            chunk_meta = metadata.copy()
            chunk_meta["chunk_index"] = i
            chunk_meta["text"] = chunk
            chunk_meta["source_file"] = os.path.basename(filepath)
            
            points.append(PointStruct(id=str(uuid.uuid4()), vector=vector, payload=chunk_meta))
            total_chunks += 1

            # Si alcanzamos el tamaño del lote, subir a Qdrant
            if len(points) >= BATCH_SIZE_POINTS:
                client.upsert(collection_name=COLLECTION_NAME, points=points)
                points = []
        
        if idx % 50 == 0:
            elapsed = time.time() - start_time
            print(f"[{idx}/{total_files}] Archivos procesados... ({total_chunks} chunks indexados). Tiempo: {elapsed:.2f}s")

    # Subir puntos restantes
    if points:
        client.upsert(collection_name=COLLECTION_NAME, points=points)
        
    print(f"\n--- CARGA MASIVA COMPLETADA ---")
    print(f"Total archivos: {total_files}")
    print(f"Total chunks en Qdrant: {total_chunks}")
    print(f"Tiempo total: {time.time() - start_time:.2f}s")

if __name__ == "__main__":
    main()
