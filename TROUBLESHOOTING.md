# OpenTelemetry Logs Collector Troubleshooting Guide

This guide helps you diagnose and fix issues with the cronjob-scale-down-operator logs collector.

## 🔍 Quick Diagnostics

### Check Status
```bash
# Check collector status
make status

# Check specific pod
kubectl get pods -n opentelemetry-system -l app.kubernetes.io/name=opentelemetry-collector

# Check if secret exists
kubectl get secret grafana-cloud-config -n opentelemetry-system
```

### View Logs
```bash
# Follow collector logs
make logs

# View recent logs only
kubectl logs -n opentelemetry-system -l app.kubernetes.io/name=opentelemetry-collector --tail=50
```

## � Common Issues

### 1. Collector Pod Not Starting

**Symptoms:**
- Pod stuck in `Pending` or `CreateContainerConfigError`
- Error: `secret "grafana-cloud-config" not found`

**Solution:**
```bash
# Apply the secret
kubectl apply -f grafana-cloud-secret.yaml

# Restart the collector
make restart
```

### 2. No Logs Being Collected

**Symptoms:**
- Collector running but no logs in Grafana Cloud
- Message: "no files match the configured criteria"

**Diagnosis:**
```bash
# Check if target pod exists
kubectl get pods -A | grep cronjob-scale-down

# Check the actual log path
minikube ssh "sudo ls -la /var/log/pods/ | grep cronjob-scale-down"
```

**Solution:**
Update the log path in `otel-configs/otel-logs.yaml` to match your actual pod name:
```yaml
filelog:
  include:
    - /var/log/pods/NAMESPACE_POD_NAME*/*/*.log
```

### 3. Logs Rejected by Grafana Cloud

**Symptoms:**
- Export errors with HTTP 400 responses
- "timestamp too far behind" errors

**Common causes:**
- Incorrect auth token format
- Wrong OTLP endpoint
- Old log timestamps

**Solution:**
```bash
# Verify auth token (should be base64 of instance_id:api_key)
echo "INSTANCE_ID:API_KEY" | base64

# Check endpoint format (should include /otlp path)
# Correct: https://otlp-gateway-prod-REGION.grafana.net/otlp
# Wrong: https://otlp-gateway-prod-REGION.grafana.net
```

### 4. Log Parsing Errors

**Symptoms:**
- Parsing errors in collector logs
- Structured fields not extracted

**Diagnosis:**
```bash
# Check raw log format
minikube ssh "sudo tail -5 /var/log/pods/*/cronjob-scale-down*/*/*.log"
```

**Expected format:**
```json
{"log":"TIMESTAMP\tLEVEL\tMESSAGE\t{JSON_DATA}\n","stream":"stderr","time":"TIMESTAMP"}
```

### 5. High Resource Usage

**Symptoms:**
- Pod OOMKilled or CPU throttling
- Slow log processing

**Solution:**
Adjust resources in `otel-configs/otel-logs.yaml`:
```yaml
resources:
  limits:
    cpu: 500m      # Increase if needed
    memory: 1Gi    # Increase if needed
  requests:
    cpu: 100m
    memory: 256Mi

# Also adjust memory limiter
memory_limiter:
  limit_mib: 800   # Should be ~80% of memory limit
```

## 🛠️ Debugging Commands

### Check Configuration
```bash
# Validate configuration
make validate-config

# View applied configuration
kubectl get configmap -n opentelemetry-system -o yaml | grep -A 50 "config:"
```

### Network Connectivity
```bash
# Test connection to Grafana Cloud (from inside cluster)
kubectl run test-curl --rm -it --image=curlimages/curl -- \
  curl -v -H "Authorization: Basic YOUR_AUTH_TOKEN" \
  https://otlp-gateway-prod-REGION.grafana.net/otlp/v1/logs
```

### File Access
```bash
# Check if collector can access log files
kubectl exec -n opentelemetry-system deployment/otel-logs-collector -- \
  ls -la /var/log/pods/ | head -10
```

## 📊 Performance Monitoring

### Key Metrics to Watch
```bash
# Check memory usage
kubectl top pods -n opentelemetry-system

# Check for restarts
kubectl get pods -n opentelemetry-system -o wide
```

### Log Volume Analysis
```bash
# Count log files being monitored
kubectl exec -n opentelemetry-system deployment/otel-logs-collector -- \
  find /var/log/pods -name "*.log" | wc -l

# Check file sizes
kubectl exec -n opentelemetry-system deployment/otel-logs-collector -- \
  du -sh /var/log/pods/*/cronjob-scale-down*
```

## 🔧 Manual Testing

### Test Log Generation
```bash
# Force operator reconciliation (if applicable)
kubectl annotate cronjobscaledown cleanup-only-example test="$(date)"

# Or scale the operator to generate logs
kubectl scale deployment cronjob-scale-down-operator-controller-manager --replicas=0
kubectl scale deployment cronjob-scale-down-operator-controller-manager --replicas=1
```

