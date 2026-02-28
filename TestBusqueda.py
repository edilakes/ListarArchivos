import sys
import yaml
from langchain_huggingface import HuggingFaceEndpointEmbeddings
from qdrant_client import QdrantClient

# Configuración
QDRANT_URL = "http://194.61.28.46:6333"
QDRANT_API_KEY = "Qdrant.09"
COLLECTION_NAME = "doctrina_itheca"
TEI_API_URL = "http://194.61.28.46:8080" # URL de la API de TEI en el servidor

def main():
    if len(sys.argv) > 1:
        query_text = " ".join(sys.argv[1:])
    else:
        query_text = "¿Cuál es la importancia del conocimiento propio para la humildad?"

    print(f"\n--- Búsqueda RAG en Itheca ---")
    print(f"Pregunta: '{query_text}'\n")

    # 1. Cargar modelo 
    print(f"Conectando a la API de Embeddings (TEI) en {TEI_API_URL}...")
    embeddings_model = HuggingFaceEndpointEmbeddings(model=TEI_API_URL)

    # 2. Conectar a Qdrant
    print("Conectando a Qdrant...")
    client = QdrantClient(url=QDRANT_URL, api_key=QDRANT_API_KEY)

    # 3. Vectorizar pregunta 
    # El modelo e5 requiere el prefijo "query: " para las búsquedas
    formatted_query = f"query: {query_text}"
    query_vector = embeddings_model.embed_query(formatted_query)

    # 4. Buscar en Qdrant
    print("Buscando en la base de conocimiento...\n")
    search_result = client.query_points(
        collection_name=COLLECTION_NAME,
        query=query_vector,
        limit=3 # Top 3 resultados
    ).points

    if not search_result:
        print("No se encontraron resultados.")
        return

    # 5. Mostrar resultados
    print("="*60)
    for i, hit in enumerate(search_result, 1):
        score = hit.score
        payload = hit.payload
        
        titulo = payload.get('title', 'Sin título')
        origen = payload.get('url_origen', 'Origen desconocido')
        texto = payload.get('text', '')[0:300] + "..." # Mostrar solo un extracto
        
        print(f"RESULTADO {i} (Afinidad: {score:.4f})")
        print(f"Documento: {titulo}")
        print(f"URL Origen: {origen}")
        print(f"Extracto:\n{texto}")
        print("-" * 60)

if __name__ == "__main__":
    main()
