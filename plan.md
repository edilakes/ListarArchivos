# Plan de Implementación: Listado de Archivos en Servidor Web

El objetivo es crear una herramienta que, dada una URL base, intente descubrir la mayor cantidad de archivos y directorios accesibles en ese servidor.

## Fases del Proyecto

### Fase 1: Análisis Básico y Archivos de Configuración

1.  **Entrada de Usuario:**
    *   La aplicación aceptará una URL base como punto de partida (ej: `https://example.com`).

2.  **Análisis de `robots.txt`:**
    *   Construir la URL para `robots.txt` (ej: `https://example.com/robots.txt`).
    *   Descargar y analizar el archivo.
    *   Extraer y listar las rutas en `Allow`, `Disallow` y la ubicación de los `Sitemap`.

3.  **Análisis de `sitemap.xml`:**
    *   Buscar sitemaps en la ubicación por defecto (`/sitemap.xml`) y en las rutas encontradas en `robots.txt`.
    *   Descargar y parsear los archivos XML.
    *   Extraer y listar todas las URLs contenidas en los sitemaps.

### Fase 2: Descubrimiento Activo (Crawling y Scraping)

1.  **Scraping de la Página Principal:**
    *   Descargar el contenido HTML de la URL base.
    *   Extraer todos los enlaces (`<a href="...">`) y las rutas de los scripts (`<script src="...">`).
    *   Almacenar los enlaces internos para un análisis posterior.

2.  **Crawling Recursivo (Opcional, Profundidad Limitada):**
    *   Para cada enlace interno descubierto, repetir el proceso de scraping.
    *   Limitar la profundidad del crawling (ej: 1 o 2 niveles) para evitar bucles y peticiones excesivas.

### Fase 3: Descubrimiento por Fuerza Bruta (Diccionario)

1.  **Crear un Diccionario Básico:**
    *   Preparar una lista de nombres comunes de archivos y directorios (ej: `admin`, `login`, `test`, `uploads`, `backup`, `wp-admin`).

2.  **Realizar Peticiones:**
    *   Para cada término en el diccionario, construir una URL (ej: `https://example.com/admin/`).
    *   Realizar una petición `HEAD` o `GET` para verificar si el recurso existe (comprobar códigos de estado como 200, 301, 403).

### Fase 4: Consolidación y Reporte

1.  **Unificar Resultados:**
    *   Agrupar todas las URLs y rutas descubiertas en las fases anteriores.
    *   Eliminar duplicados.

2.  **Generar Reporte:**
    *   Guardar la lista final de rutas en un archivo de texto (ej: `discovered_paths.txt`).
    *   El reporte debe ser claro y mostrar las rutas encontradas.

## Herramientas y Lenguaje

*   **Lenguaje:** Se utilizará PowerShell, continuando con la base del proyecto actual.
*   **Comandos Clave:**
    *   `Invoke-WebRequest`: Para descargar contenido de las URLs (`robots.txt`, `sitemap.xml`, páginas HTML).
    *   `Select-String`: Para buscar patrones en el texto (parseo simple).
    *   `Select-Xml`: Para analizar los archivos `sitemap.xml`.
    *   `Set-Content` / `Add-Content`: Para escribir los reportes.
