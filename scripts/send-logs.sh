#!/bin/bash
set -e

# uso: ./scripts/send-logs.sh <segundos_de_espera> [bucket] [patron]
SLEEP_SECONDS="${1:?Uso: $0 <segundos> [bucket_name] [log_pattern]}"
BUCKET_NAME="${2:-logging-apiserverless-iteso-bucket}"
LOG_PATTERN="${3:-openssh-*.log}"

shopt -s nullglob
files=($LOG_PATTERN)
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
    echo "No se encontraron archivos con: $LOG_PATTERN"
    exit 1
fi

echo "Se encontraron ${#files[@]} batches para subir a s3://$BUCKET_NAME/input/"

count=0
for file in "${files[@]}"; do
    count=$((count + 1))
    echo "[$count/${#files[@]}] Subiendo $file..."
    aws s3 cp "$file" "s3://$BUCKET_NAME/input/$(basename "$file")"

    if [[ $count -lt ${#files[@]} ]]; then
        echo "Esperando ${SLEEP_SECONDS} segundos antes de la proxima subida..."
        sleep "$SLEEP_SECONDS"
    fi
done

echo "Listo. Se subieron $count archivos a s3://$BUCKET_NAME/input/"