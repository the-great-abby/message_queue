#!/bin/sh
# RabbitMQ User Management Scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/rabbitmq-api.sh"

# List all users
list_users() {
    check_rabbitmq_accessible || return 1
    
    echo "RabbitMQ Users:"
    echo "==============="
    api_call GET "/api/users" | python3 -m json.tool 2>/dev/null || \
    api_call GET "/api/users" | grep -o '"name":"[^"]*"' | sed 's/"name":"\(.*\)"/  - \1/'
}

# Create a user
create_user() {
    local username="$1"
    local password="$2"
    local tags="${3:-}"
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        echo "Usage: create_user <username> <password> [tags]" >&2
        echo "Tags can be: administrator, management, monitoring, policymaker (comma-separated)" >&2
        return 1
    fi
    
    check_rabbitmq_accessible || return 1
    
    local data="{\"password\":\"${password}\""
    if [ -n "$tags" ]; then
        data="${data},\"tags\":\"${tags}\""
    fi
    data="${data}}"
    
    if api_call PUT "/api/users/${username}" "$data" >/dev/null 2>&1; then
        echo "User '${username}' created successfully"
    else
        echo "Error: Failed to create user '${username}'" >&2
        return 1
    fi
}

# Delete a user
delete_user() {
    local username="$1"
    
    if [ -z "$username" ]; then
        echo "Usage: delete_user <username>" >&2
        return 1
    fi
    
    check_rabbitmq_accessible || return 1
    
    if api_call DELETE "/api/users/${username}" >/dev/null 2>&1; then
        echo "User '${username}' deleted successfully"
    else
        echo "Error: Failed to delete user '${username}'" >&2
        return 1
    fi
}

# Set user permissions for a vhost
set_permissions() {
    local username="$1"
    local vhost="${2:-/}"
    local configure="${3:-.*}"
    local write="${4:-.*}"
    local read="${5:-.*}"
    
    if [ -z "$username" ]; then
        echo "Usage: set_permissions <username> [vhost] [configure] [write] [read]" >&2
        echo "Defaults: vhost=/, configure=.*, write=.*, read=.*" >&2
        return 1
    fi
    
    check_rabbitmq_accessible || return 1
    
    local vhost_encoded=$(encode_vhost "$vhost")
    local data="{\"configure\":\"${configure}\",\"write\":\"${write}\",\"read\":\"${read}\"}"
    
    if api_call PUT "/api/permissions/${vhost_encoded}/${username}" "$data" >/dev/null 2>&1; then
        echo "Permissions set for user '${username}' on vhost '${vhost}'"
    else
        echo "Error: Failed to set permissions for user '${username}'" >&2
        return 1
    fi
}

# Main command dispatcher
case "${1:-}" in
    list)
        list_users
        ;;
    create)
        create_user "$2" "$3" "$4"
        ;;
    delete)
        delete_user "$2"
        ;;
    permissions)
        set_permissions "$2" "$3" "$4" "$5" "$6"
        ;;
    *)
        echo "Usage: $0 {list|create|delete|permissions}" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  list                                    - List all users" >&2
        echo "  create <username> <password> [tags]     - Create a user" >&2
        echo "  delete <username>                       - Delete a user" >&2
        echo "  permissions <user> [vhost] [conf] [wrt] [read] - Set permissions" >&2
        exit 1
        ;;
esac





