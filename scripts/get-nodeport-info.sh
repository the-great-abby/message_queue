#!/bin/sh
# Get RabbitMQ NodePort connection information
# This script retrieves the NodePort numbers and node IP for connecting to RabbitMQ

set -e

RABBITMQ_NAMESPACE="${RABBITMQ_NAMESPACE:-rabbitmq-system}"
RABBITMQ_SERVICE="${RABBITMQ_SERVICE:-rabbitmq}"

# Get NodePort numbers from the service
get_nodeport() {
    local port_name="$1"
    kubectl get svc "$RABBITMQ_SERVICE" -n "$RABBITMQ_NAMESPACE" -o jsonpath="{.spec.ports[?(@.name==\"${port_name}\")].nodePort}" 2>/dev/null || echo ""
}

# Get node IP (prefer external IP, fall back to internal)
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

# Get all NodePort info
AMQP_NODEPORT=$(get_nodeport "amqp")
MANAGEMENT_NODEPORT=$(get_nodeport "management")
PROMETHEUS_NODEPORT=$(get_nodeport "prometheus")
NODE_IP=$(get_node_ip)

# Export for use in Makefile
export AMQP_NODEPORT
export MANAGEMENT_NODEPORT
export PROMETHEUS_NODEPORT
export NODE_IP

# Print connection info
echo "RabbitMQ NodePort Connection Information"
echo "========================================"
echo ""
if [ -n "$AMQP_NODEPORT" ] && [ -n "$MANAGEMENT_NODEPORT" ] && [ -n "$PROMETHEUS_NODEPORT" ]; then
    echo "📍 Node IP: $NODE_IP"
    echo ""
    echo "🔌 External Access (NodePort):"
    echo "  AMQP (Message Queue):     $NODE_IP:$AMQP_NODEPORT"
    echo "  Management UI:              http://$NODE_IP:$MANAGEMENT_NODEPORT"
    echo "  Prometheus Metrics:       http://$NODE_IP:$PROMETHEUS_NODEPORT"
    echo ""
    echo "🏠 Internal Cluster Access (ClusterIP):"
    echo "  AMQP:                      ${RABBITMQ_SERVICE}.${RABBITMQ_NAMESPACE}.svc.cluster.local:5672"
    echo "  Management UI:              http://${RABBITMQ_SERVICE}.${RABBITMQ_NAMESPACE}.svc.cluster.local:15672"
    echo "  Prometheus Metrics:         http://${RABBITMQ_SERVICE}.${RABBITMQ_NAMESPACE}.svc.cluster.local:15692"
    echo ""
    echo "📝 Migration Notice - Update your services:"
    echo "  ⚠️  Port-forwarding is deprecated. Use NodePort instead!"
    echo ""
    echo "  Old (port-forward):"
    echo "    - AMQP: localhost:5672"
    echo "    - Management: http://localhost:15672"
    echo ""
    echo "  New (NodePort):"
    echo "    - AMQP: $NODE_IP:$AMQP_NODEPORT"
    echo "    - Management: http://$NODE_IP:$MANAGEMENT_NODEPORT"
    echo ""
    echo "  The NodePort numbers are fixed and stable (no more port-forward crashes!)"
    echo ""
else
    echo "⚠️  Warning: Could not retrieve NodePort information."
    echo "   Make sure RabbitMQ is deployed and the service is configured as NodePort."
    echo "   Run: kubectl get svc $RABBITMQ_SERVICE -n $RABBITMQ_NAMESPACE"
    exit 1
fi
