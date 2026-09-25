"""
parse_batch
-----------
Primer paso de la maquina de estados.
Descarga el batch de S3 y lo separa en lineas individuales (ya parseadas en
timestamp, hostname, program, pid, log). NO escribe nada a DynamoDB: eso lo
hacen los estados de la maquina despues de clasificar cada linea.

Entrada:  {"bucket": "...", "key": "input/openssh-XXXX.log"}
Salida:   {"bucket": "...", "key": "...", "total_lines": N, "lines": [ {...}, ... ]}
"""
import re

import boto3

s3 = boto3.client("s3")

LOG_PATTERN = re.compile(
    r'^(?P<timestamp>\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+'
    r'(?P<hostname>\S+)\s+'
    r'(?P<program>[^\[\s]+)\[(?P<pid>\d+)\]:\s*'
    r'(?P<log>.*)$'
)


def parse_line(source_file, line_number, line):
    # todos los campos siempre existen (como string) para que la maquina de
    # estados pueda armar el item de DynamoDB sin que falte ninguna ruta
    item = {
        "source_file": source_file,
        "line_number": line_number,
        "timestamp": "",
        "hostname": "",
        "program": "",
        "pid": "0",
        "log": line,
        "raw": line,
    }
    match = LOG_PATTERN.match(line)
    if match:
        item.update(match.groupdict())
    return item


def lambda_handler(event, context):
    bucket = event["bucket"]
    key = event["key"]

    response = s3.get_object(Bucket=bucket, Key=key)
    content = response["Body"].read().decode("utf-8", errors="replace")

    lines = []
    for line_number, line in enumerate(content.splitlines(), start=1):
        line = line.strip()
        if line:
            lines.append(parse_line(key, line_number, line))

    print(f"s3://{bucket}/{key}: {len(lines)} lineas")
    return {"bucket": bucket, "key": key, "total_lines": len(lines), "lines": lines}
