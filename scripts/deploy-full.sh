#!/bin/bash
#
# Purpose:
#   End-to-end deployment workflow that creates a Linode GPU instance with cloud-init
#   configuration and validates the deployment. Combines create-instance.sh with
#   validation for a complete deployment experience.
#
#   Why it exists: Simplifies the deployment process to a single command for
#   quick testing and demonstration. Provides a complete workflow from instance
#   creation to validated deployment. Cloud-init automatically deploys services on first boot.
#
# Dependencies:
#   - All dependencies from create-instance.sh (linode-cli, jq, openssl)
#   - validate-services.sh: For post-deployment validation
#   - Internet connectivity: For instance creation and cloud-init deployment
#
# Troubleshooting:
#   - "Failed to create instance": See create-instance.sh troubleshooting
#   - "Services not ready": Wait longer (3-5 minutes), services may still be starting
#   - Validation warnings: Normal if services are still initializing, re-run validation
#   - Instance info file missing: Check .instance-info-<ID>.json was created
#   - Cloud-init logs: Check /var/log/cloud-init-output.log on the instance
#
# Specification Links:
#   - Feature Spec: specs/001-ai-sandbox/spec.md
#   - Tasks: specs/001-ai-sandbox/tasks.md (Phase 3, T044)
#   - Quick Start: specs/001-ai-sandbox/quickstart.md
#
# Usage: ./deploy-full.sh [instance-type] [region] [model-id]
#   If parameters are omitted, interactive prompts will be shown
#   model-id: Optional, defaults to mistralai/Mistral-7B-Instruct-v0.3

set -euo pipefail

# Log file for debugging - timestamped log in logs/ directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"
mkdir -p "${LOG_DIR}"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
LOG_FILE="${LOG_DIR}/deploy-${TIMESTAMP}.log"

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
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging function - writes to log file only (doesn't output to terminal)
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
}

