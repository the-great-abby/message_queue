#!/bin/sh
# RabbitMQ Makefile Wizard - Interactive menu for selecting make targets

# Initialize config file if it doesn't exist
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.rabbitmq-wizard.config"

# Ensure config file exists with defaults
# Calling set_config once will create the file with all defaults if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    # Create config file with defaults (set_config creates full file with all defaults)
    "$SCRIPT_DIR/config-manager.sh" set USE_PORT_FORWARD true >/dev/null 2>&1 || true
fi

# Get all targets with descriptions
get_targets() {
    grep -h "^[a-zA-Z_-]*:.*##" Makefile Makefile.kubernetes Makefile.management 2>/dev/null | \
    awk -F':.*?## ' '/^[a-zA-Z_-]+:.*##/ {print $1 "|" $2}' | \
    grep -v "^help|" | grep -v "^wizard|" | grep -v "^k8s-help|" | \
    sort -u
}

# Helper function to check if target exists
target_exists() {
    local check_target="$1"
    local all_targets="$2"
    echo "$all_targets" | grep -q "^${check_target}|"
}

# Helper function to get target description
get_target_desc() {
    local check_target="$1"
    local all_targets="$2"
    echo "$all_targets" | grep "^${check_target}|" | cut -d'|' -f2
}

# Group targets
DEPLOYMENT_TARGETS="setup teardown cleanup"
OPERATION_TARGETS="status logs shell port-forward"
USER_TARGETS="user-list user-create user-delete user-permissions"
QUEUE_TARGETS="queue-list queue-info queue-purge queue-delete"
VHOST_TARGETS="vhost-list vhost-create vhost-delete vhost-info"
HEALTH_TARGETS="health-check health-pod health-api health-node health-memory health-disk health-queues health-connections health-diagnostics"

# Function to collect parameters for commands that need them
collect_parameters() {
    local target="$1"
    local make_args=""
    
    case "$target" in
        user-create)
            echo ""
            echo "Create RabbitMQ User"
            echo "==================="
            read -p "Username (required): " username
            if [ -z "$username" ]; then
                echo "Error: Username is required" >&2
                return 1
            fi
            read -s -p "Password (required, hidden): " password
            echo ""
            if [ -z "$password" ]; then
                echo "Error: Password is required" >&2
                return 1
            fi
            read -p "Tags (optional, e.g., administrator,management,monitoring): " tags
            make_args="USER=\"$username\" PASS=\"$password\""
            if [ -n "$tags" ]; then
                make_args="$make_args TAGS=\"$tags\""
            fi
            ;;
        user-delete)
            echo ""
            echo "Delete RabbitMQ User"
            echo "==================="
            read -p "Username (required): " username
            if [ -z "$username" ]; then
                echo "Error: Username is required" >&2
                return 1
            fi
            make_args="USER=\"$username\""
            ;;
        user-permissions)
            echo ""
            echo "Set User Permissions"
            echo "==================="
            read -p "Username (required): " username
            if [ -z "$username" ]; then
                echo "Error: Username is required" >&2
                return 1
            fi
            read -p "Virtual Host [default: /]: " vhost
            vhost=${vhost:-/}
            read -p "Configure permission [default: .*]: " configure
            configure=${configure:-.*}
            read -p "Write permission [default: .*]: " write
            write=${write:-.*}
            read -p "Read permission [default: .*]: " read_perm
            read_perm=${read_perm:-.*}
            make_args="USER=\"$username\" VHOST=\"$vhost\" CONFIGURE=\"$configure\" WRITE=\"$write\" READ=\"$read_perm\""
            ;;
        queue-info)
            echo ""
            echo "Get Queue Information"
            echo "====================="
            read -p "Queue name (required): " queue
            if [ -z "$queue" ]; then
                echo "Error: Queue name is required" >&2
                return 1
            fi
            read -p "Virtual Host [default: /]: " vhost
            vhost=${vhost:-/}
            make_args="QUEUE=\"$queue\" VHOST=\"$vhost\""
            ;;
        queue-purge)
            echo ""
            echo "Purge Queue"
            echo "==========="
            read -p "Queue name (required): " queue
            if [ -z "$queue" ]; then
                echo "Error: Queue name is required" >&2
                return 1
            fi
            read -p "Virtual Host [default: /]: " vhost
            vhost=${vhost:-/}
            echo ""
            echo "WARNING: This will delete all messages in the queue!"
            read -p "Are you sure? (y/N): " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "Cancelled."
                return 1
            fi
            make_args="QUEUE=\"$queue\" VHOST=\"$vhost\""
            ;;
        queue-delete)
            echo ""
            echo "Delete Queue"
            echo "============"
            read -p "Queue name (required): " queue
            if [ -z "$queue" ]; then
                echo "Error: Queue name is required" >&2
                return 1
            fi
            read -p "Virtual Host [default: /]: " vhost
            vhost=${vhost:-/}
            echo ""
            echo "WARNING: This will permanently delete the queue!"
            read -p "Are you sure? (y/N): " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "Cancelled."
                return 1
            fi
            make_args="QUEUE=\"$queue\" VHOST=\"$vhost\""
            ;;
        vhost-create)
            echo ""
            echo "Create Virtual Host"
            echo "=================="
            read -p "Virtual Host name (required): " vhost
            if [ -z "$vhost" ]; then
                echo "Error: Virtual Host name is required" >&2
                return 1
            fi
            make_args="VHOST=\"$vhost\""
            ;;
        vhost-delete)
            echo ""
            echo "Delete Virtual Host"
            echo "=================="
            read -p "Virtual Host name (required): " vhost
            if [ -z "$vhost" ]; then
                echo "Error: Virtual Host name is required" >&2
                return 1
            fi
            echo ""
            echo "WARNING: This will permanently delete the virtual host and all its resources!"
            read -p "Are you sure? (y/N): " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "Cancelled."
                return 1
            fi
            make_args="VHOST=\"$vhost\""
            ;;
        *)
            # No parameters needed
            make_args=""
            ;;
    esac
    
    echo "$make_args"
    return 0
}

