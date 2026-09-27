#!/bin/bash
# Borra todos los recursos del log processing system
# uso: ./scripts/teardown.sh [bucket] [tabla_logs] [tabla_alertas]
BUCKET_NAME="${1:-logging-apiserverless-iteso-bucket}"
LOGS_TABLE="${2:-logging-apiserverless-iteso-tabla}"
ALERTS_TABLE="${3:-SecurityAlerts}"
SM_NAME="LogProcessingStateMachine"
API_NAME="LogProcessingAPI"

API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='$API_NAME'].ApiId" --output text)
if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
  aws apigatewayv2 delete-api --api-id "$API_ID" && echo "API $API_NAME eliminada"
fi

SM_ARN=$(aws stepfunctions list-state-machines \
  --query "stateMachines[?name=='$SM_NAME'].stateMachineArn" --output text)
if [ -n "$SM_ARN" ] && [ "$SM_ARN" != "None" ]; then
  aws stepfunctions delete-state-machine --state-machine-arn "$SM_ARN"
  echo "Maquina de estados $SM_NAME eliminada"
fi

for FUNC in start_workflow parse_batch classify_log get_alerts get_logs; do
  aws lambda delete-function --function-name "$FUNC" 2>/dev/null \
    && echo "Lambda $FUNC eliminada"
done

for TABLE in "$LOGS_TABLE" "$ALERTS_TABLE"; do
  aws dynamodb delete-table --table-name "$TABLE" >/dev/null 2>&1 \
    && echo "Tabla $TABLE eliminada"
done

if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  aws s3 rm "s3://$BUCKET_NAME" --recursive
  aws s3 rb "s3://$BUCKET_NAME"
  echo "Bucket $BUCKET_NAME eliminado"
fi

echo "Teardown completo"