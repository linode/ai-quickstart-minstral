# Quick Start Guide

Deploy AI Quickstart - Minstral LLM to a clean Linode GPU instance in minutes using automated scripts.

## Overview

This guide walks you through deploying the AI Quickstart - Minstral LLM stack to a fresh Linode GPU instance. The deployment process:
1. Creates a new Linode GPU instance
2. Installs NVIDIA drivers, Docker, and dependencies
3. Configures and starts the AI services
4. Validates that everything is working correctly

## Prerequisites

Before deploying to a clean Linode instance, ensure you have all required tools installed:

```bash
./scripts/check-prerequisites.sh
```

This verifies:
- `linode-cli` is installed and configured
- `jq` is installed (for JSON parsing)
- `openssl` is installed (for password generation)
- SSH keys are available (optional but recommended)

**Install missing dependencies** (if needed):

```bash
# Install Linode CLI
pip install linode-cli
linode-cli configure  # Follow prompts to add your API token

# Install jq (macOS)
brew install jq

# Install jq (Linux)
sudo apt-get install jq
```

**Note**: GPU instances require GPU access to be enabled on your Linode account. If you don't see GPU instance types available, contact Linode Support to enable GPU access.

## Deployment

Deploy AI Quickstart - Minstral LLM to a clean Linode GPU instance:

**Interactive Mode** (recommended for first-time users):

```bash
./scripts/deploy-full.sh
```

The script will prompt you for:
- Region (RTX4000-available regions):
  - Chicago, US (us-ord)
  - Frankfurt 2, DE (de-fra-2)
  - Osaka, JP (jp-osa)
  - Paris, FR (fr-par)
  - Seattle, WA, US (us-sea)
  - Singapore 2, SG (sg-sin-2)
- RTX4000 instance size (e.g., Small, Medium, Large)
- Model ID (optional, defaults to `mistralai/Mistral-7B-Instruct-v0.3`)

**Non-Interactive Mode** (for automation):

```bash
./scripts/deploy-full.sh [instance-type] [region] [model-id]
```

Example:
```bash
./scripts/deploy-full.sh g2-gpu-rtx4000a1-s us-sea mistralai/Mistral-7B-Instruct-v0.3
```

### What Happens During Deployment

1. **Instance Creation**: Creates a new Linode GPU instance with your configuration and cloud-init
2. **Cloud-init Deployment**: Automatically installs NVIDIA drivers, Docker, and dependencies on first boot
3. **Service Initialization**: Waits for services to start (3-5 minutes)
4. **Validation**: Verifies all services are running correctly

### After Deployment

You'll receive:
- Instance ID and IP address
- Root password (saved in `.instance-info-<ID>.json`)
- Service URLs for Chat UI and API
- SSH access command

**Access your services:**
- Chat UI: `http://YOUR_INSTANCE_IP:3000`
  - **First-time access**: You'll need to create an account when you first visit the UI
  - Create a username and password to get started
- API Endpoint: `http://YOUR_INSTANCE_IP:8000/v1`
  - **No authentication required**: The API is accessible without credentials (use firewall for security)

**SSH into your instance:**
```bash
ssh root@YOUR_INSTANCE_IP
```

## Accessing the Chat UI

When you first access the Chat UI at `http://YOUR_INSTANCE_IP:3000`, you'll need to create an account:

1. **Open the URL** in your web browser
2. **Create an account**: 
   - Enter a username
   - Create a password
   - Click "Sign Up" or "Create Account"
3. **Start chatting**: Once logged in, you can immediately start using the chat interface

**Note**: This account is local to your instance and is used to manage your chat history and preferences.

## Using the API

The API is fully OpenAI-compatible and requires **no authentication**. You can start making requests immediately:

```bash
curl http://YOUR_INSTANCE_IP:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistralai/Mistral-7B-Instruct-v0.3",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

**Note**: Since the API has no authentication, ensure you've configured a firewall to restrict access. See the [Security Guide](security.md) for details.

## Security Warning

⚠️ **IMPORTANT**: By default, both services are exposed to the internet without authentication.

**You must configure a Linode Cloud Firewall** to protect:
- Port `3000` (UI)
- Port `8000` (API)

A security warning is displayed when you SSH into the instance.

## Troubleshooting

If services aren't ready after deployment:

1. **Wait 3-5 minutes** - Services need time to initialize
2. **Re-run validation**:
   ```bash
   ./scripts/validate-services.sh YOUR_INSTANCE_IP
   ```
3. **Check logs**:
   ```bash
   tail -f logs/deploy-*.log
   ```
4. **Check instance status**:
   ```bash
   linode-cli linodes view INSTANCE_ID
   ```

## Next Steps

- [Maintenance Guide](../README.md#-maintenance) - Update services, change models, view logs
- [Full Documentation](../README.md) - Complete feature list and technical details
- [Scripts README](../scripts/README.md) - Detailed script documentation