# Build target list (must be done before function calls)
targets=$(get_targets)

# Main wizard loop
while true; do
    echo "RabbitMQ External Service Management - Wizard"
    echo "=============================================="
    echo ""

    # Display menu with sections
    index=1
    # Store targets in order (using a temporary file for portability)
    TMP_TARGETS=$(mktemp)
    trap "rm -f $TMP_TARGETS" EXIT

# Deployment & Lifecycle
echo "📦 DEPLOYMENT & LIFECYCLE"
echo "   Manages RabbitMQ installation and Kubernetes resources"
echo ""
for target in $DEPLOYMENT_TARGETS; do
    if target_exists "$target" "$targets"; then
        desc=$(get_target_desc "$target" "$targets")
        printf "  %2d) %-25s %s\n" "$index" "$target" "$desc"
        echo "$target" >> "$TMP_TARGETS"
        index=$((index + 1))
    fi
done
echo ""

# Operations & Monitoring  
echo "⚙️  OPERATIONS & MONITORING"
echo "   Day-to-day operations: status, logs, shell access, port forwarding"
echo ""
for target in $OPERATION_TARGETS; do
    if target_exists "$target" "$targets"; then
        desc=$(get_target_desc "$target" "$targets")
        printf "  %2d) %-25s %s\n" "$index" "$target" "$desc"
        echo "$target" >> "$TMP_TARGETS"
        index=$((index + 1))
    fi
done
echo ""

# User Management
echo "👤 USER MANAGEMENT"
echo "   Create, list, delete users and manage permissions"
echo ""
for target in $USER_TARGETS; do
    if target_exists "$target" "$targets"; then
        desc=$(get_target_desc "$target" "$targets")
        # Extract just the first part of the description for cleaner display
        short_desc=$(echo "$desc" | sed 's/ (usage:.*)//')
        printf "  %2d) %-25s %s\n" "$index" "$target" "$short_desc"
        echo "$target" >> "$TMP_TARGETS"
        index=$((index + 1))
    fi
done
echo ""

