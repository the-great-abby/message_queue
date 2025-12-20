# RabbitMQ External Service

A centralized RabbitMQ messaging system for Kubernetes clusters, designed for easy setup and management across multiple namespaces.

## Features

- **Centralized Messaging**: Single RabbitMQ instance accessible from any namespace
- **Management UI**: Web-based management interface for monitoring and configuration
- **Prometheus Integration**: Built-in metrics collection for monitoring
- **Persistent Storage**: Configuration and queue data persisted across restarts
- **Resource Optimized**: Configured for resource-constrained environments
- **Easy Management**: Simple Makefile targets for all operations

## Quick Start

1. **Deploy RabbitMQ**:
   ```bash
   make setup
   ```

2. **Access Management UI and Message Queue**:
   ```bash
   make connection-info
   # Shows NodePort connection details (no port-forward needed!)
   # Management UI: http://<NODE_IP>:31672 (open in browser)
   # Username: guest, Password: guest
   ```

3. **Check Status**:
   ```bash
   make status
   ```

4. **Clean Up**:
   ```bash
   make teardown
   ```

## Connection Details

### External Access (via NodePort)

RabbitMQ is now accessible via NodePort (no port-forward needed!):

Run `make connection-info` to see the current connection details. Typically:

- **AMQP URL**: `<NODE_IP>:30672`
- **Management URL**: `http://<NODE_IP>:31672`
- **Prometheus Metrics**: `http://<NODE_IP>:31692/metrics`

The NodePort numbers are fixed, so your services can use stable connection strings.

### Legacy: Local Access (via Port Forward)

For backward compatibility, port-forwarding is still available but deprecated:

- **AMQP URL**: `localhost:5672` (requires `make port-forward`)
- **Management URL**: `http://localhost:15672` (requires `make port-forward`)
- **Prometheus Metrics**: `http://localhost:15692/metrics` (requires `make port-forward`)

### From Other Namespaces

When connecting from other applications in your cluster, use these connection details:

- **AMQP URL**: `rabbitmq.rabbitmq-system.svc.cluster.local:5672`
- **Management URL**: `http://rabbitmq.rabbitmq-system.svc.cluster.local:15672`
- **Prometheus Metrics**: `http://rabbitmq.rabbitmq-system.svc.cluster.local:15692/metrics`

### Example Connection (Python)

```python
import pika

# Connect to RabbitMQ via NodePort (recommended)
# Run 'make connection-info' to get the exact NodePort and node IP
connection = pika.BlockingConnection(
    pika.ConnectionParameters('<NODE_IP>', 30672)  # NodePort for AMQP
)

# Or from within the cluster, use the service URL:
# connection = pika.BlockingConnection(
#     pika.ConnectionParameters('rabbitmq.rabbitmq-system.svc.cluster.local', 5672)
# )

channel = connection.channel()

# Create a queue
channel.queue_declare(queue='my_queue')

# Publish a message
channel.basic_publish(exchange='', routing_key='my_queue', body='Hello World!')
```

## Available Makefile Targets

### Deployment & Operations
| Target | Description |
|--------|-------------|
| `make setup` | Deploy RabbitMQ to Kubernetes |
| `make teardown` | Remove RabbitMQ from Kubernetes |
| `make status` | Show RabbitMQ pod and service status |
| `make logs` | Show RabbitMQ logs |
| `make shell` | Access RabbitMQ management shell |
| `make port-forward` | Port forward services for local access |
| `make cleanup` | Remove all resources including data |
| `make wizard` | Interactive menu to select and run targets |

### User Management
| Target | Description |
|--------|-------------|
| `make user-list` | List all RabbitMQ users |
| `make user-create USER=name PASS=pass [TAGS=tags]` | Create a user |
| `make user-delete USER=name` | Delete a user |
| `make user-permissions USER=name [VHOST=/]` | Set user permissions |

### Queue Management
| Target | Description |
|--------|-------------|
| `make queue-list [VHOST=/]` | List all queues |
| `make queue-info QUEUE=name [VHOST=/]` | Get queue information |
| `make queue-purge QUEUE=name [VHOST=/]` | Purge all messages from a queue |
| `make queue-delete QUEUE=name [VHOST=/]` | Delete a queue |

### Virtual Host Management
| Target | Description |
|--------|-------------|
| `make vhost-list` | List all virtual hosts |
| `make vhost-create VHOST=name` | Create a virtual host |
| `make vhost-delete VHOST=name` | Delete a virtual host |
| `make vhost-info [VHOST=/]` | Get virtual host information |

### Health Checks
| Target | Description |
|--------|-------------|
| `make health-check` | Run comprehensive health check |
| `make health-pod` | Check pod status |
| `make health-api` | Check Management API accessibility |
| `make health-memory` | Check memory usage |
| `make health-disk` | Check disk usage |
| `make health-queues` | Check queue status |
| `make health-connections` | Check active connections |
| `make health-diagnostics` | Run rabbitmqctl diagnostics |

See [MANAGEMENT_USAGE.md](MANAGEMENT_USAGE.md) for detailed usage examples.

## Configuration

### Resource Limits

- **Memory**: 512Mi request, 1.5Gi limit
- **CPU**: 250m request, 1000m limit
- **Storage**: 2.5Gi persistent volume

### Default Settings

- **Username**: guest
- **Password**: guest
- **Virtual Host**: /
- **Management UI**: Port 15672
- **Prometheus Metrics**: Port 15692

## Monitoring

The RabbitMQ instance is configured with Prometheus metrics collection. If you have Prometheus Operator installed, the ServiceMonitor will automatically be discovered.

Metrics are available at: `http://rabbitmq.rabbitmq-system.svc.cluster.local:15692/metrics`

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n rabbitmq-system
```

### View Logs
```bash
make logs
# or
kubectl logs -f deployment/rabbitmq -n rabbitmq-system
```

### Access Management Shell
```bash
make shell
# or
kubectl exec -it deployment/rabbitmq -n rabbitmq-system -- rabbitmqctl
```

### Reset Everything
```bash
make cleanup
```

## File Structure

```
.
├── Makefile                 # Main Makefile with all targets
├── Makefile.kubernetes     # Kubernetes-specific targets
├── namespace.yaml          # RabbitMQ namespace
├── configmap.yaml          # RabbitMQ configuration
├── pvc.yaml               # Persistent volume claim
├── deployment.yaml        # RabbitMQ deployment
├── services.yaml          # ClusterIP services
├── servicemonitor.yaml    # Prometheus ServiceMonitor
└── README.md              # This file
```

## Security Notes

This setup is configured for local development with minimal security:
- Default guest/guest credentials
- No authentication required
- Accessible only within the cluster

For production use, consider:
- Enabling authentication
- Using proper secrets management
- Configuring TLS/SSL
- Setting up proper RBAC policies










