"""
classify_log
------------
Se ejecuta dentro del estado Map, una vez por cada linea del batch.
Marca la linea como sospechosa si contiene alguno de los patrones de
SUSPICIOUS_PATTERNS. El estado Choice usa el campo "suspicious" para decidir
en que tabla de DynamoDB se guarda.

Entrada:  una linea de parse_batch
Salida:   la misma linea + {"suspicious": true/false, "alert_type": "..."}
"""

SUSPICIOUS_PATTERNS = [
    "Invalid user",
    "POSSIBLE BREAK-IN ATTEMPT",
]


def lambda_handler(event, context):
    text = event.get("raw") or event.get("log", "")
    matches = [p for p in SUSPICIOUS_PATTERNS if p in text]

    result = dict(event)
    result["suspicious"] = bool(matches)
    result["alert_type"] = ", ".join(matches) if matches else "NONE"
    return result