# Queue Management
echo "📋 QUEUE MANAGEMENT"
echo "   List, inspect, purge, and delete queues"
echo ""
for target in $QUEUE_TARGETS; do
    if target_exists "$target" "$targets"; then
        desc=$(get_target_desc "$target" "$targets")
        short_desc=$(echo "$desc" | sed 's/ (usage:.*)//')
        printf "  %2d) %-25s %s\n" "$index" "$target" "$short_desc"
        echo "$target" >> "$TMP_TARGETS"
        index=$((index + 1))
    fi
done
echo ""

# Virtual Host Management
echo "🏠 VIRTUAL HOST MANAGEMENT"
echo "   Create and manage virtual hosts for logical resource separation"
echo ""
for target in $VHOST_TARGETS; do
    if target_exists "$target" "$targets"; then
        desc=$(get_target_desc "$target" "$targets")
        short_desc=$(echo "$desc" | sed 's/ (usage:.*)//')
        printf "  %2d) %-25s %s\n" "$index" "$target" "$short_desc"
        echo "$target" >> "$TMP_TARGETS"
        index=$((index + 1))
    fi
done
echo ""

# Health Checks
echo "🏥 HEALTH CHECKS & DIAGNOSTICS"
echo "   Monitor RabbitMQ health, resources, and run diagnostics"
echo ""
for target in $HEALTH_TARGETS; do
    if target_exists "$target" "$targets"; then
        desc=$(get_target_desc "$target" "$targets")
        printf "  %2d) %-25s %s\n" "$index" "$target" "$desc"
        echo "$target" >> "$TMP_TARGETS"
        index=$((index + 1))
    fi
done
echo ""

    # Configuration section
    echo "⚙️  CONFIGURATION"
    echo "   Manage wizard settings (port-forwarding, credentials, etc.)"
    echo ""
    printf "  %2d) %-25s %s\n" "$index" "config" "Configure wizard settings"
    echo "config" >> "$TMP_TARGETS"
    config_option=$index
    index=$((index + 1))
    echo ""

    # Exit option
    exit_option=$index
    printf "  %2d) %-25s %s\n" "$exit_option" "Exit" "Exit the wizard"
    echo ""

    # Get user selection
    read -p "Select a target (1-$exit_option): " choice

    if [ -z "$choice" ]; then
        echo "No selection made. Returning to menu..."
        echo ""
        sleep 1
        continue
    fi

    # Check if user wants to exit
    if [ "$choice" -eq "$exit_option" ] 2>/dev/null; then
        echo ""
        echo "Exiting wizard. Goodbye!"
        rm -f "$TMP_TARGETS"
        exit 0
    fi

    # Validate choice is within range
    if [ "$choice" -lt 1 ] || [ "$choice" -ge "$exit_option" ] 2>/dev/null; then
        echo "Invalid selection. Please choose a number between 1 and $exit_option."
        echo ""
        sleep 1
        continue
    fi

    # Get selected target from the stored list
    selected_target=$(sed -n "${choice}p" "$TMP_TARGETS")

    if [ -z "$selected_target" ]; then
        echo "Invalid selection. Returning to menu..."
        echo ""
        sleep 1
        continue
    fi

    # Handle configuration menu
    if [ "$selected_target" = "config" ]; then
        echo ""
        ./scripts/config-manager.sh menu
        echo ""
        read -p "Press Enter to return to main menu..."
        echo ""
        rm -f "$TMP_TARGETS"
        continue
    fi

    # Collect parameters for commands that need them
    make_params=$(collect_parameters "$selected_target")
    if [ $? -ne 0 ]; then
        # User cancelled or error occurred
        echo ""
        read -p "Press Enter to return to menu..."
        echo ""
        rm -f "$TMP_TARGETS"
        continue
    fi

    echo ""
    if [ -n "$make_params" ]; then
        echo "Running: make $selected_target $make_params"
    else
        echo "Running: make $selected_target"
    fi
    echo "=============================================="
    echo ""

    # Execute the selected target with parameters
    if [ -n "$make_params" ]; then
        eval "make $selected_target $make_params"
    else
        make "$selected_target"
    fi
    
    echo ""
    echo "=============================================="
    echo ""
    read -p "Press Enter to return to menu..."
    echo ""
    
    # Clean up temp file for next iteration
    rm -f "$TMP_TARGETS"
done

