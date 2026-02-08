# Este script lista todos los archivos y carpetas de forma recursiva desde su ubicación
# y guarda el resultado en un archivo llamado file_list.txt.

Get-ChildItem -Recurse -Name > file_list.txt
