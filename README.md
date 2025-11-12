# One-Click AI Sandbox

A Linode Marketplace App that deploys a complete, pre-configured AI inference stack with both a chat UI and an OpenAI-compatible API endpoint in minutes.

## 🚀 Quick Start

Deploy a GPU instance through the Linode Marketplace and be chatting with your own private AI model within 3-5 minutes—no code required.

## ✨ Features

- **One-Click Deployment**: Fully automated setup via Linode Marketplace
- **Complete AI Stack**: Includes both a web-based chat interface and an OpenAI-compatible API
- **Pre-Configured**: NVIDIA drivers, Docker, and all dependencies pre-installed
- **Fast Time-to-Value**: From instance boot to working AI in under 5 minutes
- **Model Flexibility**: Choose any model from Hugging Face at deployment
- **OpenAI-Compatible API**: Drop-in replacement for OpenAI endpoints—just change your `BASE_URL`

## 🏗️ Architecture

The AI Sandbox consists of two containerized services:

1. **API Service** (`vLLM`): High-performance inference engine running on port `8000`
   - OpenAI-compatible REST API
   - Supports any Hugging Face model
   - GPU-accelerated inference

2. **UI Service** (`Open WebUI`): Feature-rich chat interface on port `3000`
   - Browser-based chat UI
   - Persistent chat history
   - Connected to the API service automatically

Both services are managed via Docker Compose and configured to restart automatically.

## 📋 Requirements

- A Linode GPU instance (any supported GPU instance type)
  - **Note**: GPU instances require GPU access to be enabled on your account. If you don't see GPU instance types available, please contact Linode Support to enable GPU access.
- The "One-Click AI Sandbox" Marketplace App

## 🎯 Use Cases

### For AI Explorers
Try the latest open-source models (like Llama 3) in a chat interface without writing code or paying per-token API fees.

### For Backend Engineers
Get a stable, OpenAI-compatible API endpoint. Point your existing application to your own endpoint by simply changing the `BASE_URL`.

### For Full-Stack Developers
Use the chat UI to experiment with prompts, then use the same underlying API in your application for consistent results.

## 🚦 Getting Started

### Marketplace Deployment

1. Navigate to the Linode Marketplace
2. Select "One-Click AI Sandbox"
3. Choose your GPU instance type
4. Configure the deployment:
   - **Model ID**: Enter any Hugging Face model ID (e.g., `meta-llama/Llama-3-8B-Instruct`)
   - Default: `mistralai/Mistral-7B-Instruct-v0.3`
5. Deploy and wait 3-5 minutes for services to start

### Independent Deployment (Using Scripts)

For developers who want to deploy independently using the provided scripts:

#### Prerequisites

Before running the deployment, ensure you have all required tools installed:

1. **Check prerequisites**:
   ```bash
   ./scripts/check-prerequisites.sh
   ```

   This will verify:
   - `linode-cli` is installed and configured
   - `jq` is installed (for JSON parsing)
   - `openssl` is installed (for password generation)
   - SSH keys are available (optional but recommended)
   - Required files are present

2. **Install missing dependencies** (if needed):
   ```bash
   # Install Linode CLI
   pip install linode-cli
   linode-cli configure  # Follow prompts to add your API token
   
   # Install jq (macOS)
   brew install jq
   
   # Install jq (Linux)
   sudo apt-get install jq
   ```

#### Running Full Deployment

The `deploy-full.sh` script automates the entire deployment process in one command:

1. **Creates a new Linode GPU instance**
2. **Deploys the StackScript** to configure the instance
3. **Waits for services to start** (3-5 minutes)
4. **Validates the deployment** to ensure everything is working

**Interactive Mode** (recommended for first-time users):
```bash
./scripts/deploy-full.sh
```

The script will prompt you to:
- Select a region from RTX4000-available regions:
  - Chicago, US (us-ord)
  - Frankfurt 2, DE (de-fra-2)
  - Osaka, JP (jp-osa)
  - Paris, FR (fr-par)
  - Seattle, WA, US (us-sea)
  - Singapore 2, SG (sg-sin-2)
- Select an RTX4000 instance size (e.g., Small, Medium, Large)
- Optionally specify a model ID (defaults to `mistralai/Mistral-7B-Instruct-v0.3`)

**Non-Interactive Mode** (for automation):
```bash
./scripts/deploy-full.sh [instance-type] [region] [model-id]
```

Example:
```bash
./scripts/deploy-full.sh g2-gpu-rtx4000a1-s us-sea mistralai/Mistral-7B-Instruct-v0.3
```

