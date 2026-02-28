import os
import glob
import yaml
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_huggingface import HuggingFaceEndpointEmbeddings
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
import uuid

# Configuración
QDRANT_URL = "http://194.61.28.46:6333"
QDRANT_API_KEY = "Qdrant.09"
COLLECTION_NAME = "doctrina_itheca"
MARKDOWN_DIR = r"e:\OneDrive\MiCodigo\GitHub\ListarArchivos\Markdown"
TEI_API_URL = "http://194.61.28.46:8080" # URL de la API de TEI en el servidor
VECTOR_SIZE = 1024 # Tamaño del vector para multilingual-e5-large

def parse_markdown_with_frontmatter(filepath):
    """
    Lee un archivo Markdown generado y separa el Frontmatter del contenido.
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Separar frontmatter
    metadata = {}
    text_content = content
    
    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            try:
                metadata = yaml.safe_load(parts[1])
            except Exception as e:
                print(f"Error parseando yaml en {filepath}: {e}")
            text_content = parts[2].strip()
            
    return text_content, metadata

def get_markdown_files(directory, limit=50):
    """
    Obtiene una lista de archivos markdown limitando a un número para la PoC.
    """
    files = []
    # Usar .rglob o walk para buscar recursivamente
    for root, _, filenames in os.walk(directory):
        for filename in filenames:
            if filename.endswith(".md"):
                files.append(os.path.join(root, filename))
                if len(files) >= limit:
                    return files
    return files

def main():
    print(f"--- Iniciando PoC Qdrant con API TEI remota ---")
    
    # 1. Conectar al Endpoint de Embeddings (TEI)
    print(f"Conectando a la API de Embeddings (TEI) en {TEI_API_URL}...")
    embeddings_model = HuggingFaceEndpointEmbeddings(model=TEI_API_URL)
    print("Conexión con la API TEI configurada.")

    # 2. Conectar a Qdrant
    print(f"Conectando a Qdrant en {QDRANT_URL}...")
    client = QdrantClient(url=QDRANT_URL, api_key=QDRANT_API_KEY)
    
    # 3. Crear colección si no existe
    if not client.collection_exists(collection_name=COLLECTION_NAME):
        print(f"Creando colección {COLLECTION_NAME}...")
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE),
        )
    else:
        print(f"La colección {COLLECTION_NAME} ya existe. Se agregarán los documentos.")

    # 4. Leer archivos (PoC: 5 archivos)
    files = get_markdown_files(MARKDOWN_DIR, limit=5)
    print(f"Archivos encontrados para PoC: {len(files)}")
    if not files:
        print("No se encontraron archivos en la carpeta Markdown. Ejecuta el parser primero.")
        return

    # 5. Configurar Chunking
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=1000,
        chunk_overlap=200,
        add_start_index=True,
    )

    # 6. Procesar e Indexar
    points = []
    for filepath in files:
        text, metadata = parse_markdown_with_frontmatter(filepath)
        
        # El modelo 'intfloat/multilingual-e5-large' recomienda prefijar los textos
        # con "passage: " para los documentos a indexar y "query: " para las búsquedas.
        
        chunks = text_splitter.split_text(text)
        print(f"  Procesando {os.path.basename(filepath)} -> {len(chunks)} chunks")
        
        for i, chunk in enumerate(chunks):
            # Formatear el texto para e5-large
            passage_text = f"passage: {chunk}"
            
            # Generar vector
            vector = embeddings_model.embed_query(passage_text)
            
            # Metadatos del chunk
            chunk_meta = metadata.copy()
            chunk_meta["chunk_index"] = i
            chunk_meta["text"] = chunk # Guardamos el texto original sin el prefijo passage
            chunk_meta["source_file"] = os.path.basename(filepath)
            
            point_id = str(uuid.uuid4())
            points.append(
                PointStruct(id=point_id, vector=vector, payload=chunk_meta)
            )
            
    # 7. Subir a Qdrant (en lotes pequeños es mejor, aquí mandamos todos si son pocos)
    if points:
        print(f"Subiendo {len(points)} vectores a Qdrant...")
        client.upsert(
            collection_name=COLLECTION_NAME,
            points=points
        )
        print("¡Indexación completada con éxito!")
    else:
        print("No se generaron puntos para indexar.")

if __name__ == "__main__":
    main()
