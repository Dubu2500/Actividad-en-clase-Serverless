"""
get_logs
--------
GET /logs?top=N  (API Gateway HTTP API, Lambda proxy integration, payload 2.0)

Regresa los ultimos N logs guardados en la tabla Logs.
Las fechas del log de ejemplo son viejas y fijas, por eso se ordena por
received_at (LastModified del batch en S3, la hora real en que llego).

Hace Query (no Scan) sobre el indice RecentLogsIndex:
  partition key: gsi_pk = "LOG"
  sort key:      received_at
con Limit=N y ScanIndexForward=False (los mas recientes primero).
"""
import json
import os
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key

LOGS_TABLE = os.environ.get("LOGS_TABLE", "logging-apiserverless-iteso-tabla")
INDEX_NAME = "RecentLogsIndex"
DEFAULT_TOP = 10
MAX_TOP = 1000

table = boto3.resource("dynamodb").Table(LOGS_TABLE)


def response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, ensure_ascii=False,
                           default=lambda o: int(o) if isinstance(o, Decimal) else str(o)),
    }


def to_log(item):
    return {
        "source_file": item.get("source_file"),
        "line_number": item.get("line_number"),
        "timestamp": item.get("timestamp"),
        "hostname": item.get("hostname"),
        "program": item.get("program"),
        "pid": item.get("pid"),
        "log": item.get("log"),
        "received_at": item.get("received_at"),
    }


def lambda_handler(event, context):
    params = event.get("queryStringParameters") or {}
    try:
        top = int(params.get("top", DEFAULT_TOP))
        if not 1 <= top <= MAX_TOP:
            raise ValueError
    except ValueError:
        return response(400, {"error": f"top debe ser un entero entre 1 y {MAX_TOP}"})

    result = table.query(
        IndexName=INDEX_NAME,
        KeyConditionExpression=Key("gsi_pk").eq("LOG"),
        ScanIndexForward=False,
        Limit=top,
    )
    logs = [to_log(i) for i in result["Items"]]

    return response(200, {"top": top, "count": len(logs), "logs": logs})