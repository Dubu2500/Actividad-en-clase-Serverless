## API (parte 4)

HTTP API en API Gateway con Lambda proxy integration:

| Endpoint | Lambda | Consulta |
|---|---|---|
| `GET /alerts` | get_alerts | Query a SecurityAlerts por el GSI `ActiveAlertsIndex` (alert_status = ACTIVE, ordenado por detected_at) |
| `GET /logs?top=N` | get_logs | Query a Logs por el GSI `RecentLogsIndex` (gsi_pk = LOG, sort key received_at = LastModified del batch en S3), Limit=N, ScanIndexForward=false |

```bash
./scripts/create-api.sh     # imprime la URL de la API
curl "$API_URL/alerts"
curl "$API_URL/logs?top=5"
```

# Flujo de comandos para montar la aplicacion

## 0. Solo la primera vez en tu computadora

```bash
sudo apt install -y zip
aws configure set region us-east-1
echo 'export AWS_PAGER=""' >> ~/.bashrc && source ~/.bashrc
```

## 1. Navegar al repositorio y traer lo último

```bash
cd Actividad-en-clase-Serverless
git pull
```

## 2. Verificar credenciales del Learner Lab (debe mostrar tu número de cuenta)

```bash
aws sts get-caller-identity
```

## 3. Hacer que los scripts sean ejecutables

```bash
chmod +x ./scripts/*.sh
```

## 4. Descargar el log de ejemplo (si no lo tienes)

```bash
curl -L -o OpenSSH_2k.log https://raw.githubusercontent.com/logpai/loghub/master/OpenSSH/OpenSSH_2k.log
```

## 5. Crear bucket S3, tabla de logs y tabla SecurityAlerts

```bash
./scripts/create-s3-bucket.sh <mi-bucket>
```

Confirmar que se crearon:

```bash
aws s3 ls
aws dynamodb list-tables
```

## 6. Crear los zips de las Lambdas

```bash
./scripts/package-lambda.sh
```

## 7. Desplegar las Lambdas (start_workflow, parse_batch, classify_log)

```bash
./scripts/deploy-lambda.sh
```

Confirmar que se desplegaron:

```bash
aws lambda list-functions --query "Functions[].FunctionName"
```

## 8. Crear la máquina de estados y conectar el trigger de S3

```bash
./scripts/create-state-machine.sh <mi-bucket>
```

Confirmar que se creo:

```bash
aws stepfunctions list-state-machines
```

## 9. Crear los batches

```bash
./scripts/split-log.sh < ./OpenSSH_2k.log
```

## 10. Enviar los batches (uno cada 60 segundos)

```bash
./scripts/send-logs.sh 60 <mi-bucket>
```

## 11. Confirmar que se están guardando los datos (en otra terminal)

```bash
aws s3 ls s3://logging-apiserverless-iteso-bucket --recursive
aws dynamodb scan --table-name SecurityAlerts --select COUNT
aws dynamodb scan --table-name logging-apiserverless-iteso-tabla --max-items 5
```

## 12. Crear la API gateway

```bash
./scripts/create-api.sh
```

Confirmar que se creo:

```bash
aws apigatewayv2 get-apis
```

Ahora puedes hacer peticiones a `GET /alerts` y `GET logs?top=5` con la url provista.

## 13. Eliminar los recursos creados

```bash
./scripts/teardown.sh
```

## 14. Confirmar que se elimino todo

```bash
aws s3 ls
aws dynamodb list-tables
aws lambda list-functions --query "Functions[].FunctionName"
aws stepfunctions list-state-machines
aws apigatewayv2 get-apis
```

---

## Como resolver este error

`"/bin/bash^M: bad interpreter: No such file or directory"`

```bash
# Source - https://stackoverflow.com/a/29747593
# Posted by Nivin V Joseph, modified by community. See post 'Timeline' for change history
# Retrieved 2026-09-17, License - CC BY-SA 4.0

# checar cuales archivos contienen CRLF line endings
grep -Il $'\r' ./scripts/*.sh

# aplicar a un solo archivo
sed -i -e 's/\r$//' ./scripts/<nombre_script>.sh

# aplicar a todos
sed -i -e 's/\r$//' ./scripts/*.sh
```
