#!/bin/sh
# RabbitMQ Management API Helper Functions
# Provides utilities for calling RabbitMQ Management HTTP API

set -e

# Load configuration file if it exists
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.rabbitmq-wizard.config"

# Function to load config file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # Source the config file, filtering out comments and empty lines
        while IFS='=' read -r key value || [ -n "$key" ]; do
            # Skip comments and empty lines
            case "$key" in
                \#*|"") continue ;;
            esac
            # Remove leading/trailing whitespace from key and value
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            # Only process if key is not empty
            if [ -n "$key" ]; then
                # Export the variable (only if not already set by environment)
                # Use eval carefully - only if key contains valid identifier characters
                case "$key" in
                    *[!a-zA-Z0-9_]*)
                        # Skip invalid variable names
                        continue
                        ;;
                    *)
                        # Safe to export
                        eval "export ${key}=\"${value}\""
                        ;;
                esac
            fi
        done < "$CONFIG_FILE"
    fi
}

# Load config file
load_config

# Default configuration (can be overridden by config file or environment)
# IMPORTANT: USE_PORT_FORWARD defaults to true
RABBITMQ_NAMESPACE="${RABBITMQ_NAMESPACE:-rabbitmq-system}"
RABBITMQ_SERVICE="${RABBITMQ_SERVICE:-rabbitmq}"
RABBITMQ_USER="${RABBITMQ_USER:-guest}"
RABBITMQ_PASS="${RABBITMQ_PASS:-guest}"
RABBITMQ_MANAGEMENT_PORT="${RABBITMQ_MANAGEMENT_PORT:-15672}"

# Check if we should use port-forward or direct service access
# Default to true - this is the recommended setting
USE_PORT_FORWARD="${USE_PORT_FORWARD:-true}"

# Normalize USE_PORT_FORWARD value (handle case variations)
case "$(echo "$USE_PORT_FORWARD" | tr '[:upper:]' '[:lower:]')" in
    true|1|yes|on|enabled)
        USE_PORT_FORWARD="true"
        ;;
    *)
        USE_PORT_FORWARD="false"
        ;;
esac
export USE_PORT_FORWARD

# Get NodePort number for a given port name
get_nodeport() {
    local port_name="$1"
    kubectl get svc "$RABBITMQ_SERVICE" -n "$RABBITMQ_NAMESPACE" -o jsonpath="{.spec.ports[?(@.name==\"${port_name}\")].nodePort}" 2>/dev/null || echo ""
}

# Get node IP (prefer external IP, fall back to internal, then localhost)
get_node_ip() {
    # Try to get external IP first
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
    
    if [ -z "$node_ip" ]; then
        # Fall back to internal IP
        node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    fi
    
    # If still empty, try localhost (for Docker Desktop, minikube, etc.)
    if [ -z "$node_ip" ]; then
        node_ip="localhost"
    fi
    
    echo "$node_ip"
}

# Check if service is NodePort type
is_nodeport() {
    local svc_type=$(kubectl get svc "$RABBITMQ_SERVICE" -n "$RABBITMQ_NAMESPACE" -o jsonpath='{.spec.type}' 2>/dev/null)
    [ "$svc_type" = "NodePort" ]
}

# Get the management API base URL
get_management_url() {
    # If explicitly set to use port-forward, use localhost (legacy support)
    if [ "$USE_PORT_FORWARD" = "true" ]; then
        # Check if NodePort is available first (preferred)
        if is_nodeport; then
            local nodeport=$(get_nodeport "management")
            local node_ip=$(get_node_ip)
            if [ -n "$nodeport" ]; then
                echo "http://${node_ip}:${nodeport}"
                return
            fi
        fi
        # Fall back to localhost (port-forward)
        echo "http://localhost:${RABBITMQ_MANAGEMENT_PORT}"
    # Check if NodePort is available (preferred method)
    elif is_nodeport; then
        local nodeport=$(get_nodeport "management")
        local node_ip=$(get_node_ip)
        if [ -n "$nodeport" ]; then
            echo "http://${node_ip}:${nodeport}"
            return
        fi
    # Otherwise, try to auto-detect by checking if localhost is accessible
    elif curl -s --max-time 2 "http://localhost:${RABBITMQ_MANAGEMENT_PORT}/api/whoami" >/dev/null 2>&1; then
        # Port-forward is likely active
        echo "http://localhost:${RABBITMQ_MANAGEMENT_PORT}"
    else
        # Fall back to service URL (works from within cluster)
        echo "http://${RABBITMQ_SERVICE}.${RABBITMQ_NAMESPACE}.svc.cluster.local:${RABBITMQ_MANAGEMENT_PORT}"
    fi
}

# Encode vhost for URL (default vhost "/" becomes "%2F")
encode_vhost() {
    local vhost="${1:-/}"
    echo "$vhost" | sed 's|/|%2F|g'
}

# Make API call
api_call() {
    local method="${1:-GET}"
    local endpoint="$2"
    local data="${3:-}"
    local url="$(get_management_url)${endpoint}"
    
    if [ -n "$data" ]; then
        curl -s -u "${RABBITMQ_USER}:${RABBITMQ_PASS}" \
            -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$url"
    else
        curl -s -u "${RABBITMQ_USER}:${RABBITMQ_PASS}" \
            -X "$method" \
            "$url"
    fi
}

# Check if RabbitMQ is accessible
check_rabbitmq_accessible() {
    local response
    response=$(api_call GET "/api/overview" 2>/dev/null || echo "")
    
    if [ -z "$response" ] || echo "$response" | grep -q "unauthorized\|error\|Connection refused\|Failed to connect"; then
        echo "Error: Cannot connect to RabbitMQ Management API" >&2
        echo "Make sure RabbitMQ is running and accessible." >&2
        echo "" >&2
        if is_nodeport; then
            local nodeport=$(get_nodeport "management")
            local node_ip=$(get_node_ip)
            if [ -n "$nodeport" ]; then
                echo "NodePort is configured. Try connecting to:" >&2
                echo "  http://${node_ip}:${nodeport}" >&2
                echo "" >&2
                echo "Run 'make connection-info' for full connection details." >&2
            fi
        else
            echo "Try one of the following:" >&2
            echo "  1. Run 'make connection-info' to see NodePort connection details" >&2
            echo "  2. Run 'make port-forward' in another terminal (legacy method)" >&2
            echo "  3. Use kubectl port-forward manually:" >&2
            echo "     kubectl port-forward -n ${RABBITMQ_NAMESPACE} svc/${RABBITMQ_SERVICE} ${RABBITMQ_MANAGEMENT_PORT}:${RABBITMQ_MANAGEMENT_PORT}" >&2
        fi
        return 1
    fi
    return 0
}

# Use kubectl exec for rabbitmqctl commands when API is not accessible
rabbitmqctl_exec() {
    local command="$1"
    kubectl exec -n "$RABBITMQ_NAMESPACE" deployment/rabbitmq -- rabbitmqctl "$command"
}

