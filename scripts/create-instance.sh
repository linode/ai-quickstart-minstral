#!/bin/bash
#
# Purpose:
#   Creates a new Linode GPU instance via Linode CLI for AI Quickstart - Minstral LLM deployment.
#   The script creates the instance with cloud-init configuration, waits for it to boot,
#   and saves instance information for use by other deployment scripts.
#
#   Why it exists: Enables automated deployment workflow. Allows repeatable instance
#   creation for testing iterations.
#
# Dependencies:
#   - linode-cli: Linode command-line interface (pip install linode-cli)
#   - linode-cli configured: Must run 'linode-cli configure' with API token
#   - jq: JSON parser for processing API responses (brew install jq / apt-get install jq)
#   - openssl: For generating random passwords (usually pre-installed)
#   - SSH key: Optional but recommended for SSH access (generates password if not using key)
#
# Troubleshooting:
#   - "linode-cli not installed": Install with 'pip install linode-cli'
#   - "linode-cli not configured": Run 'linode-cli configure' and provide API token
#   - "Instance creation failed": Check API token permissions, verify GPU instance access
#   - "Cannot parse instance ID": Check jq installation, verify linode-cli JSON output format
#   - Instance takes long to boot: Normal, script waits up to 5 minutes
#   - SSH not ready: Wait longer, instance may still be initializing
#
# Specification Links:
#   - Feature Spec: specs/001-ai-sandbox/spec.md
#   - Tasks: specs/001-ai-sandbox/tasks.md (Phase 3, T041)
#   - Independent Deployment: specs/001-ai-sandbox/plan.md (Development Priority section)
#
# Usage: ./create-instance.sh [instance-type] [region] [root-password] [label] [model-id]
#   If instance-type or region are omitted, interactive prompts will be shown
#   model-id: Optional, defaults to mistralai/Mistral-7B-Instruct-v0.3

set -euo pipefail

# RTX4000 Configuration - Regions where RTX4000 instances are available
RTX4000_REGIONS=(
    "us-ord:Chicago, US"
    "de-fra-2:Frankfurt 2, DE"
    "jp-osa:Osaka, JP"
    "fr-par:Paris, FR"
    "us-sea:Seattle, WA, US"
    "sg-sin-2:Singapore 2, SG"
)

