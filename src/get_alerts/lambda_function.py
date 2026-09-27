"""
get_alerts
----------
GET /alerts  (API Gateway HTTP API, Lambda proxy integration, payload 2.0)

Hace Query (no Scan) sobre el indice ActiveAlertsIndex de SecurityAlerts:
  partition key: alert_status = "ACTIVE"
  sort key:      detected_at  (las mas recientes primero)

Query params opcionales:
  ?limit=N   maximo de alertas a regresar (default 100, max 1000)
"""
import json
import os
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key

ALERTS_TABLE = os.environ.get("ALERTS_TABLE", "SecurityAlerts")
INDEX_NAME = "ActiveAlertsIndex"
DEFAULT_LIMIT = 100
MAX_LIMIT = 1000

table = boto3.resource("dynamodb").Table(ALERTS_TABLE)


def response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        # el body debe ser string; default convierte los Decimal de DynamoDB
        "body": json.dumps(body, ensure_ascii=False,
                           default=lambda o: int(o) if isinstance(o, Decimal) else str(o)),
    }


def to_alert(item):
    return {
        "id": f"{item['source_file']}#{item['line_number']}",
        "timestamp": item.get("timestamp"),
        "host": item.get("hostname"),
        "log": item.get("log"),
        "severity": item.get("severity"),
        "alert_type": item.get("alert_type"),
        "detected_at": item.get("detected_at"),
    }


def lambda_handler(event, context):
    params = event.get("queryStringParameters") or {}
    try:
        limit = int(params.get("limit", DEFAULT_LIMIT))
        if not 1 <= limit <= MAX_LIMIT:
            raise ValueError
    except ValueError:
        return response(400, {"error": f"limit debe ser un entero entre 1 y {MAX_LIMIT}"})

    alerts = []
    kwargs = {
        "IndexName": INDEX_NAME,
        "KeyConditionExpression": Key("alert_status").eq("ACTIVE"),
        "ScanIndexForward": False,
    }
    # Query regresa maximo 1 MB por pagina, por eso se pagina hasta juntar "limit"
    while len(alerts) < limit:
        result = table.query(Limit=limit - len(alerts), **kwargs)
        alerts.extend(to_alert(i) for i in result["Items"])
        if "LastEvaluatedKey" not in result:
            break
        kwargs["ExclusiveStartKey"] = result["LastEvaluatedKey"]

    return response(200, {"count": len(alerts), "alerts": alerts})