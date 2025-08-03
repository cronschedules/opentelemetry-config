# OpenTelemetry Logs Collector Configuration Management
# This Makefile helps manage the OpenTelemetry logs collector for cronjob-scale-down-operator

# Variables
NAMESPACE ?= opentelemetry-system
RELEASE_NAME ?= otel-logs-collector
CHART_VERSION ?= 0.130.0
HELM_REPO_NAME ?= open-telemetry
HELM_REPO_URL ?= https://open-telemetry.github.io/opentelemetry-helm-charts

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help install-tools add-helm-repo install upgrade uninstall status logs create-namespace delete-namespace validate-config

help: ## Show this help message
	@echo "$(BLUE)OpenTelemetry Logs Collector Management$(NC)"
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install-tools: ## Install required tools (helm, kubectl)
	@echo "$(YELLOW)Checking for required tools...$(NC)"
	@which helm > /dev/null || (echo "$(RED)Helm not found. Please install helm first.$(NC)" && exit 1)
	@which kubectl > /dev/null || (echo "$(RED)kubectl not found. Please install kubectl first.$(NC)" && exit 1)
	@echo "$(GREEN)All required tools are installed.$(NC)"

add-helm-repo: install-tools ## Add OpenTelemetry Helm repository
	@echo "$(YELLOW)Adding OpenTelemetry Helm repository...$(NC)"
	helm repo add $(HELM_REPO_NAME) $(HELM_REPO_URL)
	helm repo update
	@echo "$(GREEN)Helm repository added successfully.$(NC)"

create-namespace: ## Create OpenTelemetry namespace
	@echo "$(YELLOW)Creating namespace $(NAMESPACE)...$(NC)"
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@echo "$(GREEN)Namespace $(NAMESPACE) created/updated.$(NC)"

validate-config: ## Validate OpenTelemetry logs configuration
	@echo "$(YELLOW)Validating OpenTelemetry logs configuration...$(NC)"
	@helm template $(RELEASE_NAME) $(HELM_REPO_NAME)/opentelemetry-collector \
		--values otel-configs/otel-logs.yaml \
		--namespace $(NAMESPACE) > /dev/null && \
	echo "$(GREEN)Logs configuration is valid.$(NC)" || \
	echo "$(RED)Logs configuration has errors.$(NC)"

install: add-helm-repo create-namespace validate-config ## Install OpenTelemetry logs collector
	@echo "$(YELLOW)Installing OpenTelemetry Logs Collector...$(NC)"
	helm upgrade --install $(RELEASE_NAME) $(HELM_REPO_NAME)/opentelemetry-collector \
		--values otel-configs/otel-logs.yaml \
		--namespace $(NAMESPACE) \
		--version $(CHART_VERSION) \
		--wait
	@echo "$(GREEN)OpenTelemetry Logs Collector installed successfully.$(NC)"

upgrade: validate-config ## Upgrade OpenTelemetry logs collector
	@echo "$(YELLOW)Upgrading OpenTelemetry Logs Collector...$(NC)"
	helm upgrade $(RELEASE_NAME) $(HELM_REPO_NAME)/opentelemetry-collector \
		--values otel-configs/otel-logs.yaml \
		--namespace $(NAMESPACE) \
		--version $(CHART_VERSION)
	@echo "$(GREEN)OpenTelemetry Logs Collector upgraded successfully.$(NC)"

uninstall: ## Uninstall OpenTelemetry logs collector
	@echo "$(YELLOW)Uninstalling OpenTelemetry Logs Collector...$(NC)"
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE) || true
	@echo "$(GREEN)OpenTelemetry Logs Collector uninstalled.$(NC)"

status: ## Show status of OpenTelemetry logs collector
	@echo "$(YELLOW)OpenTelemetry Logs Collector Status:$(NC)"
	@kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=opentelemetry-collector
	@echo "\n$(YELLOW)Services:$(NC)"
	@kubectl get svc -n $(NAMESPACE) -l app.kubernetes.io/name=opentelemetry-collector

logs: ## Show logs from OpenTelemetry logs collector
	@echo "$(YELLOW)OpenTelemetry Logs Collector Logs:$(NC)"
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=opentelemetry-collector --tail=100 -f

delete-namespace: uninstall ## Delete OpenTelemetry namespace
	@echo "$(YELLOW)Deleting namespace $(NAMESPACE)...$(NC)"
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@echo "$(GREEN)Namespace $(NAMESPACE) deleted.$(NC)"

restart: ## Restart OpenTelemetry logs collector
	@echo "$(YELLOW)Restarting OpenTelemetry logs collector...$(NC)"
	kubectl rollout restart daemonset -n $(NAMESPACE) -l app.kubernetes.io/name=opentelemetry-collector
	@echo "$(GREEN)Logs collector restarted.$(NC)"

clean: uninstall delete-namespace ## Clean up everything