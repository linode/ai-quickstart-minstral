#!/bin/bash
#
# Purpose:
#   Validates that all required tools and dependencies are installed and configured
#   before attempting independent deployment. Checks for linode-cli, jq, SSH keys,
#   and required files. Provides clear guidance on missing prerequisites.
#
#   Why it exists: Prevents deployment failures due to missing dependencies.
#   Helps developers quickly identify and resolve setup issues before attempting
#   deployment. Reduces frustration and speeds up onboarding.
#
# Dependencies:
#   - bash: Standard shell (required to run this script)
#   - linode-cli: Checked by this script (must be installed separately)
#   - jq: Checked by this script (optional but recommended)
#   - SSH keys: Checked by this script (optional but recommended)
#
# Troubleshooting:
#   - "linode-cli not installed": Install with 'pip install linode-cli'
#   - "linode-cli not configured": Run 'linode-cli configure' with API token
#   - "jq not installed": Install with 'brew install jq' (macOS) or 'apt-get install jq' (Linux)
#   - "SSH key not found": Generate with 'ssh-keygen -t rsa -b 4096' (optional but recommended)
#   - "Cloud-init file not found": Verify you're in project root, check file exists
#
# Specification Links:
#   - Tasks: specs/001-ai-sandbox/tasks.md (Phase 3 prerequisites)
#   - Scripts README: scripts/README.md
#
# Usage: ./check-prerequisites.sh

set -euo pipefail

# Determine script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

echo "Checking prerequisites for AI Quickstart - Minstral LLM deployment..."
echo ""

# Check linode-cli
if command -v linode-cli &> /dev/null; then
    echo -e "${GREEN}✓ linode-cli is installed${NC}"
    LINODE_CLI_VERSION=$(linode-cli --version 2>/dev/null || echo "unknown")
    echo "  Version: ${LINODE_CLI_VERSION}"
    
    # Check if configured
    if linode-cli profile view &> /dev/null; then
        echo -e "${GREEN}✓ linode-cli is configured${NC}"

        # Test API connectivity and GPU instance availability
        echo "  Testing API connectivity..."
        if linode-cli regions list --json &> /dev/null; then
            echo -e "${GREEN}✓ API connectivity verified${NC}"

            # Check if GPU instances are available
            GPU_AVAILABLE=$(linode-cli linodes types --json 2>/dev/null | jq -r '.[] | select(.id | startswith("g2-gpu")) | .id' 2>/dev/null | head -1)
            if [ -n "${GPU_AVAILABLE}" ]; then
                echo -e "${GREEN}✓ GPU instance types accessible${NC}"
            else
                echo -e "${YELLOW}⚠ Cannot find GPU instance types (may not have access)${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ API connectivity test failed${NC}"
            echo "  Check your API token permissions"
        fi
    else
        echo -e "${YELLOW}⚠ linode-cli is not configured${NC}"
        echo "  Run: linode-cli configure"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ linode-cli is not installed${NC}"
    echo "  Install with: pip install linode-cli"
    ERRORS=$((ERRORS + 1))
fi

# Check jq (required)
if command -v jq &> /dev/null; then
    echo -e "${GREEN}✓ jq is installed${NC}"
else
    echo -e "${RED}✗ jq is not installed (required for JSON parsing)${NC}"
    echo "  Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    ERRORS=$((ERRORS + 1))
fi

# Check openssl (required for password generation)
if command -v openssl &> /dev/null; then
    echo -e "${GREEN}✓ openssl is installed${NC}"
else
    echo -e "${RED}✗ openssl is not installed (required for password generation)${NC}"
    echo "  Usually pre-installed. Check your package manager if missing."
    ERRORS=$((ERRORS + 1))
fi

# Check SSH key (optional but recommended)
SSH_KEY_FOUND=""
for key_file in ~/.ssh/id_rsa.pub ~/.ssh/id_ed25519.pub ~/.ssh/id_ecdsa.pub; do
    if [ -f "${key_file}" ]; then
        SSH_KEY_FOUND="${key_file}"
        break
    fi
done

if [ -n "${SSH_KEY_FOUND}" ]; then
    echo -e "${GREEN}✓ SSH public key found: ${SSH_KEY_FOUND}${NC}"
else
    echo -e "${YELLOW}⚠ SSH public key not found (optional - password auth will be used)${NC}"
    echo "  To enable key-based auth, generate with: ssh-keygen -t ed25519"
fi

# Check cloud-init file
if [ -f "${PROJECT_ROOT}/cloud-init/ai-sandbox.yaml" ]; then
    echo -e "${GREEN}✓ Cloud-init file found: cloud-init/ai-sandbox.yaml${NC}"
else
    echo -e "${RED}✗ Cloud-init file not found: cloud-init/ai-sandbox.yaml${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check Docker Compose template
if [ -f "${PROJECT_ROOT}/docker/docker-compose.yml.template" ]; then
    echo -e "${GREEN}✓ Docker Compose template found: docker/docker-compose.yml.template${NC}"
else
    echo -e "${YELLOW}⚠ Docker Compose template not found (will use inline generation)${NC}"
fi

echo ""
if [ ${ERRORS} -eq 0 ]; then
    echo -e "${GREEN}✓ All critical prerequisites met!${NC}"
    echo ""
    echo "You can now run:"
    echo "  ./scripts/deploy-full.sh"
    exit 0
else
    echo -e "${RED}✗ Some prerequisites are missing${NC}"
    echo "Please install missing tools before proceeding"
    exit 1
fi

