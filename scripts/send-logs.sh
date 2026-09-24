#!/bin/bash
set -e

 # el uso es: ./send-logs.sh <SLEEP_SECONDS>
SLEEP_SECONDS="${1:?Usage: $0 <sleep_seconds> [TABLE_NAME] [log_pattern]}" # el tercer y cuarto argumento es si quieres subir a una tabla diferente o especificar archivos con nombres diferentes
TABLE_NAME="${2:-logging-apiserverless-iteso-tabla}"
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

echo "Se encontraron ${#files[@]} batches para subir a la tabla $TABLE_NAME de DynamoDB."

echo "Listo. Se subieron $count archivos a la tabla $TABLE_NAME de DynamoDB."