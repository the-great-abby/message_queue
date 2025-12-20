#!/bin/sh
# RabbitMQ Wizard Configuration Manager

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.rabbitmq-wizard.config"

# Load config value
get_config() {
    local key="$1"
    local default="$2"
    if [ -f "$CONFIG_FILE" ]; then
        local value=$(grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$value" ]; then
            echo "$value"
        else
            echo "$default"
        fi
    else
        echo "$default"
    fi
}

# Set config value
set_config() {
    local key="$1"
    local value="$2"
    
    # Create config file if it doesn't exist (in project root)
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# RabbitMQ Wizard Configuration File
# This file stores wizard settings and preferences

# Port Forwarding
# Set to 'true' to use localhost port-forwarding (default: true)
# Set to 'false' to use service URL directly (requires cluster access)
USE_PORT_FORWARD=true

# RabbitMQ Namespace (default: rabbitmq-system)
RABBITMQ_NAMESPACE=rabbitmq-system

# RabbitMQ Service Name (default: rabbitmq)
RABBITMQ_SERVICE=rabbitmq

# Management Port (default: 15672)
RABBITMQ_MANAGEMENT_PORT=15672

# RabbitMQ Credentials (for Management API)
RABBITMQ_USER=guest
RABBITMQ_PASS=guest
EOF
        echo "Created configuration file at: $CONFIG_FILE"
    fi
    
    # Update or add the config value
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        # Update existing value
        if [ "$(uname)" = "Darwin" ]; then
            # macOS sed
            sed -i '' "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
        else
            # Linux sed
            sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
        fi
    else
        # Add new value (append before comments if any)
        echo "${key}=${value}" >> "$CONFIG_FILE"
    fi
}

# Show current configuration
show_config() {
    echo "Current Wizard Configuration:"
    echo "=============================="
    echo ""
    if [ -f "$CONFIG_FILE" ]; then
        grep -v "^#" "$CONFIG_FILE" | grep -v "^$" | while IFS='=' read -r key value; do
            printf "  %-30s = %s\n" "$key" "$value"
        done
    else
        echo "  (Using defaults - config file not created yet)"
        echo ""
        echo "  USE_PORT_FORWARD=true"
        echo "  RABBITMQ_NAMESPACE=rabbitmq-system"
        echo "  RABBITMQ_SERVICE=rabbitmq"
        echo "  RABBITMQ_MANAGEMENT_PORT=15672"
        echo "  RABBITMQ_USER=guest"
        echo "  RABBITMQ_PASS=guest"
    fi
    echo ""
}

# Interactive configuration menu
config_menu() {
    while true; do
        echo "Configuration Menu"
        echo "=================="
        echo ""
        show_config
        echo "Options:"
        echo "  1) Toggle USE_PORT_FORWARD (currently: $(get_config USE_PORT_FORWARD true))"
        echo "  2) Set RABBITMQ_NAMESPACE (currently: $(get_config RABBITMQ_NAMESPACE rabbitmq-system))"
        echo "  3) Set RABBITMQ_SERVICE (currently: $(get_config RABBITMQ_SERVICE rabbitmq))"
        echo "  4) Set RABBITMQ_MANAGEMENT_PORT (currently: $(get_config RABBITMQ_MANAGEMENT_PORT 15672))"
        echo "  5) Set RABBITMQ_USER (currently: $(get_config RABBITMQ_USER guest))"
        echo "  6) Set RABBITMQ_PASS (currently: $(get_config RABBITMQ_PASS guest))"
        echo "  7) Show configuration"
        echo "  8) Return to main menu"
        echo ""
        read -p "Select option (1-8): " choice
        
        case "$choice" in
            1)
                current=$(get_config USE_PORT_FORWARD true)
                if [ "$current" = "true" ]; then
                    new_value="false"
                    echo "Switching to direct service access (no port-forwarding)"
                else
                    new_value="true"
                    echo "Switching to port-forwarding mode (requires 'make port-forward' to be running)"
                fi
                set_config USE_PORT_FORWARD "$new_value"
                echo "Configuration updated!"
                echo ""
                sleep 1
                ;;
            2)
                read -p "Enter RABBITMQ_NAMESPACE [$(get_config RABBITMQ_NAMESPACE rabbitmq-system)]: " value
                value=${value:-$(get_config RABBITMQ_NAMESPACE rabbitmq-system)}
                set_config RABBITMQ_NAMESPACE "$value"
                echo "Configuration updated!"
                echo ""
                sleep 1
                ;;
            3)
                read -p "Enter RABBITMQ_SERVICE [$(get_config RABBITMQ_SERVICE rabbitmq)]: " value
                value=${value:-$(get_config RABBITMQ_SERVICE rabbitmq)}
                set_config RABBITMQ_SERVICE "$value"
                echo "Configuration updated!"
                echo ""
                sleep 1
                ;;
            4)
                read -p "Enter RABBITMQ_MANAGEMENT_PORT [$(get_config RABBITMQ_MANAGEMENT_PORT 15672)]: " value
                value=${value:-$(get_config RABBITMQ_MANAGEMENT_PORT 15672)}
                set_config RABBITMQ_MANAGEMENT_PORT "$value"
                echo "Configuration updated!"
                echo ""
                sleep 1
                ;;
            5)
                read -p "Enter RABBITMQ_USER [$(get_config RABBITMQ_USER guest)]: " value
                value=${value:-$(get_config RABBITMQ_USER guest)}
                set_config RABBITMQ_USER "$value"
                echo "Configuration updated!"
                echo ""
                sleep 1
                ;;
            6)
                read -p "Enter RABBITMQ_PASS [hidden]: " value
                if [ -n "$value" ]; then
                    set_config RABBITMQ_PASS "$value"
                    echo "Configuration updated!"
                else
                    echo "Password not changed."
                fi
                echo ""
                sleep 1
                ;;
            7)
                # Already shown above, just wait
                read -p "Press Enter to continue..."
                echo ""
                ;;
            8)
                return 0
                ;;
            *)
                echo "Invalid option. Please try again."
                echo ""
                sleep 1
                ;;
        esac
    done
}

# Main command dispatcher
case "${1:-menu}" in
    get)
        get_config "$2" "$3"
        ;;
    set)
        set_config "$2" "$3"
        ;;
    show)
        show_config
        ;;
    menu|*)
        config_menu
        ;;
esac
