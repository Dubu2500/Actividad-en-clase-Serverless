#!/bin/bash
set -e
# Crea/actualiza la maquina de estados y conecta S3 -> start_workflow -> Step Functions
cd "$(dirname "$0")/.."

BUCKET_NAME="${1:-logging-apiserverless-iteso-bucket}"
LOGS_TABLE="${2:-logging-apiserverless-iteso-tabla}"
ALERTS_TABLE="${3:-SecurityAlerts}"
SM_NAME="LogProcessingStateMachine"

LAB_ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region || true)
REGION="${REGION:-us-east-1}"

PARSE_ARN="arn:aws:lambda:$REGION:$ACCOUNT:function:parse_batch"
CLASSIFY_ARN="arn:aws:lambda:$REGION:$ACCOUNT:function:classify_log"

# reemplaza los ${...} del JSON por los valores reales
DEFINITION=$(sed \
  -e "s|\${PARSE_BATCH_ARN}|$PARSE_ARN|g" \
  -e "s|\${CLASSIFY_LOG_ARN}|$CLASSIFY_ARN|g" \
  -e "s|\${LOGS_TABLE}|$LOGS_TABLE|g" \
  -e "s|\${ALERTS_TABLE}|$ALERTS_TABLE|g" \
  statemachine/log_processing.asl.json)

SM_ARN=$(aws stepfunctions list-state-machines \
  --query "stateMachines[?name=='$SM_NAME'].stateMachineArn" --output text)

if [ -z "$SM_ARN" ] || [ "$SM_ARN" == "None" ]; then
  SM_ARN=$(aws stepfunctions create-state-machine \
    --name "$SM_NAME" \
    --definition "$DEFINITION" \
    --role-arn "$LAB_ROLE_ARN" \
    --type STANDARD \
    --query 'stateMachineArn' --output text)
  echo "Maquina de estados creada: $SM_ARN"
else
  aws stepfunctions update-state-machine \
    --state-machine-arn "$SM_ARN" \
    --definition "$DEFINITION" >/dev/null
  echo "Maquina de estados actualizada: $SM_ARN"
fi

# start_workflow necesita saber que maquina iniciar
aws lambda update-function-configuration \
  --function-name start_workflow \
  --environment "Variables={STATE_MACHINE_ARN=$SM_ARN}" >/dev/null
aws lambda wait function-updated-v2 --function-name start_workflow

# permiso para que S3 invoque start_workflow (si ya existe, lo ignoramos)
aws lambda add-permission \
  --function-name start_workflow \
  --statement-id s3-trigger \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::${BUCKET_NAME}" >/dev/null 2>&1 || true

START_ARN=$(aws lambda get-function --function-name start_workflow \
  --query 'Configuration.FunctionArn' --output text)

# el trigger de S3 ahora apunta a start_workflow (reemplaza al de log-processor)
cat > /tmp/notification.json << EOL
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "$START_ARN",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": { "Key": { "FilterRules": [
        { "Name": "prefix", "Value": "input/" },
        { "Name": "suffix", "Value": ".log" }
      ]}}
    }
  ]
}
EOL

aws s3api put-bucket-notification-configuration \
  --bucket "$BUCKET_NAME" \
  --notification-configuration file:///tmp/notification.json

echo "Listo: s3://$BUCKET_NAME/input/*.log -> start_workflow -> $SM_NAME"