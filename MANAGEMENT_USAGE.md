# RabbitMQ Management Commands Usage Guide

This guide explains how to use the automated management commands for RabbitMQ.

## Prerequisites

Before using management commands, ensure RabbitMQ is running:

```bash
make status
```

For most commands, you'll need access to the Management API. You have two options:

### Option 1: Use Port Forwarding (Recommended)

Run port-forwarding in one terminal:
```bash
make port-forward
```

Then in another terminal, use the management commands. The scripts will automatically detect the local port-forward.

### Option 2: Use from within Kubernetes Cluster

If running from within the cluster, set the environment variable:
```bash
export USE_PORT_FORWARD=true
```

## User Management

### List Users
```bash
make user-list
```

### Create a User
```bash
# Basic user
make user-create USER=myuser PASS=mypassword

# User with admin tags
make user-create USER=admin PASS=secret TAGS=administrator,management

# User with specific tags (monitoring, policymaker)
make user-create USER=operator PASS=op123 TAGS=monitoring,policymaker
```

### Delete a User
```bash
make user-delete USER=myuser
```

### Set User Permissions
```bash
# Full permissions on default vhost
make user-permissions USER=myuser

# Custom permissions
make user-permissions USER=myuser VHOST=/myvhost CONFIGURE="^my-.*" WRITE=".*" READ=".*"

# Permissions explanation:
# CONFIGURE: pattern for resource configuration (queues, exchanges)
# WRITE: pattern for writing (publishing) to resources
# READ: pattern for reading (consuming) from resources
```

## Queue Management

### List Queues
```bash
# List all queues
make queue-list

# List queues in a specific vhost
make queue-list VHOST=/myvhost
```

### Get Queue Information
```bash
make queue-info QUEUE=myqueue

# In a specific vhost
make queue-info QUEUE=myqueue VHOST=/myvhost
```

### Purge Queue (Remove all messages)
```bash
make queue-purge QUEUE=myqueue

# In a specific vhost
make queue-purge QUEUE=myqueue VHOST=/myvhost
```

### Delete Queue
```bash
make queue-delete QUEUE=myqueue

# In a specific vhost
make queue-delete QUEUE=myqueue VHOST=/myvhost
```

## Virtual Host Management

### List Virtual Hosts
```bash
make vhost-list
```

### Create Virtual Host
```bash
make vhost-create VHOST=myvhost
```

### Get Virtual Host Information
```bash
make vhost-info

# Specific vhost
make vhost-info VHOST=/myvhost
```

### Delete Virtual Host
```bash
make vhost-delete VHOST=myvhost
```

**Note:** Deleting a vhost will remove all associated queues, exchanges, and bindings!

## Health Checks

### Comprehensive Health Check
```bash
make health-check
```

This runs all health checks and provides a summary.

### Individual Health Checks

Check specific aspects:

```bash
make health-pod          # Pod status
make health-api          # Management API
make health-node         # Node health
make health-memory       # Memory usage
make health-disk         # Disk usage
make health-queues       # Queue status
make health-connections  # Active connections
make health-diagnostics  # Full diagnostics
```

## Examples

### Complete Setup Scenario

```bash
# 1. Deploy RabbitMQ
make setup

# 2. Start port-forwarding (in separate terminal)
make port-forward

# 3. Create a new vhost for an application
make vhost-create VHOST=/myapp

# 4. Create a user for the application
make user-create USER=myapp PASS=securepass123

# 5. Set permissions for the user on the vhost
make user-permissions USER=myapp VHOST=/myapp

# 6. Check everything is working
make health-check
```

### Queue Troubleshooting

```bash
# Check queue status
make queue-list

# Get detailed info about a problematic queue
make queue-info QUEUE=problematic_queue

# Purge messages if needed (be careful!)
make queue-purge QUEUE=problematic_queue

# If queue is no longer needed
make queue-delete QUEUE=old_queue
```

### Monitoring

```bash
# Quick health check
make health-check

# Monitor memory usage
make health-memory

# Check if queues are accumulating messages
make health-queues

# See active connections
make health-connections
```

## Environment Variables

You can customize the scripts with environment variables:

```bash
# Change namespace
export RABBITMQ_NAMESPACE=my-namespace

# Change service name
export RABBITMQ_SERVICE=my-rabbitmq

# Change credentials
export RABBITMQ_USER=admin
export RABBITMQ_PASS=secret

# Use port-forwarding mode
export USE_PORT_FORWARD=true

# Change management port
export RABBITMQ_MANAGEMENT_PORT=15672
```

## Troubleshooting

### "Cannot connect to RabbitMQ Management API"

**Solution 1:** Start port-forwarding:
```bash
make port-forward
# Then set USE_PORT_FORWARD=true or the script should auto-detect
```

**Solution 2:** Verify RabbitMQ is running:
```bash
make status
```

**Solution 3:** Check if Management UI is accessible:
```bash
curl -u guest:guest http://localhost:15672/api/overview
```

### "Permission denied" errors

Make sure you're using a user with appropriate permissions. The default `guest` user has full permissions, but custom users may need permissions set:
```bash
make user-permissions USER=myuser
```

### Scripts not working

Make sure scripts are executable:
```bash
chmod +x scripts/*.sh
```

## Integration with Wizard

All these commands are available through the interactive wizard:
```bash
make wizard
```

Select the management operation you want to perform from the menu.