# RTX4000 Instance Types
RTX4000_INSTANCE_TYPES=(
    "g2-gpu-rtx4000a1-s:RTX4000 Ada x1 Small - \$350/month"
    "g2-gpu-rtx4000a1-m:RTX4000 Ada x1 Medium - \$446/month"
    "g2-gpu-rtx4000a1-l:RTX4000 Ada x1 Large - \$638/month"
    "g2-gpu-rtx4000a1-xl:RTX4000 Ada x1 X-Large - \$1022/month"
    "g2-gpu-rtx4000a2-s:RTX4000 Ada x2 Small - \$700/month"
    "g2-gpu-rtx4000a2-m:RTX4000 Ada x2 Medium - \$892/month"
    "g2-gpu-rtx4000a2-hs:RTX4000 Ada x2 Medium High Storage - \$992/month"
    "g2-gpu-rtx4000a4-s:RTX4000 Ada x4 Small - \$1976/month"
    "g2-gpu-rtx4000a4-m:RTX4000 Ada x4 Medium - \$2384/month"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Prompt for region selection
prompt_region() {
    local provided_region="${1:-}"
    
    if [ -n "${provided_region}" ]; then
        # Validate provided region
        local valid=false
        for region_entry in "${RTX4000_REGIONS[@]}"; do
            local region_id="${region_entry%%:*}"
            if [ "${region_id}" = "${provided_region}" ]; then
                valid=true
                break
            fi
        done
        
        if [ "${valid}" = "true" ]; then
            echo "${provided_region}"
            return 0
        else
            echo -e "${YELLOW}Warning: Invalid region '${provided_region}'. Showing options...${NC}" >&2
        fi
    fi
    
    # Interactive prompt
    echo ""
    echo -e "${CYAN}Select Region (RTX4000 available regions):${NC}"
    local index=1
    for region_entry in "${RTX4000_REGIONS[@]}"; do
        local region_id="${region_entry%%:*}"
        local region_label="${region_entry#*:}"
        echo "  ${index}) ${region_label} (${region_id})"
        index=$((index + 1))
    done
    
    while true; do
        echo -ne "${CYAN}Enter choice [1-${#RTX4000_REGIONS[@]}]: ${NC}" >&2
        # Read from stdin (works in all contexts)
        read -r choice 2>/dev/null || true
        
        if [[ "${choice}" =~ ^[0-9]+$ ]] && [ "${choice}" -ge 1 ] && [ "${choice}" -le ${#RTX4000_REGIONS[@]} ]; then
            local selected_entry="${RTX4000_REGIONS[$((choice - 1))]}"
            echo "${selected_entry%%:*}"
            return 0
        else
            echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#RTX4000_REGIONS[@]}.${NC}" >&2
        fi
    done
}

# Prompt for instance size selection
prompt_instance_size() {
    local provided_size="${1:-}"
    
    if [ -n "${provided_size}" ]; then
        # Validate provided size
        local valid=false
        for size_entry in "${RTX4000_INSTANCE_TYPES[@]}"; do
            local size_id="${size_entry%%:*}"
            if [ "${size_id}" = "${provided_size}" ]; then
                valid=true
                break
            fi
        done
        
        if [ "${valid}" = "true" ]; then
            echo "${provided_size}"
            return 0
        else
            echo -e "${YELLOW}Warning: Invalid instance type '${provided_size}'. Showing options...${NC}" >&2
        fi
    fi
    
    # Interactive prompt
    echo ""
    echo -e "${CYAN}Select Instance Size (RTX4000):${NC}"
    local index=1
    for size_entry in "${RTX4000_INSTANCE_TYPES[@]}"; do
        local size_id="${size_entry%%:*}"
        local size_label="${size_entry#*:}"
        echo "  ${index}) ${size_label} (${size_id})"
        index=$((index + 1))
    done
    
    while true; do
        echo -ne "${CYAN}Enter choice [1-${#RTX4000_INSTANCE_TYPES[@]}]: ${NC}" >&2
        # Read from stdin (works in all contexts)
        read -r choice 2>/dev/null || true
        
        if [[ "${choice}" =~ ^[0-9]+$ ]] && [ "${choice}" -ge 1 ] && [ "${choice}" -le ${#RTX4000_INSTANCE_TYPES[@]} ]; then
            local selected_entry="${RTX4000_INSTANCE_TYPES[$((choice - 1))]}"
            echo "${selected_entry%%:*}"
            return 0
        else
            echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#RTX4000_INSTANCE_TYPES[@]}.${NC}" >&2
        fi
    done
}

# Function to generate a strong password that meets Linode requirements
# Linode requires: 11-128 chars, at least 3 of: uppercase, lowercase, numbers, special chars
# We ensure ALL 4 types with at least 3 of each for extra strength
generate_password() {
    # Character sets
    UPPER_CHARS="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    LOWER_CHARS="abcdefghijklmnopqrstuvwxyz"
    NUMBERS="0123456789"
    # Use only commonly accepted special characters
    SPECIAL_CHARS="!@#$&*-_"

    # Generate at least 3 of each type to ensure strength
    # Uppercase: 3 random chars
    UPPER_PART=""
    for i in 1 2 3; do
        UPPER_PART="${UPPER_PART}${UPPER_CHARS:$((RANDOM % 26)):1}"
    done

    # Lowercase: 3 random chars
    LOWER_PART=""
    for i in 1 2 3; do
        LOWER_PART="${LOWER_PART}${LOWER_CHARS:$((RANDOM % 26)):1}"
    done

    # Numbers: 3 random chars
    NUMBER_PART=""
    for i in 1 2 3; do
        NUMBER_PART="${NUMBER_PART}${NUMBERS:$((RANDOM % 10)):1}"
    done

    # Special chars: 3 random chars
    SPECIAL_PART=""
    for i in 1 2 3; do
        SPECIAL_PART="${SPECIAL_PART}${SPECIAL_CHARS:$((RANDOM % ${#SPECIAL_CHARS})):1}"
    done

    # Add more random alphanumeric to reach 24+ characters
    RANDOM_PART=$(openssl rand -base64 12 | tr -d "=+/" | head -c 12)

    # Combine all parts (24+ characters, guaranteed mix)
    ROOT_PASSWORD="${UPPER_PART}${LOWER_PART}${NUMBER_PART}${SPECIAL_PART}${RANDOM_PART}"
}

# Get parameters (if provided) or prompt interactively
INSTANCE_TYPE=$(prompt_instance_size "${1:-}")
REGION=$(prompt_region "${2:-}")

# Handle password: if provided as parameter, use it; otherwise prompt or auto-generate
PASSWORD_WAS_GENERATED=false

# Check if we're in an interactive terminal (TTY)
IS_INTERACTIVE=false
if [ -t 0 ] && [ -t 1 ]; then
    IS_INTERACTIVE=true
fi

if [ -n "${3:-}" ]; then
    # Password provided as parameter
    ROOT_PASSWORD="${3}"
    PASSWORD_WAS_GENERATED=false
elif [ "${IS_INTERACTIVE}" = "true" ]; then
    # Interactive terminal - prompt for password
    echo "" >&2
    echo -e "${CYAN}Root Password (leave blank to generate random password):${NC}" >&2
    echo -ne "${CYAN}Enter password: ${NC}" >&2
    # Use -s to hide input for security (silent mode)
    # Read from stdin (works in all contexts)
    read -rs ROOT_PASSWORD 2>/dev/null || true
    echo "" >&2  # New line after hidden input
    
    # If blank, generate a random password
    if [ -z "${ROOT_PASSWORD}" ]; then
        generate_password
        PASSWORD_WAS_GENERATED=true
        echo "" >&2
        echo -e "${YELLOW}Generated root password: ${ROOT_PASSWORD}${NC}" >&2
        echo -e "${YELLOW}⚠️  Save this password for SSH access!${NC}" >&2
    else
        PASSWORD_WAS_GENERATED=false
        echo "" >&2
        echo -e "${GREEN}Using provided password${NC}" >&2
    fi
else
    # Non-interactive (called from another script) - auto-generate password
    generate_password
    PASSWORD_WAS_GENERATED=true
    echo "Generated root password: ${ROOT_PASSWORD}" >&2
fi

LABEL="${4:-ai-quickstart-minstral-$(date +%s)}"
MODEL_ID="${5:-${MODEL_ID:-mistralai/Mistral-7B-Instruct-v0.3}}"
IMAGE="linode/ubuntu22.04"

# Determine script directory and project root for cloud-init file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLOUD_INIT_FILE="${PROJECT_ROOT}/cloud-init/ai-sandbox.yaml"

# Check if cloud-init file exists
if [ ! -f "${CLOUD_INIT_FILE}" ]; then
    echo -e "${RED}Error: Cloud-init file not found: ${CLOUD_INIT_FILE}${NC}" >&2
    exit 1
fi

# Read cloud-init file and substitute MODEL_ID placeholder
CLOUD_INIT_CONTENT=$(cat "${CLOUD_INIT_FILE}" | sed "s|MODEL_ID_PLACEHOLDER|${MODEL_ID}|g")

# Base64 encode the cloud-init content (required by linode-cli)
CLOUD_INIT_B64=$(echo -n "${CLOUD_INIT_CONTENT}" | base64)

# Check if linode-cli is installed
if ! command -v linode-cli &> /dev/null; then
    echo -e "${RED}Error: linode-cli is not installed${NC}"
    echo "Install it with: pip install linode-cli"
    echo "Or configure it with: linode-cli configure"
    exit 1
fi

# Check if linode-cli is configured
if ! linode-cli profile view &> /dev/null; then
    echo -e "${YELLOW}Warning: linode-cli may not be configured${NC}"
    echo "Run: linode-cli configure"
fi

# Password validation - ensure it meets Linode requirements if provided
# Linode requires: 11-128 chars, at least 3 of: uppercase, lowercase, numbers, special chars
if [ -n "${ROOT_PASSWORD}" ]; then
    # Check password length
    if [ ${#ROOT_PASSWORD} -lt 11 ] || [ ${#ROOT_PASSWORD} -gt 128 ]; then
        echo -e "${RED}Error: Password must be 11-128 characters long${NC}"
        exit 1
    fi
    
    # Note: We don't validate character types here since user provided it
    # Linode API will reject if it doesn't meet requirements
fi

echo -e "${GREEN}Creating Linode GPU instance...${NC}"
echo "Instance Type: ${INSTANCE_TYPE}"
echo "Region: ${REGION}"
echo "Label: ${LABEL}"
echo ""

# Create the instance
echo "Calling linode-cli to create instance..." >&2
# Note: This may take 10-30 seconds depending on API response time
# Use a temp file to capture output to avoid command substitution issues

# Find available SSH key (try common locations)
SSH_KEY=""
for key_file in ~/.ssh/id_rsa.pub ~/.ssh/id_ed25519.pub ~/.ssh/id_ecdsa.pub; do
    if [ -f "${key_file}" ]; then
        SSH_KEY=$(cat "${key_file}" 2>/dev/null || echo "")
        if [ -n "${SSH_KEY}" ]; then
            echo "Using SSH key: ${key_file}" >&2
            break
        fi
    fi
done

TEMP_OUTPUT=$(mktemp)
if [ -n "${SSH_KEY}" ]; then
    # Create with SSH key and cloud-init user_data (base64-encoded)
    # Use --no-defaults to avoid extra output that interferes with JSON parsing
    linode-cli linodes create \
        --type "${INSTANCE_TYPE}" \
        --region "${REGION}" \
        --image "${IMAGE}" \
        --root_pass "${ROOT_PASSWORD}" \
        --label "${LABEL}" \
        --authorized_keys "${SSH_KEY}" \
        --metadata.user_data "${CLOUD_INIT_B64}" \
        --no-defaults \
        --json > "${TEMP_OUTPUT}" 2>&1
else
    # Create without SSH key (password only) but with cloud-init user_data (base64-encoded)
    echo "No SSH key found, creating with password only" >&2
    linode-cli linodes create \
        --type "${INSTANCE_TYPE}" \
        --region "${REGION}" \
        --image "${IMAGE}" \
        --root_pass "${ROOT_PASSWORD}" \
        --label "${LABEL}" \
        --metadata.user_data "${CLOUD_INIT_B64}" \
        --no-defaults \
        --json > "${TEMP_OUTPUT}" 2>&1
fi
CREATE_EXIT_CODE=$?
INSTANCE_JSON=$(cat "${TEMP_OUTPUT}")
rm -f "${TEMP_OUTPUT}"

if [ ${CREATE_EXIT_CODE} -ne 0 ]; then
    ERROR_MSG="Error creating instance"
    echo -e "${RED}✗ ${ERROR_MSG}${NC}" >&2
    echo "" >&2
    echo "Linode CLI Error:" >&2
    echo "${INSTANCE_JSON}" >&2
    echo "" >&2
    echo -e "${YELLOW}Generated password (for debugging): ${ROOT_PASSWORD}${NC}" >&2
    echo -e "${YELLOW}Password length: ${#ROOT_PASSWORD} characters${NC}" >&2
    echo "" >&2
    echo -e "${YELLOW}Troubleshooting:${NC}" >&2
    echo "  1. Check your Linode API token: linode-cli profile view" >&2
    echo "  2. Verify you have access to GPU instances" >&2
    echo "  3. Check if the instance type is available in the selected region" >&2
    echo "  4. Verify your password meets requirements (11-128 chars, mixed case, numbers, special chars)" >&2

    # Log to file if LOG_FILE is set (when called from deploy-full.sh)
    if [ -n "${LOG_FILE:-}" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: Instance creation failed" >> "${LOG_FILE}" 2>/dev/null || true
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: Exit code: ${CREATE_EXIT_CODE}" >> "${LOG_FILE}" 2>/dev/null || true
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: Generated password: ${ROOT_PASSWORD} (length: ${#ROOT_PASSWORD})" >> "${LOG_FILE}" 2>/dev/null || true
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: API Response: ${INSTANCE_JSON}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
    exit 1
fi

# Extract instance ID and IP
INSTANCE_ID=$(echo "${INSTANCE_JSON}" | jq -r '.[0].id')
INSTANCE_IP=$(echo "${INSTANCE_JSON}" | jq -r '.[0].ipv4[0]')

if [ -z "${INSTANCE_ID}" ] || [ "${INSTANCE_ID}" = "null" ]; then
    ERROR_MSG="Failed to parse instance ID from Linode API response"
    echo -e "${RED}✗ Error: ${ERROR_MSG}${NC}" >&2
    echo "" >&2
    echo "API Response:" >&2
    echo "${INSTANCE_JSON}" >&2
    echo "" >&2
    echo -e "${YELLOW}This may indicate:${NC}" >&2
    echo "  - API response format changed" >&2
    echo "  - Instance creation partially failed" >&2
    echo "  - Network/API connectivity issue" >&2

    # Log to file if LOG_FILE is set
    if [ -n "${LOG_FILE:-}" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: ${ERROR_MSG}" >> "${LOG_FILE}" 2>/dev/null || true
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: API Response: ${INSTANCE_JSON}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
    exit 1
fi

# Validate IP was also extracted
if [ -z "${INSTANCE_IP}" ] || [ "${INSTANCE_IP}" = "null" ]; then
    echo -e "${YELLOW}⚠️  Warning: Could not extract instance IP from response${NC}" >&2
    echo "Instance ID: ${INSTANCE_ID}" >&2
    echo "You may need to get the IP manually: linode-cli linodes view ${INSTANCE_ID}" >&2
fi

echo -e "${GREEN}✓ Instance created successfully!${NC}"
echo ""
echo "Instance ID: ${INSTANCE_ID}"
echo "Instance IP: ${INSTANCE_IP}"
if [ "${PASSWORD_WAS_GENERATED}" = "true" ]; then
    echo "Root Password: ${ROOT_PASSWORD}"
    echo -e "${YELLOW}⚠️  IMPORTANT: Save this password for SSH access!${NC}"
else
    echo "Root Password: [provided by user]"
fi
echo "Label: ${LABEL}"
echo ""

# Wait for instance to be running
# Only wait if we're in interactive mode (not when called from deploy-full.sh)
if [ "${IS_INTERACTIVE}" = "true" ]; then
    MAX_WAIT=300
    WAIT_TIME=0
    echo "Waiting for instance to boot..."
    echo "This may take 1-2 minutes..."
    
    while [ ${WAIT_TIME} -lt ${MAX_WAIT} ]; do
        STATUS=$(linode-cli linodes view "${INSTANCE_ID}" --json 2>/dev/null | jq -r '.[0].status' 2>/dev/null || echo "unknown")
        
        if [ "${STATUS}" = "running" ]; then
            echo -e "${GREEN}✓ Instance is running!${NC}" >&2
            break
        fi
        
        if [ "${STATUS}" != "unknown" ]; then
            echo "  Status: ${STATUS} (waiting...)" >&2
        fi
        sleep 10
        WAIT_TIME=$((WAIT_TIME + 10))
    done

    if [ ${WAIT_TIME} -ge ${MAX_WAIT} ]; then
        echo -e "${YELLOW}Warning: Instance may not be fully booted yet${NC}" >&2
    fi

    # Wait a bit more for SSH to be ready
    echo "Waiting for SSH to be ready..." >&2
    sleep 30
else
    # Non-interactive mode: just report status, don't wait
    echo "Instance is provisioning. It will be ready in 1-2 minutes." >&2
fi

# Save instance info to file for other scripts
INSTANCE_INFO_FILE=".instance-info-${INSTANCE_ID}.json"
cat > "${INSTANCE_INFO_FILE}" <<EOF
{
  "instance_id": "${INSTANCE_ID}",
  "instance_ip": "${INSTANCE_IP}",
  "instance_type": "${INSTANCE_TYPE}",
  "region": "${REGION}",
  "label": "${LABEL}",
  "root_password": "${ROOT_PASSWORD}",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Log successful file creation
if [ -n "${LOG_FILE:-}" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: Instance info file created: ${INSTANCE_INFO_FILE}" >> "${LOG_FILE}" 2>/dev/null || true
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: Instance ID: ${INSTANCE_ID}, IP: ${INSTANCE_IP}" >> "${LOG_FILE}" 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}Instance information saved to: ${INSTANCE_INFO_FILE}${NC}"
echo ""
echo "Cloud-init configuration has been applied. The instance will automatically:"
echo "  - Install Docker and dependencies"
echo "  - Configure NVIDIA drivers"
echo "  - Deploy AI Quickstart - Minstral LLM services"
echo ""
echo "Monitor deployment:"
echo "  ssh root@${INSTANCE_IP} 'tail -f /var/log/cloud-init-output.log'"
echo "  ssh root@${INSTANCE_IP} 'tail -f /var/log/ai-sandbox/deployment.log'"
echo ""
echo "SSH access:"
echo "  ssh root@${INSTANCE_IP}"

