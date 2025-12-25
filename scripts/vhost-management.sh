#!/bin/sh
# RabbitMQ Virtual Host Management Scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/rabbitmq-api.sh"

# List all vhosts
list_vhosts() {
    check_rabbitmq_accessible || return 1
    
    echo "Virtual Hosts:"
    echo "=============="
    api_call GET "/api/vhosts" | python3 -m json.tool 2>/dev/null || \
    api_call GET "/api/vhosts" | grep -o '"name":"[^"]*"' | sed 's/"name":"\(.*\)"/  - \1/'
}

# Create a vhost
create_vhost() {
    local vhost="$1"
    
    if [ -z "$vhost" ]; then
        echo "Usage: create_vhost <vhost>" >&2
        return 1
    fi
    
    check_rabbitmq_accessible || return 1
    
    local vhost_encoded=$(encode_vhost "$vhost")
    if api_call PUT "/api/vhosts/${vhost_encoded}" "{}" >/dev/null 2>&1; then
        echo "Virtual host '${vhost}' created successfully"
    else
        echo "Error: Failed to create virtual host '${vhost}'" >&2
        return 1
    fi
}

# Delete a vhost
delete_vhost() {
    local vhost="$1"
    
    if [ -z "$vhost" ]; then
        echo "Usage: delete_vhost <vhost>" >&2
        return 1
    fi
    
    check_rabbitmq_accessible || return 1
    
    local vhost_encoded=$(encode_vhost "$vhost")
    if api_call DELETE "/api/vhosts/${vhost_encoded}" >/dev/null 2>&1; then
        echo "Virtual host '${vhost}' deleted successfully"
    else
        echo "Error: Failed to delete virtual host '${vhost}'" >&2
        return 1
    fi
}

# Get vhost information
vhost_info() {
    local vhost="${1:-/}"
    
    check_rabbitmq_accessible || return 1
    
    local vhost_encoded=$(encode_vhost "$vhost")
    echo "Virtual Host Information: ${vhost}"
    echo "==================================="
    api_call GET "/api/vhosts/${vhost_encoded}" | python3 -m json.tool
}

# Main command dispatcher
case "${1:-}" in
    list)
        list_vhosts
        ;;
    create)
        create_vhost "$2"
        ;;
    delete)
        delete_vhost "$2"
        ;;
    info)
        vhost_info "$2"
        ;;
    *)
        echo "Usage: $0 {list|create|delete|info}" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  list              - List all virtual hosts" >&2
        echo "  create <vhost>    - Create a virtual host" >&2
        echo "  delete <vhost>    - Delete a virtual host" >&2
        echo "  info [vhost]      - Get virtual host information (default: /)" >&2
        exit 1
        ;;
esac





