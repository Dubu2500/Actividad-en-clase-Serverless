"""
start_workflow
--------------
Lambda que se dispara cuando llega un batch a s3://<bucket>/input/*.log
Su unica responsabilidad es iniciar una ejecucion de la maquina de estados
(Step Functions) mandandole el bucket y la key del archivo.

S3 no puede disparar Step Functions directamente, por eso usamos esta Lambda
(igual que validate_reporte en el demo de ReportGenerator).
"""
import json
import os
import re
import urllib.parse
import uuid

import boto3

STATE_MACHINE_ARN = os.environ.get("STATE_MACHINE_ARN")
sfn = boto3.client("stepfunctions")


def execution_name(key):
    # el nombre de la ejecucion debe ser unico, max 80 caracteres y sin caracteres raros
    base = os.path.splitext(os.path.basename(key))[0]
    base = re.sub(r"[^A-Za-z0-9_-]", "-", base)[:60]
    return f"{base}-{uuid.uuid4().hex[:8]}"


def lambda_handler(event, context):
    if not STATE_MACHINE_ARN:
        raise RuntimeError("Falta la variable de ambiente STATE_MACHINE_ARN")

    executions = []
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        response = sfn.start_execution(
            stateMachineArn=STATE_MACHINE_ARN,
            name=execution_name(key),
            input=json.dumps({"bucket": bucket, "key": key}),
        )
        print(f"Ejecucion iniciada para s3://{bucket}/{key}: {response['executionArn']}")
        executions.append(response["executionArn"])

    return {"statusCode": 200, "executions": executions}
