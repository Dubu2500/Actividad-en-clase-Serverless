#!/bin/bash
set -e
# Crea el bucket S3, la tabla de logs, la tabla SecurityAlerts y los indices (GSI)
# uso: ./scripts/create-s3-bucket.sh [bucket] [tabla_logs] [tabla_alertas]

BUCKET_NAME="${1:-logging-apiserverless-iteso-bucket}"
TABLE_NAME="${2:-logging-apiserverless-iteso-tabla}"
ALERTS_TABLE="${3:-SecurityAlerts}"

# ---------- S3 ----------
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "El bucket $BUCKET_NAME ya existe, omitimos la creacion..."
else
  echo "Creando bucket: $BUCKET_NAME"
  aws s3 mb "s3://$BUCKET_NAME"
fi
aws s3api put-object --bucket "$BUCKET_NAME" --key input/ >/dev/null
aws s3api put-object --bucket "$BUCKET_NAME" --key output/ >/dev/null

# ---------- tablas ----------
# las dos tablas usan la misma llave: source_file + line_number
create_table() {
  local table="$1"
  if aws dynamodb describe-table --table-name "$table" >/dev/null 2>&1; then
    echo "La tabla $table ya existe, omitimos la creacion..."
  else
    echo "Creando tabla: $table"
    aws dynamodb create-table \
      --table-name "$table" \
      --attribute-definitions \
        AttributeName=source_file,AttributeType=S \
        AttributeName=line_number,AttributeType=N \
      --key-schema \
        AttributeName=source_file,KeyType=HASH \
        AttributeName=line_number,KeyType=RANGE \
      --billing-mode PAY_PER_REQUEST >/dev/null
  fi
  aws dynamodb wait table-exists --table-name "$table"
}

# ---------- indices (GSI) ----------
# se pueden agregar a una tabla que ya existe (a diferencia de los LSI)
create_gsi() {
  local table="$1" index="$2" pk="$3" sk="$4"
  local existing
  existing=$(aws dynamodb describe-table --table-name "$table" \
    --query "Table.GlobalSecondaryIndexes[?IndexName=='$index'].IndexName" --output text)
  if [ -n "$existing" ] && [ "$existing" != "None" ]; then
    echo "El indice $index ya existe en $table"
  else
    echo "Creando indice $index en $table ($pk + $sk)"
    aws dynamodb update-table \
      --table-name "$table" \
      --attribute-definitions \
        AttributeName="$pk",AttributeType=S \
        AttributeName="$sk",AttributeType=S \
      --global-secondary-index-updates \
        "[{\"Create\":{\"IndexName\":\"$index\",\"KeySchema\":[{\"AttributeName\":\"$pk\",\"KeyType\":\"HASH\"},{\"AttributeName\":\"$sk\",\"KeyType\":\"RANGE\"}],\"Projection\":{\"ProjectionType\":\"ALL\"}}}]" \
      >/dev/null
  fi
  # esperamos a que el indice quede ACTIVE (tarda unos minutos si la tabla tiene datos)
  until [ "$(aws dynamodb describe-table --table-name "$table" \
      --query "Table.GlobalSecondaryIndexes[?IndexName=='$index'].IndexStatus" --output text)" == "ACTIVE" ]; do
    echo "  esperando a que $index este ACTIVE..."
    sleep 10
  done
}

create_table "$TABLE_NAME"
create_table "$ALERTS_TABLE"

# GET /logs?top=N  -> ultimos logs segun la hora en que llego el batch a S3
create_gsi "$TABLE_NAME" RecentLogsIndex gsi_pk received_at
# GET /alerts      -> alertas activas, las mas recientes primero
create_gsi "$ALERTS_TABLE" ActiveAlertsIndex alert_status detected_at

echo "Listo. Bucket: s3://$BUCKET_NAME, Tablas: $TABLE_NAME y $ALERTS_TABLE (con indices)"