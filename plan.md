# Plan de Implementación: Crawler de Archivos en Servidor Web

El objetivo original es crear un crawler avanzado que, dada una URL base, navegue de forma recursiva a través de los archivos HTML para descubrir y mapear todos los recursos enlazados dentro del dominio `app.itheca.org`. Este esfuerzo ha mutado hacia la preparación de los datos para la ingestión en un sistema RAG (Retrieval-Augmented Generation) avanzado.

## Estado Actual
*   **Implementación Crawler:** Crawler híbrido (Directorios + Contenido) operativo en `ListarArchivos.ps1` y URLs extraídas en `full_discovered_files.txt`.
*   **Verificación de Enlaces:** Verificación realizada en `VerificarArchivos.ps1`, generando `verified_tree.txt` (rutas operativas) y `broken_links.txt` (errores).
*   **Extracción de URLs Válidas:** COMPLETADO con `ExtraerUrlsValidas.ps1`, asilando un total de 11.800+ URLs correctas en el archivo `valid_links.txt`.
*   **Siguiente Tarea Activa:** Fase 3, Tarea 1: Programación del **Pipeline de Ingesta Dual (Web + Fallback)** mediante un agente Flash.

---

## Fase 3: Preparación Estructurada para el Conocimiento
Esta fase está rediseñada para ser ejecutada por un agente iterativo (modelo base o Flash). Cada paso es una tarea aislada.

1.  **[PENDIENTE - SIGUIENTE PASO PARA AGENTE FLASH] El Descargador Dual Recursivo (Pipeline de Ingesta)**
    *   **Delegación (Tarea 1 en Propuesta_Proyecto_RAG_Itheca):** El agente debe crear `DescargarContenidoDual.ps1`.
    *   **Lógica Innegociable:** Leer cada URL de `valid_links.txt`, intentar un scrapeo en vivo con `Invoke-WebRequest` usando la URL en vivo como Origen Primario. Implementar *Try/Catch* para que, en caso de fallo, intente localizar o recuperar la versión local previamente crawleada.

2.  **[PENDIENTE] El Parser Html a Markdown y Extracción de Metadatos:**
    *   **Delegación (Tarea 2 en Propuesta):** El agente creará un script (Python o PowerShell) que recorra los HTML descargados iterativamente en el paso 1.
    *   **Lógica Innegociable:** Limpieza total del *boilerplate* y menús. Extracción solo del contenido medular. Guardado en `.md` con inyección obligatoria de un encabezado (frontmatter) que guarde la variable `url_origen`.

3.  **Análisis de Patrones en Enlaces Rotos:**
    *   Tarea original de evaluación de la estructura perdida de `broken_links.txt`.

---

## Fase 4: Implementación de Arquitectura de Microservicios RAG 
*(Para una visión extendida, consultar `Propuesta_Proyecto_RAG_Itheca.md`)*

El diseño final del sistema abandona el concepto de un RAG acoplado y pasa a un modelo de servicio.

1.  **Qdrant Vector Store Centralizado:** Implementación del motor vectorial de forma aislada para habilitar concurrencia.
2.  **Consumo Multi-Agente:**
    *   Ataque directo por el **Cerebro** de **InteractIA** mediante una tool específica (`consultar_doctrina_itheca`).
    *   Ataque concurrente por una instancia de **n8n** conectada vía nodo nativo Qdrant para flujos de mensajería (Continuous RAG).
3.  **Prueba de Concepto (PoC):** Indexación de una muestra de 10-20 documentos Markdown y script temporal de test de búsqueda para validar el pipeline.

## Fases Anteriores (Completadas / Secundarias)
*   **Fase 1 (Crawling Principal):** Proceso base operativo a partir de `https://app.itheca.org/biblioteca/`.
*   **Fase 2 (Consolidación):** Rutas guardadas y des-duplicadas en logs.
*   **Herramientas Clave Base:** PowerShell, `HtmlWebResponseObject`, y manejo de HashSets y Queues.