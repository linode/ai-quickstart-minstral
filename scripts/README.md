# AI Quickstart - Minstral LLM Deployment Scripts

Scripts for independent deployment and testing of AI Quickstart - Minstral LLM on Linode instances.

## Prerequisites

Before using these scripts, ensure you have:

1. **Linode CLI installed and configured**:
   ```bash
   pip install linode-cli
   linode-cli configure
   ```

2. **jq installed** (for JSON parsing):
   ```bash
   brew install jq  # macOS
   apt-get install jq  # Linux
   ```

3. **SSH key configured** (for accessing instances)

4. **Check prerequisites**:
   ```bash
   ./scripts/check-prerequisites.sh
   ```

## Scripts

### Quick Start: Full Deployment

Deploy everything in one command. The script will prompt you interactively for region and instance size if not provided:
```bash
./scripts/deploy-full.sh [instance-type] [region] [model-id]
```

**Interactive Mode** (recommended for first-time users):
```bash
./scripts/deploy-full.sh
```
You'll be prompted to:
1. Select a region from RTX4000-available regions
2. Select an RTX4000 instance size
3. Model ID (optional, defaults to `mistralai/Mistral-7B-Instruct-v0.3`)

**Non-Interactive Mode** (for automation):
```bash
./scripts/deploy-full.sh g2-gpu-rtx4000a1-s us-sea mistralai/Mistral-7B-Instruct-v0.3
```

**Available Regions** (RTX4000 only):
- Chicago, US (us-ord)
- Frankfurt 2, DE (de-fra-2)
- Osaka, JP (jp-osa)
- Paris, FR (fr-par)
- Seattle, WA, US (us-sea)
- Singapore 2, SG (sg-sin-2)

**Available Instance Sizes** (RTX4000):
- Small (g2-gpu-rtx4000a1-s) - $350/month
- Medium (g2-gpu-rtx4000a1-m) - $446/month
- Large (g2-gpu-rtx4000a1-l) - $638/month
- X-Large (g2-gpu-rtx4000a1-xl) - $1022/month
- And more options (x2 and x4 GPU configurations available)

### Individual Scripts

#### `create-instance.sh`
Create a new Linode GPU instance. Supports interactive prompts for region and instance size.

```bash
./scripts/create-instance.sh [instance-type] [region] [root-password] [label]
```

**Interactive Mode**:
```bash
./scripts/create-instance.sh
```
You'll be prompted to select region and instance size from RTX4000 options.

**Non-Interactive Mode**:
```bash
./scripts/create-instance.sh g2-gpu-rtx4000a1-s us-sea "MyPassword123" ai-sandbox-test
```

**Note**: Only RTX4000 instances are supported. See available regions and sizes above.

**Output**: Creates instance with cloud-init configuration and saves info to `.instance-info-<ID>.json`

#### `validate-services.sh`
Validate that services are running and accessible.

```bash
./scripts/validate-services.sh <instance-ip>
```

**Example**:
```bash
./scripts/validate-services.sh 192.168.1.100
```

**Checks**:
- SSH connectivity
- Docker Compose services status
- Port accessibility (3000, 8000)
- API/UI endpoint responses
- Deployment status from /etc/motd

#### `cleanup-instance.sh`
Delete a test instance.

```bash
./scripts/cleanup-instance.sh <instance-id> [--force]
```

**Example**:
```bash
./scripts/cleanup-instance.sh 12345678
```

## Workflow Examples

### Development Workflow

1. **Check prerequisites**:
   ```bash
   ./scripts/check-prerequisites.sh
   ```

2. **Deploy full stack**:
   ```bash
   ./scripts/deploy-full.sh
   ```

3. **Validate deployment**:
   ```bash
   # Get IP from .instance-info-*.json or linode-cli
   ./scripts/validate-services.sh <instance-ip>
   ```

4. **Test and iterate**:
   - Make changes to cloud-init configuration
   - Create a new instance to test changes
   - Validate again

5. **Cleanup when done**:
   ```bash
   ./scripts/cleanup-instance.sh <instance-id>
   ```

### Testing on Existing Instance

If you already have a Linode instance, you can manually deploy by copying the cloud-init configuration:

```bash
# Copy cloud-init file to instance
scp cloud-init/ai-sandbox.yaml root@<instance-ip>:/tmp/

# Run cloud-init manually (if needed)
# Note: Cloud-init typically runs automatically on first boot
```

## Environment Variables

- `MODEL_ID`: Override default model (default: `mistralai/Mistral-7B-Instruct-v0.3`)

Example:
```bash
export MODEL_ID="meta-llama/Llama-3-8B-Instruct"
./scripts/deploy-full.sh
```

## Logging

All deployment scripts log to timestamped files in the `logs/` directory:
- Format: `logs/deploy-YYYYMMDD-HHMMSS.log`
- Each deployment creates a new log file with a timestamp
- Logs are not committed to git (excluded in `.gitignore`)

The log file contains:
- Timestamped entries for each deployment step
- Error messages with details
- Command outputs for debugging
- Instance creation and deployment status

View the latest log:
```bash
# View most recent log
ls -t logs/*.log | head -1 | xargs tail -f

# Or view all logs
ls -lh logs/
```

The log file location is displayed at the start of each deployment.

## Troubleshooting

### Script Terminates Without Error Message
- **Check the log file**: The log file location is shown at the start of deployment
- View latest log: `ls -t logs/*.log | head -1 | xargs tail -20`
- The log file contains detailed error information even if the script exits silently
- Common causes:
  - Linode API errors (check API token permissions)
  - Password validation failures
  - Network connectivity issues
  - Missing dependencies (jq, linode-cli)

### Instance Creation Fails
- Check Linode CLI is configured: `linode-cli profile view`
- Verify you have GPU instance access
- Check available regions: `linode-cli regions list`
- **Check log file**: `ls -t logs/*.log | head -1 | xargs tail` for detailed error messages
- Verify password meets requirements (11-128 chars, mixed case, numbers, special chars)

### Deployment Fails
- Wait longer for instance to boot (may take 2-3 minutes)
- Check SSH connectivity: `ssh root@<instance-ip>`
- Verify cloud-init file exists: `ls -la cloud-init/ai-sandbox.yaml`
- **Check log file**: `tail ~/.ai-sandbox-deploy.log` for deployment errors

### Services Not Accessible
- Wait 3-5 minutes for services to start
- Check deployment logs: `ssh root@<instance-ip> 'tail -f /var/log/ai-sandbox/deployment.log'`
- Check service status: `ssh root@<instance-ip> 'docker-compose -f /opt/ai-sandbox/docker-compose.yml ps'`
- **Check local log file**: `tail ~/.ai-sandbox-deploy.log` for validation errors

## Next Steps

After successful deployment:
1. Test the chat interface: `http://<instance-ip>:3000`
2. Test the API: `http://<instance-ip>:8000/v1`
3. Configure firewall rules to protect your services
4. Review the [Security Guide](../docs/security.md) for best practices