### Verify Log Flow
```bash
# 1. Check logs are being written
minikube ssh "sudo tail -f /var/log/pods/*/cronjob-scale-down*/*/*.log"

# 2. Check collector is processing them
make logs | grep -i "filelog\|export"

# 3. Check in Grafana Cloud Loki
# Go to Grafana Cloud > Explore > Loki
# Query: {job="opentelemetry-collector"} | json
```

## 🔄 Recovery Steps

### Complete Reset
```bash
# 1. Remove everything
make clean

# 2. Recreate secret
kubectl apply -f grafana-cloud-secret.yaml

# 3. Reinstall collector
make install

# 4. Verify
make status
```

### Update Configuration
```bash
# 1. Make changes to otel-configs/otel-logs.yaml
# 2. Upgrade deployment
make upgrade

# 3. Check status
make status
```

## 📞 Getting Help

### Useful Information to Collect
```bash
# Collector status
make status

# Recent logs
kubectl logs -n opentelemetry-system -l app.kubernetes.io/name=opentelemetry-collector --tail=100

# Configuration
kubectl get configmap -n opentelemetry-system -o yaml

# Resource usage
kubectl top pods -n opentelemetry-system

# Target pod info
kubectl get pods -A | grep cronjob-scale-down
```

### External Resources
- [OpenTelemetry Collector Troubleshooting](https://opentelemetry.io/docs/collector/troubleshooting/)
- [Grafana Cloud Logs Documentation](https://grafana.com/docs/grafana-cloud/logs/)
- [OTLP Specification](https://opentelemetry.io/docs/specs/otlp/)

---

**Pro Tip**: Always check the collector logs first - they usually contain clear error messages that point to the exact issue.
# All collector logs
make logs

# Specific collector logs
kubectl logs -n opentelemetry-system deployment/otel-collector -f
kubectl logs -n opentelemetry-system daemonset/otel-collector-logs -f

# Filter for errors
kubectl logs -n opentelemetry-system deployment/otel-collector | grep -i error
```

## 🚨 Common Issues and Solutions

### 1. Collectors Not Starting

**Symptoms:**
- Pods stuck in `Pending` or `CrashLoopBackOff`
- Error messages about missing secrets or configurations

**Diagnostics:**
```bash
# Check pod status
kubectl describe pod -n opentelemetry-system -l app.kubernetes.io/name=opentelemetry-collector

# Check events
kubectl get events -n opentelemetry-system --sort-by=.metadata.creationTimestamp
```

**Common Causes & Solutions:**

#### Missing Grafana Cloud Secret
```bash
# Check if secret exists
kubectl get secret grafana-cloud-config -n opentelemetry-system

# If missing, create it
kubectl apply -f grafana-cloud-secret.yaml
```

#### Invalid Configuration
```bash
# Validate configuration
make validate-config

# Check for syntax errors
helm template otel-collector open-telemetry/opentelemetry-collector --values otel-configs/otel-global.yaml
```

#### Resource Constraints
```bash
# Check node resources
kubectl top nodes

# Check pod resource requests
kubectl describe pod -n opentelemetry-system [POD_NAME]
```

### 2. No Data in Grafana Cloud

**Symptoms:**
- Collectors running but no data appearing in Grafana Cloud
- Connection timeouts or authentication errors

**Diagnostics:**
```bash
# Test connectivity
make check-grafana-connection

# Check for export errors in logs
kubectl logs -n opentelemetry-system deployment/otel-collector | grep -i "export\|error\|failed"

# Check authentication
kubectl get secret grafana-cloud-config -n opentelemetry-system -o yaml
```

**Common Causes & Solutions:**

#### Wrong Grafana Cloud Endpoints
```bash
# Check your region and update endpoints
# US Central: https://otlp-gateway-prod-us-central-0.grafana.net/otlp
# EU West: https://otlp-gateway-prod-eu-west-0.grafana.net/otlp
```

#### Invalid Credentials
```bash
# Regenerate auth token
echo -n "INSTANCE_ID:API_KEY" | base64

# Update secret
kubectl patch secret grafana-cloud-config -n opentelemetry-system -p '{"stringData":{"auth-token":"NEW_TOKEN"}}'
```

#### Network Connectivity
```bash
# Test from collector pod
kubectl exec -n opentelemetry-system deployment/otel-collector -- \
  curl -v https://otlp-gateway-prod-us-central-0.grafana.net/otlp
```

### 3. High Memory Usage

**Symptoms:**
- Pods being OOMKilled
- High memory consumption alerts

**Diagnostics:**
```bash
# Check resource usage
kubectl top pods -n opentelemetry-system

# Check memory limits
kubectl describe pod -n opentelemetry-system [POD_NAME] | grep -A 5 -B 5 memory
```

**Solutions:**

#### Adjust Memory Limiter
```yaml
# In your configuration
memory_limiter:
  limit_mib: 800      # Reduce this value
  spike_limit_mib: 200
```

#### Reduce Batch Sizes
```yaml
batch:
  send_batch_size: 512    # Reduce from 1024
  send_batch_max_size: 1024  # Reduce from 2048
```

#### Increase Resource Limits
```yaml
resources:
  limits:
    memory: 2Gi  # Increase if needed
  requests:
    memory: 512Mi
```

### 4. Log Collection Issues

**Symptoms:**
- Missing logs from specific applications
- Logs not being parsed correctly

**Diagnostics:**
```bash
# Check if logs collector is running on all nodes
kubectl get pods -n opentelemetry-system -l app.kubernetes.io/name=opentelemetry-collector -o wide

# Check log file access
kubectl exec -n opentelemetry-system daemonset/otel-collector-logs -- ls -la /var/log/pods/

# Check for parsing errors
kubectl logs -n opentelemetry-system daemonset/otel-collector-logs | grep -i "parse\|error"
```

**Solutions:**

#### Missing Node Access
```bash
# Check node tolerations
kubectl describe daemonset -n opentelemetry-system otel-collector-logs | grep -A 10 Tolerations
```

#### Log Format Issues
```yaml
# Adjust operators in filelog receiver
operators:
  - type: json_parser
    id: parser-docker
    on_error: send  # Continue even if parsing fails
```

#### Permissions Issues
```bash
# Check if collector can read log files
kubectl exec -n opentelemetry-system daemonset/otel-collector-logs -- \
  ls -la /var/log/pods/your-namespace_your-pod_*/
```

### 5. Performance Issues

**Symptoms:**
- High CPU usage
- Slow log processing
- Backpressure warnings

**Diagnostics:**
```bash
# Check CPU usage
kubectl top pods -n opentelemetry-system

# Check collector metrics
kubectl port-forward -n opentelemetry-system svc/otel-collector 8888:8888
# Visit http://localhost:8888/metrics
```

**Solutions:**

#### Increase Parallelism
```yaml
# Add more replicas
replicaCount: 3

# Or use multiple pipelines
service:
  pipelines:
    logs/app1:
      receivers: [filelog]
      processors: [batch]
      exporters: [otlp/grafana]
    logs/app2:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/grafana]
```

#### Optimize Processors
```yaml
# Reduce processing overhead
batch:
  timeout: 5s  # Increase timeout
  send_batch_size: 2048  # Increase batch size

# Remove unnecessary processors
processors: [memory_limiter, batch]  # Minimal set
```

## 🔧 Advanced Debugging

### Enable Debug Logging
```yaml
# In collector configuration
service:
  telemetry:
    logs:
      level: "debug"  # Change from "info"
```

### Add Debug Exporter
```yaml
exporters:
  debug:
    verbosity: detailed  # Increase verbosity
    sampling_initial: 5   # Show more samples

service:
  pipelines:
    logs:
      exporters: [debug, otlp/grafana]  # Add debug exporter
```

### Monitor Collector Metrics
```bash
# Port forward to collector metrics
kubectl port-forward -n opentelemetry-system svc/otel-collector 8888:8888

# Key metrics to check:
# - otelcol_receiver_accepted_spans_total
# - otelcol_receiver_refused_spans_total
# - otelcol_exporter_sent_spans_total
# - otelcol_exporter_send_failed_spans_total
```

### Test Individual Components
```bash
# Test receivers
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -d '{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test"}}]},"scopeLogs":[{"scope":{},"logRecords":[{"body":{"stringValue":"test log"},"timeUnixNano":"1234567890000000000"}]}]}]}'

# Test exporters by checking collector logs for export attempts
```

## 📊 Health Checks

### Collector Health Endpoints
```bash
# Health check
kubectl exec -n opentelemetry-system deployment/otel-collector -- \
  curl http://localhost:13133/

# zPages (debugging info)
kubectl port-forward -n opentelemetry-system svc/otel-collector 55679:55679
# Visit http://localhost:55679/debug/tracez
```

### Configuration Validation
```bash
# Dry-run deployment
helm template otel-collector open-telemetry/opentelemetry-collector \
  --values otel-configs/otel-global.yaml \
  --namespace opentelemetry-system

# Check for validation errors
make validate-config
```

## 🆘 Getting Help

### Collect Diagnostic Information
```bash
# Create a debug bundle
mkdir otel-debug
kubectl get all -n opentelemetry-system -o yaml > otel-debug/resources.yaml
kubectl logs -n opentelemetry-system deployment/otel-collector --previous > otel-debug/collector-logs.txt
kubectl logs -n opentelemetry-system daemonset/otel-collector-logs --previous > otel-debug/logs-collector.txt
kubectl describe pods -n opentelemetry-system > otel-debug/pod-descriptions.txt
kubectl get events -n opentelemetry-system --sort-by=.metadata.creationTimestamp > otel-debug/events.txt
```

### Useful Resources
- [OpenTelemetry Collector Troubleshooting](https://opentelemetry.io/docs/collector/troubleshooting/)
- [Grafana Cloud OTLP Documentation](https://grafana.com/docs/grafana-cloud/send-data/otlp/)
- [Helm Chart Issues](https://github.com/open-telemetry/opentelemetry-helm-charts/issues)

### Community Support
- [OpenTelemetry Slack](https://cloud-native.slack.com/archives/C01NPBM2E23)
- [GitHub Issues](https://github.com/open-telemetry/opentelemetry-collector/issues)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/opentelemetry)
