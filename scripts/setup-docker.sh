#!/bin/bash
#
# Purpose:
#   Installs Docker Engine, Docker Compose, and NVIDIA Container Toolkit on a fresh
#   Ubuntu instance to prepare it for AI Quickstart - Minstral LLM deployment.
#
# Usage: ./setup-docker.sh
#   Can be run locally or copied to remote instance
#
# Dependencies:
#   - Ubuntu 22.04
#   - Internet connectivity
#   - sudo/root access

set -euo pipefail

# Non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Docker & NVIDIA Setup for AI Quickstart - Minstral LLM ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Run with: sudo $0"
    exit 1
fi

# Step 1: Update system
echo -e "${GREEN}[1/5] Updating system packages...${NC}"
apt-get update -qq
apt-get upgrade -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Step 2: Install Docker
echo -e "${GREEN}[2/5] Installing Docker Engine...${NC}"

# Remove old versions if they exist
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install prerequisites
apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

echo -e "${GREEN}✓ Docker installed: $(docker --version)${NC}"

# Step 3: Install Docker Compose (standalone for compatibility)
echo -e "${GREEN}[3/5] Installing Docker Compose...${NC}"

# Docker Compose v2 is installed via plugin, but also install standalone for compatibility
COMPOSE_VERSION="v2.24.0"
curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo -e "${GREEN}✓ Docker Compose installed: $(docker-compose --version)${NC}"

# Step 4: Install NVIDIA Container Toolkit
echo -e "${GREEN}[4/5] Installing NVIDIA Container Toolkit...${NC}"

# Add NVIDIA repository
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update -qq
apt-get install -y -qq nvidia-container-toolkit

# Configure Docker to use NVIDIA runtime
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

echo -e "${GREEN}✓ NVIDIA Container Toolkit installed${NC}"

# Step 5: Verify installation
echo -e "${GREEN}[5/5] Verifying installation...${NC}"

# Test Docker
if docker run --rm hello-world > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker is working${NC}"
else
    echo -e "${YELLOW}⚠ Docker test failed${NC}"
fi

# Check GPU access (will fail gracefully if no GPU)
if command -v nvidia-smi &> /dev/null; then
    echo -e "${GREEN}✓ NVIDIA drivers detected${NC}"
    nvidia-smi -L 2>/dev/null || echo -e "${YELLOW}⚠ GPU not detected or drivers not loaded${NC}"
else
    echo -e "${YELLOW}⚠ NVIDIA drivers not installed (will be installed on first boot if GPU instance)${NC}"
fi

echo ""
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "System is ready for AI Quickstart - Minstral LLM deployment:"
echo "  - Docker Engine: $(docker --version | cut -d' ' -f3)"
echo "  - Docker Compose: $(docker-compose --version | cut -d' ' -f4)"
echo "  - NVIDIA Container Toolkit: Installed"
echo ""
echo "Next steps:"
echo "  1. Deploy AI Quickstart - Minstral LLM using cloud-init (automatic on instance creation)"
echo "  2. Or manually configure services using docker-compose"
echo ""
