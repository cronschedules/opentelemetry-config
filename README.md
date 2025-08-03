# OpenTelemetry Logs Collector for Cronjob Scale Down Operator

A simplified OpenTelemetry logs collector setup specifically designed to collect logs from the `cronjob-scale-down-operator-controller-manager` pod and send them to Grafana Cloud via OTLP.

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster
- Helm 3.x
- kubectl configured for your cluster
- Grafana Cloud account with API key

### Setup

1. **Configure Grafana Cloud credentials:**
   ```bash
   # Copy the template and update with your credentials
   cp grafana-cloud-secret-template.yaml grafana-cloud-secret.yaml
   # Edit grafana-cloud-secret.yaml with your actual credentials
   kubectl apply -f grafana-cloud-secret.yaml
   ```

2. **Deploy the logs collector:**
   ```bash
   make install
   ```

3. **Check status:**
   ```bash
   make status
   ```

## 📁 Repository Structure

```
.
├── Makefile                           # Management commands
├── README.md                          # This file
├── TROUBLESHOOTING.md                 # Troubleshooting guide
├── grafana-cloud-secret-template.yaml # Grafana Cloud credentials template
└── otel-configs/
    └── otel-logs.yaml                 # Logs collector configuration (DaemonSet)
```

> **Note**: `grafana-cloud-secret.yaml` (your actual credentials) is ignored by git for security.

## 🎯 What This Does

- **Monitors**: `cronjob-scale-down-operator-controller-manager` pod logs only
- **Parses**: Structured JSON logs with controller metadata extraction
- **Exports**: Logs to Grafana Cloud Loki via OTLP HTTP
- **Enriches**: Adds Kubernetes metadata and structured attributes

### Extracted Log Fields

From this log format:
```json
{"log":"2025-08-03T22:00:00Z\tINFO\tRequeuing for next event\t{\"controller\": \"cronjobscaledown\", \"controllerGroup\": \"cronschedules.elbazi.co\", \"reconcileID\": \"71dc25fa...\"}\n","stream":"stderr","time":"2025-08-03T22:00:00.032Z"}
```

The collector extracts:
- ✅ **`k8s.controller.name`**: `"cronjobscaledown"`
- ✅ **`k8s.controller.group`**: `"cronschedules.elbazi.co"`  
- ✅ **`k8s.controller.kind`**: `"CronJobScaleDown"`
- ✅ **`reconcile.id`**: `"71dc25fa-1ed2-4bd2-bfd9-e3e9eeb3c735"`
- ✅ **`log.level`**: `"INFO"`
- ✅ **`log.message`**: `"Requeuing for next event"`
- ✅ **`log.source`**: `"cronjob-scale-down-operator"`

## 🔧 Available Commands

```bash
# Deployment
make install                 # Install logs collector
make upgrade                 # Upgrade logs collector
make uninstall              # Remove logs collector

# Management  
make status                 # Check deployment status
make logs                   # View collector logs (follow mode)
make restart                # Restart the collector

# Maintenance
make clean                  # Complete cleanup (removes namespace)
make validate-config        # Validate configuration
```

## ⚙️ Configuration

### Grafana Cloud Setup

1. **Get your credentials:**
   - Instance ID: Found in Grafana Cloud settings
   - API Key: Create from Access Policies with Logs:Write permission

2. **Update the secret:**
   ```yaml
   # grafana-cloud-secret.yaml
   stringData:
     instance-id: "YOUR_INSTANCE_ID"
     loki-otlp-endpoint: "https://otlp-gateway-prod-YOUR-REGION.grafana.net/otlp"
     auth-token: "BASE64_OF_INSTANCE_ID:API_KEY"
   ```

3. **Generate auth-token:**
   ```bash
   echo -n "YOUR_INSTANCE_ID:YOUR_API_KEY" | base64
   ```

### Pod Targeting

The collector is configured to monitor logs from:
```
/var/log/pods/default_cronjob-scale-down-operator-controller-manager*/*/*.log
```

If your pod is in a different namespace or has a different name, update the path in `otel-configs/otel-logs.yaml`:
```yaml
filelog:
  include:
    - /var/log/pods/YOUR_NAMESPACE_YOUR_POD_NAME*/*/*.log
```

## 🔍 Troubleshooting

### Check if collector is running:
```bash
make status
```

### View collector logs:
```bash
make logs
```

### Common issues:

1. **Secret not found:**
   ```bash
   kubectl get secret grafana-cloud-config -n opentelemetry-system
   ```

2. **No logs being collected:**
   - Verify the cronjob-scale-down-operator pod exists
   - Check the file path pattern matches your pod name
   - Look for "Started watching file" in collector logs

3. **Logs rejected by Grafana Cloud:**
   - Check auth token is correct (base64 encoded instance_id:api_key)
   - Verify OTLP endpoint URL for your region
   - Ensure logs are not too old (Grafana Cloud has retention limits)

## � Resource Usage

The collector is configured with minimal resources:
- **CPU**: 50m request, 300m limit
- **Memory**: 128Mi request, 512Mi limit
- **Mode**: DaemonSet (runs on all nodes)

## 🔒 Security

- Service account with minimal RBAC permissions (pods, namespaces read-only)
- Runs as root (required for reading log files from host)
- Secrets properly mounted and not exposed in logs

---

This setup provides focused, efficient log collection specifically for the cronjob-scale-down-operator with rich structured data extraction for better observability in Grafana Cloud.