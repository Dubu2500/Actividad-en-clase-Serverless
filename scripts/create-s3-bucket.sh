#!/bin/bash
set -e

BUCKET_NAME="${1:-logging-vicky-iteso}"

echo "Creando bucket: $BUCKET_NAME"
aws s3 mb "s3://$BUCKET_NAME"

echo "Creando carpetas input/ y output/ dentro del bucket"
aws s3api put-object --bucket "$BUCKET_NAME" --key input/
aws s3api put-object --bucket "$BUCKET_NAME" --key output/

echo "Listo. Bucket creado: s3://$BUCKET_NAME"