#!/bin/bash
set -e
# Crea o actualiza las 3 Lambdas: start_workflow, parse_batch, classify_log
cd "$(dirname "$0")/.."
LAB_ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)

for zip in build/*.zip; do
  NAME=$(basename "$zip" .zip)
  if aws lambda get-function --function-name "$NAME" >/dev/null 2>&1; then
    aws lambda update-function-code --function-name "$NAME" \
      --zip-file "fileb://$zip" >/dev/null
    aws lambda wait function-updated-v2 --function-name "$NAME"
  else
    aws lambda create-function --function-name "$NAME" \
      --runtime python3.13 \
      --role "$LAB_ROLE_ARN" \
      --handler lambda_function.lambda_handler \
      --zip-file "fileb://$zip" \
      --timeout 30 --memory-size 256 >/dev/null
    aws lambda wait function-active-v2 --function-name "$NAME"
  fi
  echo "Lambda $NAME lista"
done