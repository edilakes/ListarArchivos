# Plan de Implementación: Crawler de Archivos en Servidor Web

El objetivo es crear un crawler avanzado que, dada una URL base, navegue de forma recursiva a través de los archivos HTML para descubrir y mapear todos los recursos enlazados dentro del dominio `app.itheca.org`.

## Fase 1: Crawling y Análisis de Contenido (Enfoque Principal)

1.  **Punto de Partida:**
    *   Comenzar con el mismo método de la fase anterior: descubrir los directorios raíz (`Biblia`, `Padres`, etc.) a partir de la página principal `https://app.itheca.org/biblioteca/`.
    *   Crear una cola de URLs para procesar, inicializada con estos directorios.
    *   Mantener un registro de URLs ya visitadas para evitar bucles y trabajo redundante.

2.  **Proceso del Crawler (Bucle Principal):**
    *   Mientras la cola de URLs no esté vacía, tomar una URL para procesar.
    *   **Si la URL es un directorio** (termina en `/`):
        *   Descargar el listado.
        *   Extraer todos los enlaces (`<a href="...">`).
        *   Añadir cada nuevo enlace a la cola de URLs por procesar (si no ha sido visitado).
    *   **Si la URL es un archivo HTML** (termina en `.html` o `.htm`):
        *   Descargar el contenido del archivo.
        *   Analizar (parsear) el HTML para encontrar todos los recursos enlazados:
            *   Otros archivos HTML (`<a href="...">`).
            *   Archivos JavaScript (`<script src="...">`).
            *   Hojas de estilo CSS (`<link rel="stylesheet" href="...">`).
            *   Imágenes y otros medios (`<img src="...">`, etc.).
        *   Añadir cada nuevo recurso encontrado a la cola de URLs por procesar (si no ha sido visitado y pertenece al dominio).

3.  **Filtrado de Dominio:**
    *   Durante el proceso, asegurarse de que solo se sigan y registren las URLs que pertenecen al dominio de interés (ej: `app.itheca.org`).

## Fase 2: Consolidación y Reporte

1.  **Unificar Resultados:**
    *   Agrupar todas las URLs de archivos finales descubiertos (HTML, JS, CSS, imágenes, etc.).
    *   Eliminar duplicados.

2.  **Generar Reporte:**
    *   Guardar la lista final y completa de rutas en un archivo de texto (ej: `full_discovered_files.txt`).

## Fases Anteriores (Ahora Secundarias)

*   **Análisis de `robots.txt` y `sitemap.xml`:** Puede realizarse como un paso inicial opcional para poblar la cola de URLs.
*   **Descubrimiento por Fuerza Bruta:** Puede usarse como un método complementario si el crawling no revela todos los directorios.

## Herramientas y Lenguaje

*   **Lenguaje:** Se actualizará el script de PowerShell `DescubrirArchivos.ps1`.
*   **Comandos Clave:**
    *   `Invoke-WebRequest`: Para descargar contenido HTML y de directorios.
    *   Uso de las propiedades `.Links`, `.Images`, etc., del objeto `HtmlWebResponseObject` de PowerShell para un parseo más robusto.
    *   Manejo de colecciones: `Queue` para las URLs por procesar y `HashSet` para las URLs visitadas.