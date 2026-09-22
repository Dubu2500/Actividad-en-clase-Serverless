import boto3
import csv
import io
import os
import re
import urllib.parse

s3 = boto3.client("s3")

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

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["timestamp", "hostname", "program", "pid", "log"])

        for line in content.splitlines():
            line = line.strip()
            if not line:
                continue
            match = LOG_PATTERN.match(line)
            if match:
                writer.writerow([
                    match.group("timestamp"),
                    match.group("hostname"),
                    match.group("program"),
                    match.group("pid"),
                    match.group("log"),
                ])
            else:
                writer.writerow(["", "", "", "", line])

        filename = os.path.basename(key)
        csv_filename = os.path.splitext(filename)[0] + ".csv"
        output_key = f"output/{csv_filename}"

        s3.put_object(
            Bucket=bucket,
            Key=output_key,
            Body=output.getvalue().encode("utf-8"),
            ContentType="text/csv",
        )
        results.append(output_key)

    return {"statusCode": 200, "body": f"Generados: {results}"}
