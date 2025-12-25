#!/bin/sh
# RabbitMQ Health Check and Diagnostics

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/rabbitmq-api.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print status
print_status() {
    local status="$1"
    local message="$2"
    if [ "$status" = "OK" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    else
        echo -e "${RED}✗${NC} $message"
    fi
}

# Check RabbitMQ pod status
check_pod_status() {
    echo "Checking RabbitMQ Pod Status..."
    echo "==============================="
    
    local pod_status=$(kubectl get pods -n "$RABBITMQ_NAMESPACE" -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
    
    if [ "$pod_status" = "Running" ]; then
        print_status "OK" "Pod is Running"
        
        local ready=$(kubectl get pods -n "$RABBITMQ_NAMESPACE" -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
        if [ "$ready" = "True" ]; then
            print_status "OK" "Pod is Ready"
        else
            print_status "WARN" "Pod is not fully ready"
        fi
    else
        print_status "FAIL" "Pod status: ${pod_status}"
        return 1
    fi
    echo ""
}

# Check Management API accessibility
check_management_api() {
    echo "Checking Management API..."
    echo "=========================="
    
    if check_rabbitmq_accessible; then
        local overview=$(api_call GET "/api/overview")
        local version=$(echo "$overview" | grep -o '"rabbitmq_version":"[^"]*"' | head -1 | sed 's/"rabbitmq_version":"\(.*\)"/\1/' || echo "unknown")
        local management_version=$(echo "$overview" | grep -o '"management_version":"[^"]*"' | head -1 | sed 's/"management_version":"\(.*\)"/\1/' || echo "unknown")
        
        print_status "OK" "Management API is accessible"
        print_status "OK" "RabbitMQ Version: ${version}"
        print_status "OK" "Management Version: ${management_version}"
    else
        print_status "FAIL" "Cannot connect to Management API"
        return 1
    fi
    echo ""
}

# Check node health
check_node_health() {
    echo "Checking Node Health..."
    echo "======================"
    
    if ! check_rabbitmq_accessible; then
        return 1
    fi
    
    local nodes=$(api_call GET "/api/nodes")
    local node_count=$(echo "$nodes" | grep -o '"name"' | wc -l | tr -d ' ')
    
    if [ "$node_count" -gt 0 ]; then
        print_status "OK" "Found ${node_count} node(s)"
        
        # Check if any nodes are running
        local running_nodes=$(echo "$nodes" | grep -o '"running":true' | wc -l | tr -d ' ')
        if [ "$running_nodes" -gt 0 ]; then
            print_status "OK" "${running_nodes} node(s) running"
        else
            print_status "FAIL" "No nodes are running"
        fi
    else
        print_status "FAIL" "No nodes found"
    fi
    echo ""
}

# Check memory usage
check_memory() {
    echo "Checking Memory Usage..."
    echo "========================"
    
    if ! check_rabbitmq_accessible; then
        return 1
    fi
    
    local overview=$(api_call GET "/api/overview")
    local memory_used=$(echo "$overview" | grep -o '"memory":[0-9]*' | head -1 | sed 's/"memory"://' || echo "0")
    
    if [ "$memory_used" != "0" ]; then
        # Convert bytes to MB
        local memory_mb=$((memory_used / 1024 / 1024))
        print_status "OK" "Memory used: ${memory_mb} MB"
        
        # Check if memory is reasonable (less than 1GB = 1024MB)
        if [ "$memory_mb" -lt 1024 ]; then
            print_status "OK" "Memory usage is within normal range"
        else
            print_status "WARN" "Memory usage is high (${memory_mb} MB)"
        fi
    else
        print_status "WARN" "Could not retrieve memory information"
    fi
    echo ""
}

# Check disk usage
check_disk() {
    echo "Checking Disk Usage..."
    echo "======================"
    
    if ! check_rabbitmq_accessible; then
        return 1
    fi
    
    local nodes=$(api_call GET "/api/nodes")
    local disk_free=$(echo "$nodes" | grep -o '"disk_free":[0-9]*' | head -1 | sed 's/"disk_free"://' || echo "0")
    
    if [ "$disk_free" != "0" ]; then
        # Convert bytes to GB
        local disk_gb=$((disk_free / 1024 / 1024 / 1024))
        print_status "OK" "Disk free: ${disk_gb} GB"
        
        # Check if disk space is reasonable (more than 1GB)
        if [ "$disk_gb" -gt 1 ]; then
            print_status "OK" "Sufficient disk space available"
        else
            print_status "WARN" "Low disk space (${disk_gb} GB free)"
        fi
    else
        print_status "WARN" "Could not retrieve disk information"
    fi
    echo ""
}

# Check queue status
check_queues() {
    echo "Checking Queues..."
    echo "=================="
    
    if ! check_rabbitmq_accessible; then
        return 1
    fi
    
    local queues=$(api_call GET "/api/queues")
    local queue_count=$(echo "$queues" | grep -o '"name"' | wc -l | tr -d ' ')
    
    if [ "$queue_count" -gt 0 ]; then
        print_status "OK" "Found ${queue_count} queue(s)"
        
        # Check for queues with high message counts
        local high_msg_queues=$(echo "$queues" | grep -o '"messages":[0-9]*' | sed 's/"messages"://' | awk '$1 > 1000' | wc -l | tr -d ' ')
        if [ "$high_msg_queues" -gt 0 ]; then
            print_status "WARN" "${high_msg_queues} queue(s) have more than 1000 messages"
        fi
    else
        print_status "OK" "No queues found (this is normal for a fresh installation)"
    fi
    echo ""
}

# Check connections
check_connections() {
    echo "Checking Connections..."
    echo "======================"
    
    if ! check_rabbitmq_accessible; then
        return 1
    fi
    
    local connections=$(api_call GET "/api/connections")
    local conn_count=$(echo "$connections" | grep -o '"name"' | wc -l | tr -d ' ')
    
    if [ "$conn_count" -gt 0 ]; then
        print_status "OK" "Active connections: ${conn_count}"
    else
        print_status "OK" "No active connections"
    fi
    echo ""
}

# Run rabbitmqctl diagnostics
run_diagnostics() {
    echo "Running RabbitMQ Diagnostics..."
    echo "==============================="
    
    rabbitmqctl_exec "status" || {
        print_status "FAIL" "Could not run diagnostics"
        return 1
    }
    echo ""
}

# Comprehensive health check
comprehensive_check() {
    echo "RabbitMQ Health Check"
    echo "====================="
    echo ""
    
    local failed=0
    
    check_pod_status || failed=$((failed + 1))
    check_management_api || failed=$((failed + 1))
    check_node_health || failed=$((failed + 1))
    check_memory || failed=$((failed + 1))
    check_disk || failed=$((failed + 1))
    check_queues || failed=$((failed + 1))
    check_connections || failed=$((failed + 1))
    
    echo "====================="
    if [ "$failed" -eq 0 ]; then
        echo -e "${GREEN}Health Check: PASSED${NC}"
        return 0
    else
        echo -e "${RED}Health Check: FAILED (${failed} check(s) failed)${NC}"
        return 1
    fi
}

# Main command dispatcher
case "${1:-check}" in
    check|full)
        comprehensive_check
        ;;
    pod)
        check_pod_status
        ;;
    api)
        check_management_api
        ;;
    node)
        check_node_health
        ;;
    memory)
        check_memory
        ;;
    disk)
        check_disk
        ;;
    queues)
        check_queues
        ;;
    connections)
        check_connections
        ;;
    diagnostics)
        run_diagnostics
        ;;
    *)
        echo "Usage: $0 {check|pod|api|node|memory|disk|queues|connections|diagnostics}" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  check          - Run comprehensive health check (default)" >&2
        echo "  pod            - Check pod status only" >&2
        echo "  api            - Check Management API only" >&2
        echo "  node           - Check node health only" >&2
        echo "  memory         - Check memory usage only" >&2
        echo "  disk           - Check disk usage only" >&2
        echo "  queues         - Check queue status only" >&2
        echo "  connections    - Check connections only" >&2
        echo "  diagnostics    - Run rabbitmqctl diagnostics" >&2
        exit 1
        ;;
esac





