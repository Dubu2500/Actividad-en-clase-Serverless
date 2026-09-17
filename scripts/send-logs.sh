#!/bin/bash

 # el uso es: ./send-logs.sh <SLEEP_SECONDS>
SLEEP_SECONDS="${1:?Usage: $0 <sleep_seconds> [bucket_name] [log_pattern]}" # el tercer y cuarto argumento es si quieres subir a un bucket diferente o especificar archivos con nombres diferentes
BUCKET_NAME="${2:-logging-apiserverless-iteso}"
LOG_PATTERN="${3:-openssh-*.log}"

# recopila los archivos cuyo nombre sigue el patron openssh-*.log
shopt -s nullglob
files=($LOG_PATTERN)
shopt -u nullglob

# fall back si no se encuentran archivos
if [[ ${#files[@]} -eq 0 ]]; then
    echo "No se encontraron archivos con: $LOG_PATTERN"
    exit 1
fi

echo "Se encontraron ${#files[@]} batches para subir a S3://$BUCKET_NAME/input/"

count=0

# sube los batches a s3
for file in "${files[@]}"; do
    count=$((count + 1))
    echo "[$count/${#files[@]}] Subiendo $file..."
    aws s3 cp "$file" "s3://$BUCKET_NAME/input/$(basename "$file")"

    # pone un tiempo de espera entre uploads
    if [[ $count -lt ${#files[@]} ]]; then
        echo "Esperando ${SLEEP_SECONDS} segundos antes de la proxima subida..."
        sleep "$SLEEP_SECONDS"
    fi
done

echo "Listo. Se subieron $count archivos a S3://$BUCKET_NAME/input/"