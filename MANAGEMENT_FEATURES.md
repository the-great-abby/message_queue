# RabbitMQ Management Features

## Currently Available (via Management UI)

The Management UI (`rabbitmq:3.13-management` image) provides full management capabilities at `http://localhost:15672`:

### ✅ User Management
- Create, edit, delete users
- Set passwords and permissions
- Assign user tags (administrator, management, monitoring, policymaker)
- Configure per-vhost permissions

### ✅ Queue Management
- View all queues with detailed metrics
- Create queues manually
- Delete queues
- Purge queue messages
- Inspect individual messages
- Monitor queue consumers

### ✅ Virtual Host (vhost) Management
- Create and delete vhosts
- Configure vhost permissions
- View vhost statistics

### ✅ Exchange Management
- Create, edit, delete exchanges
- Configure exchange types (direct, topic, fanout, headers)
- View exchange bindings

### ✅ Binding Management
- Create bindings between exchanges and queues
- View routing key patterns
- Delete bindings

### ✅ Additional Features
- Connection and channel monitoring
- Policy management (queue policies, operator policies)
- Cluster monitoring (when using clustering)
- Import/export definitions (configurations)

## Recommended Automation Features

### High Priority
1. **User Management Scripts**
   - `make user-create USER=name PASS=pass` - Create users programmatically
   - `make user-list` - List all users
   - `make user-delete USER=name` - Delete users
   - `make user-set-permissions USER=name VHOST=/ PERMS=".* .* .*"` - Set permissions

2. **Queue Management Scripts**
   - `make queue-list [VHOST=/]` - List queues (optionally filtered by vhost)
   - `make queue-purge QUEUE=name [VHOST=/]` - Purge queue messages
   - `make queue-delete QUEUE=name [VHOST=/]` - Delete queues
   - `make queue-info QUEUE=name [VHOST=/]` - Get queue details and statistics

3. **VHost Management Scripts**
   - `make vhost-create NAME=vhost` - Create virtual hosts
   - `make vhost-list` - List all vhosts
   - `make vhost-delete NAME=vhost` - Delete vhosts

### Medium Priority
4. **Exchange Management Scripts**
   - `make exchange-list [VHOST=/]` - List exchanges
   - `make exchange-create NAME=ex TYPE=topic [VHOST=/]` - Create exchanges
   - `make exchange-delete NAME=ex [VHOST=/]` - Delete exchanges

5. **Binding Management Scripts**
   - `make binding-list [VHOST=/]` - List all bindings
   - `make binding-create EXCHANGE=ex QUEUE=q ROUTING_KEY=key [VHOST=/]` - Create bindings

6. **Connection Monitoring**
   - `make connections-list` - Show active connections
   - `make connections-close CONNECTION=name` - Close specific connections

### Lower Priority (Nice to Have)
7. **Policy Management**
   - `make policy-list` - List policies
   - `make policy-create NAME=pol PATTERN=".*" DEFINITION='{"ha-mode":"all"}'` - Create policies

8. **Health Checks & Diagnostics**
   - `make health-check` - Comprehensive health check
   - `make diagnostics` - Run diagnostics suite

9. **Backup/Restore**
   - `make export-definitions FILE=definitions.json` - Export all definitions
   - `make import-definitions FILE=definitions.json` - Import definitions

10. **Monitoring & Statistics**
    - `make stats` - Show comprehensive statistics
    - `make overview` - Show overview dashboard data

## Implementation Notes

All management operations can be performed via:
- **Management UI** (http://localhost:15672) - Manual, web-based
- **Management HTTP API** - Can be scripted via curl/wget
- **rabbitmqctl** - CLI tool (already available via `make shell`)

Recommended approach: Create helper scripts in `scripts/` that use either:
1. `rabbitmqctl` commands (via kubectl exec)
2. Management HTTP API (via curl to Management UI)

## Example: Management HTTP API

```bash
# Get all users
curl -u guest:guest http://localhost:15672/api/users

# Create a user
curl -u guest:guest -X PUT http://localhost:15672/api/users/username \
  -H "Content-Type: application/json" \
  -d '{"password":"secret","tags":"administrator"}'

# List queues
curl -u guest:guest http://localhost:15672/api/queues

# Purge a queue
curl -u guest:guest -X DELETE http://localhost:15672/api/queues/%2F/queue-name/contents
```

Note: `%2F` is the URL-encoded version of `/` (the default vhost).





