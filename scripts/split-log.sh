#!/bin/bash
set -e

BASE_NAME="openssh"
MAX_BYTES=$((10 * 1024)) # 10 KB

current_bytes=0 # contador de bytes
current_file=""

# directorio donde vive este script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# root del proyecto, un nivel arriba de scripts/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# genera un nombre de archivo con la fecha actual
generate_filename() {
    echo "${PROJECT_ROOT}/${BASE_NAME}-$(date +%Y%m%d%H%M%S).log"
}

# lee linea por linea
while IFS= read -r line || [[ -n "$line" ]]; do
    line_with_newline="$line"$'\n' # aseguramos que incluya el caracter de newline
    line_bytes=$(printf '%s' "$line_with_newline" | wc -c)

    # si el archivo no esta abierto o si añadir esta linea sobrepasa los bytes maximos, creamos un nuevo batch
    if [[ -z "$current_file" ]] || (( current_bytes + line_bytes > MAX_BYTES )); then
        if [[ -n "$current_file" ]]; then
            sleep 1 # esperamos 1 segundo entre batches
        fi
        current_file=$(generate_filename)
        current_bytes=0
    fi

    # agrega la linea al batch activo
    printf '%s' "$line_with_newline" >> "$current_file"
    # actualizamos el contador de bytes para el batch actual
    (( current_bytes += line_bytes ))
done
