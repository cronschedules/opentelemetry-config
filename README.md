# OpenTelemetry Logs Collector

Collects logs from Kubernetes pods and sends them to Grafana Cloud.

## What's included

- `otel-configs/otel-logs.yaml` - OpenTelemetry collector configuration
- `Makefile` - Deployment commands
- `grafana-cloud-secret-template.yaml` - Grafana Cloud credentials template

## Usage

```bash
make install    # Deploy
make status     # Check status
make logs       # View logs
```

Logs are parsed and the actual log message is extracted into a clean `message` field.
