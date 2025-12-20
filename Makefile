# RabbitMQ External Service Management
# Main Makefile that includes modular components

include Makefile.kubernetes
include Makefile.management

.PHONY: help wizard setup teardown status logs shell port-forward cleanup connection-info

# Default target
help: ## Show this help message
	@echo "RabbitMQ External Service Management"
	@echo "===================================="
	@echo ""
	@echo "This project provides a centralized RabbitMQ system for Kubernetes."
	@echo "The RabbitMQ instance is deployed in the 'rabbitmq-system' namespace"
	@echo "and can be accessed from other namespaces in the cluster."
	@echo ""
	@echo "Quick Start:"
	@echo "  make setup          # Deploy RabbitMQ to Kubernetes"
	@echo "  make connection-info # Show NodePort connection details (no port-forward needed!)"
	@echo "  make teardown       # Remove RabbitMQ from Kubernetes"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: rabbitmq-setup ## Deploy RabbitMQ to Kubernetes
	@echo ""
	@echo "Setup complete! RabbitMQ is now running in the rabbitmq-system namespace."
	@echo "Use 'make connection-info' to see NodePort connection details."

teardown: rabbitmq-teardown ## Remove RabbitMQ from Kubernetes

status: rabbitmq-status ## Show RabbitMQ status

logs: rabbitmq-logs ## Show RabbitMQ logs

shell: rabbitmq-shell ## Access RabbitMQ shell

port-forward: rabbitmq-port-forward ## Port forward RabbitMQ services for local access (deprecated: use NodePort instead)

connection-info: rabbitmq-connection-info ## Show NodePort connection information for RabbitMQ

cleanup: rabbitmq-cleanup ## Clean up all RabbitMQ resources (including data)

wizard: ## Interactive menu to select and run make targets
	@./scripts/wizard.sh