#### What Happens During Deployment

1. **Instance Creation** (Step 1):
   - Creates a new Linode GPU instance with your selected configuration
   - Generates a secure root password automatically
   - Saves instance information to `.instance-info-<ID>.json`
   - Verifies the instance was created successfully

2. **StackScript Deployment** (Step 2):
   - Uploads and executes the AI Sandbox StackScript
   - Installs NVIDIA drivers, Docker, and dependencies
   - Configures the Docker Compose services
   - Downloads and sets up the selected model

3. **Service Initialization** (Step 3):
   - Waits 60 seconds for services to begin starting
   - Services typically take 3-5 minutes to fully initialize

4. **Validation** (Step 4):
   - Checks SSH connectivity to the instance
   - Verifies Docker Compose services are running
   - Tests API and UI endpoints are accessible
   - Displays deployment status

#### After Deployment

Upon successful deployment, you'll see:

- **Instance Information**:
  - Instance ID
  - Instance IP address
  - Model ID used
  - Root password (saved in `.instance-info-<ID>.json`)

- **Service URLs**:
  - Chat UI: `http://YOUR_INSTANCE_IP:3000`
  - API Endpoint: `http://YOUR_INSTANCE_IP:8000/v1`

- **SSH Access**:
  ```bash
  ssh root@YOUR_INSTANCE_IP
  ```

- **Log File Location**:
  - Deployment logs are saved to `logs/deploy-YYYYMMDD-HHMMSS.log`
  - View with: `tail -f logs/deploy-*.log`

#### Troubleshooting

If deployment fails or services aren't ready:

1. **Check the log file**: The log file path is displayed at the start of deployment
   ```bash
   tail -f logs/deploy-*.log
   ```

2. **Re-run validation** (if services aren't ready):
   ```bash
   ./scripts/validate-services.sh YOUR_INSTANCE_IP
   ```

3. **Check instance status**:
   ```bash
   linode-cli linodes view INSTANCE_ID
   ```

4. **Common issues**:
   - **Services not ready**: Wait 3-5 minutes after deployment, then re-run validation
   - **Instance creation failed**: Check API token permissions and available regions
   - **Deployment timeout**: Instance may still be booting; wait and re-run validation

For more detailed troubleshooting, see the [Scripts README](scripts/README.md).

### Accessing Your Services

Once deployed (via Marketplace or scripts), access your services at:

- **Chat UI**: `http://YOUR_INSTANCE_IP:3000`
- **API Endpoint**: `http://YOUR_INSTANCE_IP:8000/v1`

### API Usage

The API is fully OpenAI-compatible. Example:

```bash
curl http://YOUR_INSTANCE_IP:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistralai/Mistral-7B-Instruct-v0.3",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## 🔒 Security

**⚠️ IMPORTANT**: By default, both services are exposed to the internet without authentication.

**You must configure a Linode Cloud Firewall** to protect:
- Port `3000` (UI)
- Port `8000` (API)

A security warning is displayed in the system Message of the Day (`/etc/motd`) when you SSH into the instance.

## 🛠️ Maintenance

### Updating Services

To update the containers, edit `/opt/ai-sandbox/docker-compose.yml` and run:

```bash
cd /opt/ai-sandbox
docker-compose up -d
```

### Changing Models

To switch models, update the `MODEL_ID` environment variable in `/opt/ai-sandbox/docker-compose.yml` and restart:

```bash
cd /opt/ai-sandbox
docker-compose down
docker-compose up -d
```

### Viewing Logs

```bash
cd /opt/ai-sandbox
docker-compose logs -f
```

## 📁 Directory Structure

- `/opt/models` - Model cache directory
- `/opt/open-webui` - Chat UI persistent data
- `/opt/ai-sandbox/docker-compose.yml` - Service configuration

## 🔧 Technical Details

### Base Image

The Marketplace App deploys on a custom Ubuntu 22.04 LTS image with:
- NVIDIA Drivers (latest stable)
- Docker Engine
- Docker Compose v2

### Services

- **API**: `ghcr.io/vllm-project/vllm-openai:latest`
- **UI**: `ghcr.io/open-webui/open-webui:main`

## 📝 Limitations (V1)

- No automatic API authentication (use firewall)
- No user accounts for the UI (open by default)
- No automatic HTTPS/SSL
- Inference only (no fine-tuning support)

## 🤝 Contributing

This is a Linode Marketplace App. For issues or feature requests, please open an issue in this repository.

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

**Status**: Draft v1.0  
**Product**: Akamai Cloud / Linode Marketplace

