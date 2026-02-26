# Propuesta de Arquitectura RAG: Dominio Itheca

## 1. Visión General (Arquitectura de Microservicios)
El objetivo es transformar el dominio `app.itheca.org` en una base de datos vectorial centralizada y agnóstica. En lugar de acoplar el conocimiento a un solo agente, crearemos un **Motor de Conocimiento Independiente** basado en **Qdrant**.
Esto permitirá que múltiples clientes consuman la misma base de datos de forma simultánea:
1.  **Agente InteractIA (Cerebro):** A través de una herramienta (Tool) personalizada.
2.  **Agente N8N:** A través de sus nodos nativos de Qdrant para automatizaciones de flujos de trabajo (bots de Telegram, respuestas por email, etc.).

## 2. Estrategia de Ingesta Dual (Online + Fallback Local)
Para garantizar resiliencia y que el sistema RAG posea siempre la versión original de Itheca, el pipeline de extracción de datos funcionará con una estrategia dual:
*   **Prioridad 1 (Scraping en Vivo):** Al procesar el listado de `valid_links.txt`, el script (ej. en PowerShell o Python) intentará leer el contenido directamente de la web en vivo (`https://app.itheca.org/...`). La URL web original será la **Llave Primaria** y el metadato más importante de un documento.
*   **Prioridad 2 (Fallback Local):** Si la web falla (Error 404, 500, o timeout de red), el script interceptará la excepción y construirá la ruta local equivalente (ej. `C:\Ruta\Descargas\biblioteca\doc.html`). Leerá el archivo local físico, garantizando que el texto se procese, pero mantendrá la URL web original como "Origen" para que las citas del agente sigan apuntando al servidor de Itheca.

## 3. Preparación Semántica y Vectorización
1. **Limpieza (HTML a Markdown):** Un *parser* eliminará estrictamente el boilerplate (menús, cabeceras) de los archivos HTML (sean descargados o leídos en local) dejándolos en Markdown puro.
2. **Chunking Semántico:** El Markdown se dividirá en fragmentos con contexto (párrafos lógicos, 500-1000 tokens, 15% overlap) usando `RecursiveCharacterTextSplitter` de Langchain o un script equivalente.
3. **Metadatos Clave:** Inyección estricta de:
    *   `url_origen`: Obligatorio (ej: *https://app.itheca.org/biblioteca/doc.html*).
    *   `origen_extraccion`: (Valor: *"WEB"* o *"LOCAL_FALLBACK"* para auditoría).
4. **Almacenamiento (Qdrant):** Los chunks enriquecidos pasarán por un modelo de embeddings (ej. `text-embedding-3-large`) y se guardarán en una única colección en Qdrant (ej. `doctrina_itheca`).

## 4. Evolución: RAG Continuo (Integración Dinámica con n8n)
La arquitectura está diseñada para mantenerse viva. Cuando Itheca agregue fuentes nuevas, el sistema las absorberá automáticamente:
*   **Workflow en n8n:** Se programará un cronograma (ej. semanal).
*   **Fase de Descubrimiento:** El flujo lanzará un rastreo rápido sobre `app.itheca.org` para obtener el listado actualizado de URLs.
*   **Diff-Check Automático:** Comparará las URLs descubiertas contra la lista de URLs (metadato `url_origen`) existentes en Qdrant.
*   **Ingesta Quirúrgica:** Por cada URL nueva, disparará de forma aislada el *Pipeline de Ingesta* (descargar, parsear a MD, chunking, generar embedding e inyectar en Qdrant). El conocimiento de InteractIA se actualizará sin intervención humana.

---

## 5. Tareas Atómicas de Implementación (Diseñadas para Agente Flash)

Las siguientes tareas están estructuradas de forma lineal, aislada y con un nivel de detalle extremo. Si un agente de menor capacidad toma este documento, **debe ejecutar exclusivamente una y solo una** de estas tareas por turno, deteniéndose tras su conclusión para reportar y recibir feedback.

### Tarea 1: El Descargador Dual Recursivo (Pipeline de Ingesta - Fase 1)
*   **Objetivo:** Crear el script de PowerShell `DescargarContenidoDual.ps1`.
*   **Input:** Archivo `valid_links.txt` (rutas relativas al dominio).
*   **Lógica Principal:**
    1.  El script debe tomar una URL válida (ej. `/biblioteca/Fco/papa.html`).
    2.  Debe intentar hacer un `Invoke-WebRequest` a `https://app.itheca.org/biblioteca/Fco/papa.html`.
    3.  **Manejo de Error Estricto (try/catch):**
        *   Si la petición web (200 OK) es exitosa, guardar el HTML devuelto en la carpeta local emulando la ruta: `.\Descargas\biblioteca\Fco\papa.html`. Registrar "Web Exitosa" en un archivo log.
        *   Si la petición web *falla*, el script **no debe abortar**. Debe registrar el fallo en el log e ir a buscar el archivo en una ruta de origen secundaria (en caso de que exista de la etapa previa de crawling) y copiarlo a la carpeta de salida `.\Descargas\`.
*   **Condición de Éxito para el Agente:** El script debe ser capaz de procesar un archivo simulado de 5 URLs de prueba, mostrando en consola y en log cuáles se bajó de la web y a cuáles aplicó el fallback (si se programa para ello).

### Tarea 2: El Parser Html a Markdown y Metadatos (Pipeline - Fase 2)
*   **Objetivo:** Crear un script de Python `ParserHTML.py` (preferentemente Python por tener acceso a librerías como BeautifulSoup, aunque puede ser PowerShell si el entorno carece de Python).
*   **Input:** Directorio local `.\Descargas\` generado en la Tarea 1.
*   **Lógica:**
    1.  Recorrer todos los archivos `.html` del directorio y subdirectorios.
    2.  Extraer el cuerpo principal del texto. (El Agente Flash deberá inspeccionar 2 o 3 HTMLs para determinar las clases CSS o IDs exactos que delimitan el contenido útil y excluyen los menús de Itheca).
    3.  Convertir el texto limpio a `.md`.
    4.  Interesante: Inyectar un encabezado de metadatos YAML al inicio del `.md` generado que incluya: `url_origen: https://app.itheca.org/[ruta_relativa_descubierta]`.
*   **Salida:** Una nueva carpeta `.\Markdown\` replicando la estructura del árbol de directorios, conteniendo los archivos limpios.

### Tarea 3: PoC: Chunking y Qdrant Indexer Local
*   **Objetivo:** Crear un script pequeño de Python `IndexadorQdrant.py`.
*   **Prerrequisitos:** El agente Flash debe levantar un contenedor Docker básico de Qdrant en local (*o instruir* al usuario con el comando exacto para hacerlo).
*   **Lógica:**
    1.  Usar Langchain u OpenAI SDK (asumiendo que hay una clave API en el entorno).
    2.  Tomar **solo 10 archivos Markdown** de la carpeta resultante de la Tarea 2 (como PoC).
    3.  Segmentar el texto en párrafos usando RecursiveCharacterTextSplitter (1000 tokens).
    4.  Generar vectores y subirlos a la colección `doctrina_itheca` en el Qdrant local, preservando el `url_origen`.

### Tarea 4: Validación de Búsqueda
*   **Objetivo:** Script mínimo `TestBúsqueda.py`.
*   **Lógica:** Conectarse al Qdrant local, hacer una query teológica en lenguaje natural, y retornar los Top 3 Chunks con su respectivo `url_origen` impresos en la consola. Esto validará que el Pipeline y la inyección de origen funcionan a la perfección.
