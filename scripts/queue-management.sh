#!/bin/sh
# RabbitMQ Queue Management Scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/rabbitmq-api.sh"

# List all queues (optionally filtered by vhost)
list_queues() {
    local vhost="${1:-}"
    check_rabbitmq_accessible || return 1
    
    if [ -n "$vhost" ]; then
        local vhost_encoded=$(encode_vhost "$vhost")
        echo "Queues in vhost '${vhost}':"
        echo "=========================="
        api_call GET "/api/queues/${vhost_encoded}" | python3 -m json.tool 2>/dev/null || \
        api_call GET "/api/queues/${vhost_encoded}" | grep -o '"name":"[^"]*"' | sed 's/"name":"\(.*\)"/  - \1/'
    else
        echo "All Queues:"
        echo "==========="
        api_call GET "/api/queues" | python3 -m json.tool 2>/dev/null || \
        api_call GET "/api/queues" | grep -o '"name":"[^"]*","vhost":"[^"]*"' | sed 's/"name":"\([^"]*\)","vhost":"\([^"]*\)"/  - \1 (\2)/'
    fi
}

# Get queue information
queue_info() {
    local queue="$1"
    local vhost="${2:-/}"
    
    if [ -z "$queue" ]; then
        echo "Usage: queue_info <queue> [vhost]" >&2
        return 1
    fi
    
    check_rabbitmq_accessible || return 1
    
    local vhost_encoded=$(encode_vhost "$vhost")
    echo "Queue Information: ${queue} (vhost: ${vhost})"
    echo "=============================================="
    api_call GET "/api/queues/${vhost_encoded}/${queue}" | python3 -m json.tool
}

# Purge a queue
purge_queue() {
    local queue="$1"
    local vhost="${2:-/}"
    
    if [ -z "$queue" ]; then
        echo "Usage: purge_queue <queue> [vhost]" >&2
        return 1
    fi
    
    check_rabbitmq_accessible || return 1
    
    local vhost_encoded=$(encode_vhost "$vhost")
    if api_call DELETE "/api/queues/${vhost_encoded}/${queue}/contents" >/dev/null 2>&1; then
        echo "Queue '${queue}' purged successfully"
    else
        echo "Error: Failed to purge queue '${queue}'" >&2
        return 1
    fi
}

# Delete a queue
delete_queue() {
    local queue="$1"
    local vhost="${2:-/}"
    
    if [ -z "$queue" ]; then
        echo "Usage: delete_queue <queue> [vhost]" >&2
        return 1
    fi
    
    check_rabbitmq_accessible || return 1
    
    local vhost_encoded=$(encode_vhost "$vhost")
    if api_call DELETE "/api/queues/${vhost_encoded}/${queue}" >/dev/null 2>&1; then
        echo "Queue '${queue}' deleted successfully"
    else
        echo "Error: Failed to delete queue '${queue}'" >&2
        return 1
    fi
}

# Main command dispatcher
case "${1:-}" in
    list)
        list_queues "$2"
        ;;
    info)
        queue_info "$2" "$3"
        ;;
    purge)
        purge_queue "$2" "$3"
        ;;
    delete)
        delete_queue "$2" "$3"
        ;;
    *)
        echo "Usage: $0 {list|info|purge|delete}" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  list [vhost]           - List queues (optionally filtered by vhost)" >&2
        echo "  info <queue> [vhost]   - Get queue information" >&2
        echo "  purge <queue> [vhost]  - Purge all messages from a queue" >&2
        echo "  delete <queue> [vhost] - Delete a queue" >&2
        exit 1
        ;;
esac