# Error display function
show_error() {
    local message="$1"
    local details="${2:-}"
    log "ERROR: ${message}"
    if [ -n "${details}" ]; then
        log "ERROR DETAILS: ${details}"
    fi
    echo -e "${RED}✗ ${message}${NC}" >&2
    if [ -n "${details}" ]; then
        echo "${details}" >&2
    fi
    echo -e "${YELLOW}Check log file for details: ${LOG_FILE}${NC}" >&2
}

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
    
    # If no parameter provided and we reach here, it means we're in interactive mode
    # (non-interactive mode is handled at script level)
    
    # Interactive prompt - try to read from /dev/tty if available
    echo "" >&2
    echo -e "${CYAN}Select Region (RTX4000 available regions):${NC}" >&2
    local index=1
    for region_entry in "${RTX4000_REGIONS[@]}"; do
        local region_id="${region_entry%%:*}"
        local region_label="${region_entry#*:}"
        echo "  ${index}) ${region_label} (${region_id})" >&2
        index=$((index + 1))
    done
    
    # Use /dev/tty for reading if available, otherwise stdin
    local tty_input=""
    if [ -c /dev/tty ] && [ -r /dev/tty ] 2>/dev/null; then
        tty_input="</dev/tty"
    fi
    
    while true; do
        echo -ne "${CYAN}Enter choice [1-${#RTX4000_REGIONS[@]}]: ${NC}" >&2
        # Try to read from TTY, fallback to stdin
        if ! eval "read -r choice ${tty_input}" 2>/dev/null; then
            # If reading fails, use default
            echo -e "\n${YELLOW}Cannot read input. Using default region.${NC}" >&2
            local default_entry="${RTX4000_REGIONS[0]}"
            echo "${default_entry%%:*}"
            return 0
        fi
        
        if [[ "${choice}" =~ ^[0-9]+$ ]] && [ "${choice}" -ge 1 ] && [ "${choice}" -le ${#RTX4000_REGIONS[@]} ]; then
            local selected_entry="${RTX4000_REGIONS[$((choice - 1))]}"
            echo "${selected_entry%%:*}"
            return 0
        elif [ -z "${choice}" ]; then
            # Empty input - use default
            echo -e "${YELLOW}No input provided. Using default region.${NC}" >&2
            local default_entry="${RTX4000_REGIONS[0]}"
            echo "${default_entry%%:*}"
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
    
    # If no parameter provided and we reach here, it means we're in interactive mode
    # (non-interactive mode is handled at script level)
    
    # Interactive prompt - try to read from /dev/tty if available
    echo "" >&2
    echo -e "${CYAN}Select Instance Size (RTX4000):${NC}" >&2
    local index=1
    for size_entry in "${RTX4000_INSTANCE_TYPES[@]}"; do
        local size_id="${size_entry%%:*}"
        local size_label="${size_entry#*:}"
        echo "  ${index}) ${size_label} (${size_id})" >&2
        index=$((index + 1))
    done
    
    # Use /dev/tty for reading if available, otherwise stdin
    local tty_input=""
    if [ -c /dev/tty ] && [ -r /dev/tty ] 2>/dev/null; then
        tty_input="</dev/tty"
    fi
    
    while true; do
        echo -ne "${CYAN}Enter choice [1-${#RTX4000_INSTANCE_TYPES[@]}]: ${NC}" >&2
        # Try to read from TTY, fallback to stdin
        if ! eval "read -r choice ${tty_input}" 2>/dev/null; then
            # If reading fails, use default
            echo -e "\n${YELLOW}Cannot read input. Using default instance type.${NC}" >&2
            local default_entry="${RTX4000_INSTANCE_TYPES[0]}"
            echo "${default_entry%%:*}"
            return 0
        fi
        
        if [[ "${choice}" =~ ^[0-9]+$ ]] && [ "${choice}" -ge 1 ] && [ "${choice}" -le ${#RTX4000_INSTANCE_TYPES[@]} ]; then
            local selected_entry="${RTX4000_INSTANCE_TYPES[$((choice - 1))]}"
            echo "${selected_entry%%:*}"
            return 0
        elif [ -z "${choice}" ]; then
            # Empty input - use default
            echo -e "${YELLOW}No input provided. Using default instance type.${NC}" >&2
            local default_entry="${RTX4000_INSTANCE_TYPES[0]}"
            echo "${default_entry%%:*}"
            return 0
        else
            echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#RTX4000_INSTANCE_TYPES[@]}.${NC}" >&2
        fi
    done
}

# Initialize logging (LOG_DIR and LOG_FILE already set above)
log "=== AI Quickstart - Minstral LLM Deployment Started ==="
log "Script: ${SCRIPT_DIR}/deploy-full.sh"
log "Working directory: ${PROJECT_ROOT}"

# Get parameters (if provided) or prompt interactively
# Check if running interactively at script level (before command substitution)
IS_INTERACTIVE=false
if [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then
    IS_INTERACTIVE=true
fi

# Get parameters or use defaults
if [ -n "${1:-}" ]; then
    # Parameter provided - validate and use it
    INSTANCE_TYPE=$(prompt_instance_size "${1:-}")
elif [ "${IS_INTERACTIVE}" = "true" ]; then
    # Interactive mode - prompt user
    echo -e "${CYAN}=== AI Quickstart - Minstral LLM Deployment Configuration ===${NC}"
    echo -e "${CYAN}📋 Log file: ${LOG_FILE}${NC}"
    echo ""
    INSTANCE_TYPE=$(prompt_instance_size "")
else
    # Non-interactive mode - use default
    echo -e "${YELLOW}Non-interactive mode: Using defaults${NC}"
    INSTANCE_TYPE="${RTX4000_INSTANCE_TYPES[0]%%:*}"
fi

if [ -n "${2:-}" ]; then
    # Parameter provided - validate and use it
    REGION=$(prompt_region "${2:-}")
elif [ "${IS_INTERACTIVE}" = "true" ]; then
    # Interactive mode - prompt user
    REGION=$(prompt_region "")
else
    # Non-interactive mode - use default
    REGION="${RTX4000_REGIONS[0]%%:*}"
fi

MODEL_ID="${3:-mistralai/Mistral-7B-Instruct-v0.3}"

# Verify cloud-init file exists
CLOUD_INIT_FILE="${PROJECT_ROOT}/cloud-init/ai-sandbox.yaml"
if [ ! -f "${CLOUD_INIT_FILE}" ]; then
    show_error "Cloud-init file not found: ${CLOUD_INIT_FILE}"
    exit 1
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     AI Quickstart - Minstral LLM - Full Deployment Workflow ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Configuration:"
echo "  Instance Type: ${INSTANCE_TYPE}"
echo "  Region: ${REGION}"
echo "  Model ID: ${MODEL_ID}"
echo "  Deployment: Cloud-init (automatic on first boot)"
echo ""

# Step 1: Create instance with cloud-init
echo -e "${GREEN}Step 1: Creating Linode GPU instance with cloud-init...${NC}"
cd "${PROJECT_ROOT}"

# Export LOG_FILE and MODEL_ID so create-instance.sh can use them
export LOG_FILE
export MODEL_ID

# Call create-instance.sh
# When called from deploy-full.sh, create-instance.sh detects non-interactive mode
# and auto-generates password (no prompt needed)
log "Calling create-instance.sh with: type=${INSTANCE_TYPE}, region=${REGION}, model=${MODEL_ID}"

# Capture stdout for parsing, stderr goes to terminal for any error messages
# Using tee to capture ALL output in the log file in real-time
INSTANCE_OUTPUT=$("${SCRIPT_DIR}/create-instance.sh" "${INSTANCE_TYPE}" "${REGION}" "" "" "${MODEL_ID}" 2>&1 | tee -a "${LOG_FILE}")
CREATE_EXIT_CODE=$?

# Log the output for debugging
log "create-instance.sh exit code: ${CREATE_EXIT_CODE}"
log "create-instance.sh full output: ${INSTANCE_OUTPUT}"

# Check if create-instance.sh failed
if [ ${CREATE_EXIT_CODE} -ne 0 ]; then
    show_error "Failed to create instance" "${INSTANCE_OUTPUT}"
    exit 1
fi

# Extract instance ID from output (macOS-compatible grep)
INSTANCE_ID=$(echo "${INSTANCE_OUTPUT}" | grep -oE 'Instance ID: [0-9]+' | grep -oE '[0-9]+' | head -1 || echo "")

if [ -z "${INSTANCE_ID}" ]; then
    show_error "Failed to parse instance ID from create-instance.sh output" "Output was: ${INSTANCE_OUTPUT}"
    exit 1
fi

log "Instance created successfully: ${INSTANCE_ID}"

echo -e "${GREEN}✓ Instance created: ${INSTANCE_ID}${NC}"
echo -e "${CYAN}Cloud-init will automatically deploy services on first boot${NC}"
echo ""

# Get instance IP from the info file
INSTANCE_INFO_FILE=".instance-info-${INSTANCE_ID}.json"

# Validate instance info file was created
if [ ! -f "${INSTANCE_INFO_FILE}" ]; then
    log "WARNING: Instance info file not found: ${INSTANCE_INFO_FILE}"
    echo -e "${YELLOW}⚠️  Warning: Instance info file not created${NC}" >&2
    echo "Attempting to create it manually..." >&2

    # Try to create it manually using linode-cli
    if command -v linode-cli &> /dev/null; then
        INSTANCE_DATA=$(linode-cli linodes view "${INSTANCE_ID}" --json 2>&1)
        if [ $? -eq 0 ]; then
            INSTANCE_IP_TEMP=$(echo "${INSTANCE_DATA}" | jq -r '.[0].ipv4[0]' 2>/dev/null || echo "")
            cat > "${INSTANCE_INFO_FILE}" <<EOF
{
  "instance_id": "${INSTANCE_ID}",
  "instance_ip": "${INSTANCE_IP_TEMP}",
  "instance_type": "${INSTANCE_TYPE}",
  "region": "${REGION}",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "created_by": "deploy-full.sh"
}
EOF
            log "Manually created instance info file: ${INSTANCE_INFO_FILE}"
        else
            show_error "Failed to retrieve instance data from Linode API" "${INSTANCE_DATA}"
            exit 1
        fi
    else
        show_error "Cannot create instance info file: linode-cli not available"
        exit 1
    fi
else
    log "Instance info file found: ${INSTANCE_INFO_FILE}"
fi

# Post-creation validation: Verify instance actually exists via API
echo "Verifying instance exists via Linode API..."
log "Verifying instance ${INSTANCE_ID} exists"
if command -v linode-cli &> /dev/null; then
    VERIFY_OUTPUT=$(linode-cli linodes view "${INSTANCE_ID}" --json 2>&1)
    VERIFY_EXIT_CODE=$?

    if [ ${VERIFY_EXIT_CODE} -ne 0 ]; then
        log "ERROR: Failed to verify instance ${INSTANCE_ID} via API"
        log "ERROR: API output: ${VERIFY_OUTPUT}"
        show_error "Instance verification failed" "The instance ID ${INSTANCE_ID} could not be found via Linode API. It may have failed to create properly."
        exit 1
    fi

    # Check instance status
    INSTANCE_STATUS=$(echo "${VERIFY_OUTPUT}" | jq -r '.[0].status' 2>/dev/null || echo "unknown")
    log "Instance status: ${INSTANCE_STATUS}"
    echo -e "${GREEN}✓ Instance verified: status=${INSTANCE_STATUS}${NC}"
else
    log "WARNING: Cannot verify instance (linode-cli not available)"
    echo -e "${YELLOW}⚠️  Skipping instance verification (linode-cli not available)${NC}"
fi

if [ -f "${INSTANCE_INFO_FILE}" ]; then
    INSTANCE_IP=$(jq -r '.instance_ip' "${INSTANCE_INFO_FILE}" 2>/dev/null || echo "")
    if [ -z "${INSTANCE_IP}" ] || [ "${INSTANCE_IP}" = "null" ]; then
        log "WARNING: Could not parse IP from ${INSTANCE_INFO_FILE}, trying linode-cli"
        INSTANCE_IP=""
    fi
fi

# Fallback: get IP from linode-cli if not found in file
if [ -z "${INSTANCE_IP}" ]; then
    if command -v linode-cli &> /dev/null; then
        log "Getting instance IP from linode-cli"
        INSTANCE_IP=$(linode-cli linodes view "${INSTANCE_ID}" --json 2>/dev/null | jq -r '.[0].ipv4[0]' 2>/dev/null || echo "")
        if [ -z "${INSTANCE_IP}" ] || [ "${INSTANCE_IP}" = "null" ]; then
            show_error "Cannot determine instance IP" "Instance ID: ${INSTANCE_ID}. Try: linode-cli linodes view ${INSTANCE_ID}"
            exit 1
        fi
    else
        show_error "Cannot determine instance IP" "jq failed and linode-cli not available"
        exit 1
    fi
fi

log "Instance IP: ${INSTANCE_IP}"

# Step 2: Wait for cloud-init to complete and services to start
echo -e "${GREEN}Step 2: Waiting for cloud-init deployment to complete...${NC}"
echo "Cloud-init is running automatically on first boot."
echo "This may take 3-5 minutes..."
log "Waiting for cloud-init deployment on instance ${INSTANCE_ID}"

# Wait for SSH to be available first
echo "Waiting for SSH to be available..."
SSH_READY=false
for i in {1..60}; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes root@"${INSTANCE_IP}" "echo 'SSH ready'" 2>/dev/null; then
        SSH_READY=true
        echo -e "${GREEN}✓ SSH connection established${NC}"
        break
    fi
    if [ $((i % 10)) -eq 0 ]; then
        echo "  Still waiting for SSH... (${i}/60 attempts)"
    fi
    sleep 5
done

if [ "${SSH_READY}" = "false" ]; then
    echo -e "${YELLOW}⚠️  Warning: SSH not ready yet, but continuing...${NC}" >&2
    echo "Cloud-init may still be running. Services will start automatically." >&2
fi

# Wait additional time for cloud-init to complete deployment
echo "Waiting for services to initialize (this may take 3-5 minutes)..."
sleep 120

# Step 3: Validate deployment
echo -e "${GREEN}Step 3: Validating deployment...${NC}"
log "Validating services on instance ${INSTANCE_IP}"
if ! "${SCRIPT_DIR}/validate-services.sh" "${INSTANCE_IP}" 2>&1 | tee -a "${LOG_FILE}"; then
    echo -e "${YELLOW}⚠️  Warning: Some services may not be ready yet${NC}" >&2
    echo "Wait a few more minutes and run validation again:" >&2
    echo "  ./scripts/validate-services.sh ${INSTANCE_IP}" >&2
    log "WARNING: Service validation failed or services not ready"
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Deployment Complete!                        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Instance Information:"
echo "  Instance ID: ${INSTANCE_ID}"
echo "  Instance IP: ${INSTANCE_IP}"
echo "  Model: ${MODEL_ID}"
echo ""
echo "Access Your Services:"
echo "  Chat UI: http://${INSTANCE_IP}:3000"
echo "  API: http://${INSTANCE_IP}:8000/v1"
echo ""
echo "SSH Access:"
echo "  ssh root@${INSTANCE_IP}"
echo ""
echo "Monitor Deployment:"
echo "  ssh root@${INSTANCE_IP} 'tail -f /var/log/cloud-init-output.log'"
echo "  ssh root@${INSTANCE_IP} 'tail -f /var/log/ai-sandbox/deployment.log'"
echo ""
# Extract and display root password
if [ -f "${INSTANCE_INFO_FILE}" ]; then
    ROOT_PASS=$(jq -r '.root_password' "${INSTANCE_INFO_FILE}" 2>/dev/null || echo "")
    if [ -n "${ROOT_PASS}" ] && [ "${ROOT_PASS}" != "null" ]; then
        echo -e "${YELLOW}Root Password:${NC}"
        echo "  ${ROOT_PASS}"
        echo ""
    fi
fi
echo "Instance info saved to: ${INSTANCE_INFO_FILE}"
echo ""
echo -e "${YELLOW}⚠️  Remember to configure firewall rules to protect your services!${NC}"
echo ""
echo -e "${CYAN}📋 Deployment log: ${LOG_FILE}${NC}"
echo -e "${CYAN}   View with: tail -f ${LOG_FILE}${NC}"
log "Deployment completed successfully. Instance: ${INSTANCE_ID}, IP: ${INSTANCE_IP}"

