"""
classify_log
------------
Se ejecuta dentro del estado Map, una vez por cada linea del batch.
Marca la linea como sospechosa si contiene alguno de los patrones de
SUSPICIOUS_PATTERNS. El estado Choice usa el campo "suspicious" para decidir
en que tabla de DynamoDB se guarda.

Entrada:  una linea de parse_batch
Salida:   la misma linea + {"suspicious": true/false, "alert_type": "...", "severity": "..."}
"""

# patron -> severidad de la alerta
SUSPICIOUS_PATTERNS = {
    "POSSIBLE BREAK-IN ATTEMPT": "HIGH",
    "Invalid user": "MEDIUM",
}
SEVERITY_ORDER = ["HIGH", "MEDIUM"]


def lambda_handler(event, context):
    text = event.get("raw") or event.get("log", "")
    matches = [p for p in SUSPICIOUS_PATTERNS if p in text]

    result = dict(event)
    result["suspicious"] = bool(matches)
    result["alert_type"] = ", ".join(matches) if matches else "NONE"

    # si hay varios patrones, se queda la severidad mas alta
    severities = [SUSPICIOUS_PATTERNS[m] for m in matches]
    result["severity"] = next((s for s in SEVERITY_ORDER if s in severities), "NONE")
    return result