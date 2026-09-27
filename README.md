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