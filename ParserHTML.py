import os
import re
from bs4 import BeautifulSoup
import markdownify
import yaml

# Configuración
DOWNLOAD_DIR = r"e:\OneDrive\MiCodigo\GitHub\ListarArchivos\Descargas"
MARKDOWN_DIR = r"e:\OneDrive\MiCodigo\GitHub\ListarArchivos\Markdown"
BASE_URL = "https://app.itheca.org"

def clean_html_content(soup):
    """
    Elimina elementos no deseados de Itheca (menús, navigation bars, etc.)
    """
    # Eliminar el div de menú
    menu = soup.find("div", class_="menu")
    if menu:
        menu.decompose()
    
    # Eliminar scripts y estilos
    for script_or_style in soup(["script", "style"]):
        script_or_style.decompose()

    return soup

def parse_file(file_path):
    """
    Lee un HTML, lo limpia, extrae metadatos y lo convierte a Markdown.
    """
    # Abrimos en binario. BeautifulSoup/UnicodeDammit detectará el encoding real (UTF-8, Windows-1252, etc.)
    with open(file_path, "rb") as f:
        content = f.read()

    # Le pasamos los bytes puros a BeautifulSoup
    soup = BeautifulSoup(content, "html.parser")
    
    # Título para el metadato
    title_tag = soup.find("title")
    h1_tag = soup.find("h1")
    title = title_tag.get_text().strip() if title_tag else (h1_tag.get_text().strip() if h1_tag else "Sin título")

    # Limpiar
    soup = clean_html_content(soup)

    # Convertir a Markdown
    # Usamos markdownify para una conversión limpia
    md_content = markdownify.markdownify(str(soup), heading_style="ATX").strip()

    # Calcular url_origen
    rel_path = os.path.relpath(file_path, DOWNLOAD_DIR).replace("\\", "/")
    # Si es index.html en una carpeta, la URL de origen suele omitirlo
    url_path = rel_path
    if url_path.endswith("index.html"):
        url_path = url_path[:-10]
    
    url_origen = f"{BASE_URL}/{url_path}"

    # Metadatos YAML (Frontmatter)
    metadata = {
        "title": title,
        "url_origen": url_origen,
        "source_type": "official_itheca_web"
    }
    
    yaml_frontmatter = "---\n" + yaml.dump(metadata, allow_unicode=True) + "---\n\n"
    
    return yaml_frontmatter + md_content

def main():
    if not os.path.exists(MARKDOWN_DIR):
        os.makedirs(MARKDOWN_DIR)

    count = 0
    for root, dirs, files in os.walk(DOWNLOAD_DIR):
        for file in files:
            if file.endswith(".html"):
                html_path = os.path.join(root, file)
                
                # Replicar estructura de carpetas
                rel_dir = os.path.relpath(root, DOWNLOAD_DIR)
                target_dir = os.path.join(MARKDOWN_DIR, rel_dir)
                if not os.path.exists(target_dir):
                    os.makedirs(target_dir)

                md_filename = os.path.splitext(file)[0] + ".md"
                target_path = os.path.join(target_dir, md_filename)

                try:
                    md_text = parse_file(html_path)
                    with open(target_path, "w", encoding="utf-8") as f:
                        f.write(md_text)
                    count += 1
                    if count % 100 == 0:
                        print(f"Procesados {count} archivos...")
                except Exception as e:
                    print(f"Error procesando {html_path}: {e}")

    print(f"Fin del proceso. Total procesados: {count}")

if __name__ == "__main__":
    main()
