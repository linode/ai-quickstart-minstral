# Architecture

## Overview

AI Quickstart - Minstral LLM consists of two containerized services that work together to provide a complete AI inference stack:

1. **API Service** (`vLLM`): High-performance inference engine
2. **UI Service** (`Open WebUI`): Feature-rich chat interface

Both services are managed via Docker Compose and configured to restart automatically.

## Services

### API Service (vLLM)

- **Port**: `8000`
- **Container**: `ghcr.io/vllm-project/vllm-openai:latest`
- **Purpose**: High-performance inference engine with OpenAI-compatible REST API
- **Features**:
  - OpenAI-compatible REST API
  - Supports any Hugging Face model
  - GPU-accelerated inference
  - Optimized for production workloads

### UI Service (Open WebUI)

- **Port**: `3000`
- **Container**: `ghcr.io/open-webui/open-webui:main`
- **Purpose**: Browser-based chat interface
- **Features**:
  - Browser-based chat UI
  - Persistent chat history
  - Connected to the API service automatically
  - User-friendly interface for interacting with models

## Base Image

The deployment uses a custom Ubuntu 22.04 LTS image with:

- **NVIDIA Drivers**: Latest stable version
- **Docker Engine**: Container runtime
- **Docker Compose v2**: Service orchestration

## Directory Structure

The following directories are used on the deployed instance:

- `/opt/models` - Model cache directory (stores downloaded models)
- `/opt/open-webui` - Chat UI persistent data (chat history, settings)
- `/opt/ai-sandbox/docker-compose.yml` - Service configuration file

## Service Communication

The UI service automatically connects to the API service running on `localhost:8000`. Both services run on the same instance and communicate over the Docker network.

## Resource Requirements

- **GPU**: Any supported Linode GPU instance type
- **Memory**: Varies by model size (check model requirements)
- **Storage**: Sufficient space for model files (models can be several GB)

## Deployment Architecture

When deployed via the scripts:

1. A new Linode GPU instance is created with cloud-init configuration
2. Cloud-init automatically installs system dependencies (NVIDIA drivers, Docker) on first boot
3. Docker Compose services are configured and started
4. The selected model is downloaded and cached
5. Services are validated and ready for use

