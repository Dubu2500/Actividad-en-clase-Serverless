import os
import re
import urllib.parse

import boto3

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

TABLE_NAME = os.environ.get("TABLE_NAME", "logging-apiserverless-iteso-tabla")
table = dynamodb.Table(TABLE_NAME)

LOG_PATTERN = re.compile(
    r'^(?P<timestamp>\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+'
    r'(?P<hostname>\S+)\s+'
    r'(?P<program>[^\[\s]+)\[(?P<pid>\d+)\]:\s*'
    r'(?P<log>.*)$'
)


def lambda_handler(event, context):
    results = []

    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        response = s3.get_object(Bucket=bucket, Key=key)
        content = response["Body"].read().decode("utf-8")

        written = 0

        # batch_writer agrupa en lotes de 25 y reintenta los items no procesados
        with table.batch_writer() as batch:
            for line_number, line in enumerate(content.splitlines(), start=1):
                line = line.strip()
                if not line:
                    continue

                item = {
                    "source_file": key,
                    "line_number": line_number,
                }

                match = LOG_PATTERN.match(line)
                if match:
                    item.update({
                        "timestamp": match.group("timestamp"),
                        "hostname": match.group("hostname"),
                        "program": match.group("program"),
                        "pid": int(match.group("pid")),
                        "log": match.group("log"),
                    })
                else:
                    # si hay una linea sin el formato esperado se guarda solo el texto raw
                    item["log"] = line

                batch.put_item(Item=item)
                written += 1

        results.append({"file": key, "items": written})

    return {"statusCode": 200, "body": f"Procesados: {results}"}