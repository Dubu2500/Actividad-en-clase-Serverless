#!/bin/bash
set -e

FUNCTION_NAME="log-processor"
BUCKET_NAME="${1:-logging-apiserverless-iteso-bucket}"

LAB_ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)

if aws lambda get-function --function-name "$FUNCTION_NAME" >/dev/null 2>&1; then
  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file fileb://lambda_package.zip
else
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.13 \
    --role "$LAB_ROLE_ARN" \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://lambda_package.zip \
    --timeout 30 \
    --memory-size 256

  aws lambda add-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id s3-trigger \
    --action lambda:InvokeFunction \
    --principal s3.amazonaws.com \
    --source-arn "arn:aws:s3:::${BUCKET_NAME}"
fi

FUNCTION_ARN=$(aws lambda get-function --function-name "$FUNCTION_NAME" \
  --query 'Configuration.FunctionArn' --output text)

cat > /tmp/notification.json << EOL
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "$FUNCTION_ARN",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            { "Name": "prefix", "Value": "input/" },
            { "Name": "suffix", "Value": ".log" }
          ]
        }
      }
    }
  ]
}
EOL

aws s3api put-bucket-notification-configuration \
  --bucket "$BUCKET_NAME" \
  --notification-configuration file:///tmp/notification.json

echo "Lambda desplegada y trigger de S3 configurado"
