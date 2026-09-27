#!/bin/bash
set -e
# Crea la HTTP API con GET /alerts -> get_alerts y GET /logs -> get_logs
# (mismo proceso que create_and_configure_api_gateway.sh del demo ReportGenerator)

API_NAME="LogProcessingAPI"
STAGE_NAME='$default'   # stage por defecto: la URL queda sin prefijo (https://.../alerts)

REGION=$(aws configure get region || true)
REGION="${REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# si la API ya existe la borramos para crearla limpia
OLD_API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='$API_NAME'].ApiId" --output text)
if [ -n "$OLD_API_ID" ] && [ "$OLD_API_ID" != "None" ]; then
  echo "Borrando API anterior $OLD_API_ID"
  aws apigatewayv2 delete-api --api-id "$OLD_API_ID"
fi

# Crear HTTP API
API_ID=$(aws apigatewayv2 create-api \
  --name "$API_NAME" \
  --protocol-type HTTP \
  --query 'ApiId' --output text)
echo "API creada: $API_ID"

# crea integracion + ruta + permiso para una Lambda
add_route() {
  local method="$1" path="$2" lambda_name="$3"
  local lambda_arn="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$lambda_name"

  # Crear integracion Lambda proxy
  local integration_id
  integration_id=$(aws apigatewayv2 create-integration \
    --api-id "$API_ID" \
    --integration-type AWS_PROXY \
    --integration-uri "$lambda_arn" \
    --payload-format-version 2.0 \
    --query 'IntegrationId' --output text)

  # Crear ruta METODO /path
  aws apigatewayv2 create-route \
    --api-id "$API_ID" \
    --route-key "$method $path" \
    --target "integrations/$integration_id" >/dev/null

  # Permitir que API Gateway invoque la Lambda (quitamos el permiso viejo si existia)
  aws lambda remove-permission --function-name "$lambda_name" \
    --statement-id apigateway-invoke >/dev/null 2>&1 || true
  aws lambda add-permission \
    --function-name "$lambda_name" \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/$method$path" >/dev/null

  echo "Ruta $method $path -> $lambda_name"
}

add_route GET /alerts get_alerts
add_route GET /logs get_logs

# Deploy con auto-deploy
aws apigatewayv2 create-stage \
  --api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --auto-deploy >/dev/null

API_URL=$(aws apigatewayv2 get-api --api-id "$API_ID" --query 'ApiEndpoint' --output text)
echo ""
echo "Listo. URL de la API: $API_URL"
echo "  curl \"$API_URL/alerts\""
echo "  curl \"$API_URL/logs?top=5\""