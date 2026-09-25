#!/bin/bash
set -e

BUCKET_NAME="${1:-logging-apiserverless-iteso-bucket}"
TABLE_NAME="${2:-logging-apiserverless-iteso-tabla}"

echo "Creando bucket: $BUCKET_NAME"
aws s3 mb "s3://$BUCKET_NAME"

echo "Creando tabla: $TABLE_NAME"

echo "Creando carpetas input/ y output/ dentro del bucket"
aws s3api put-object --bucket "$BUCKET_NAME" --key input/
aws s3api put-object --bucket "$BUCKET_NAME" --key output/

if aws dynamodb describe-table --table-name "$TABLE_NAME" >/dev/null 2>&1; then
  echo "La tabla $TABLE_NAME ya existe, omitimos la creacion..."
else
  aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions \
      AttributeName=source_file,AttributeType=S \
      AttributeName=line_number,AttributeType=N \
    --key-schema \
      AttributeName=source_file,KeyType=HASH \
      AttributeName=line_number,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST >/dev/null
fi

echo "Listo. Bucket creado: s3://$BUCKET_NAME, Tabla creada (DynamoDB): $TABLE_NAME"