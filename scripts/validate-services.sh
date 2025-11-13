#!/bin/bash
#
# Purpose:
#   Validates that AI Quickstart - Minstral LLM services (API and UI) are running and accessible
#   after deployment. Checks SSH connectivity, Docker Compose service status,
#   port accessibility, and endpoint responses. Provides comprehensive validation
#   report for deployment verification.
#
#   Why it exists: Enables automated verification of deployment success. Helps
#   identify issues early and confirms services are ready for use. Critical for
#   testing and demonstration workflows.
#
# Dependencies:
#   - SSH access: Must have SSH key or password access to the instance
#   - curl: For testing HTTP endpoints (usually pre-installed)
#   - jq: For parsing Docker Compose JSON output (optional but recommended)
#   - bash: With /dev/tcp support for port checking (standard on Linux/macOS)
#   - Instance must have completed cloud-init deployment
#
# Troubleshooting:
#   - "Cannot connect via SSH": Verify instance is running, check firewall rules
#   - "Services not running": Wait longer (3-5 minutes), check deployment logs
#   - "Ports not accessible": Check firewall rules, verify services started correctly
#   - "API/UI not responding": Services may still be initializing, wait and retry
#   - False negatives: Services may be starting, re-run validation after waiting
#   - Check deployment logs: ssh root@<ip> 'tail -f /var/log/cloud-init-output.log'
#   - Check deployment logs: ssh root@<ip> 'tail -f /var/log/ai-sandbox/deployment.log'
#
# Specification Links:
#   - Feature Spec: specs/001-ai-sandbox/spec.md (Success Criteria SC-001, SC-004)
#   - Tasks: specs/001-ai-sandbox/tasks.md (Phase 3, T045)
#   - API Contract: specs/001-ai-sandbox/contracts/openai-api-v1.md
#
# Usage: ./validate-services.sh <instance-ip>

set -euo pipefail

INSTANCE_IP="${1:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "${INSTANCE_IP}" ]; then
    echo -e "${RED}Error: Instance IP required${NC}"
    echo "Usage: $0 <instance-ip>"
    exit 1
fi

echo -e "${GREEN}Validating AI Quickstart - Minstral LLM services on ${INSTANCE_IP}...${NC}"
echo ""

# Check SSH connectivity
if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"${INSTANCE_IP}" "echo 'Connected'" &>/dev/null; then
    echo -e "${RED}✗ Cannot connect to instance via SSH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ SSH connection successful${NC}"

# Check if cloud-init deployment has run
if ssh root@"${INSTANCE_IP}" "[ -f /opt/ai-sandbox/docker-compose.yml ]" 2>/dev/null; then
    echo -e "${GREEN}✓ Docker Compose configuration found${NC}"
else
    echo -e "${YELLOW}⚠ Cloud-init deployment may not have completed yet${NC}"
fi

# Check if Docker Compose services are running
SERVICES_STATUS=$(ssh root@"${INSTANCE_IP}" "cd /opt/ai-sandbox && docker-compose ps --format json" 2>/dev/null || echo "[]")

if [ -z "${SERVICES_STATUS}" ] || [ "${SERVICES_STATUS}" = "[]" ]; then
    echo -e "${YELLOW}⚠ Docker Compose services not found or not running${NC}"
else
    API_RUNNING=$(echo "${SERVICES_STATUS}" | jq -r '.[] | select(.Service=="api") | .State' 2>/dev/null || echo "")
    UI_RUNNING=$(echo "${SERVICES_STATUS}" | jq -r '.[] | select(.Service=="ui") | .State' 2>/dev/null || echo "")
    
    if [ "${API_RUNNING}" = "running" ]; then
        echo -e "${GREEN}✓ API service (vLLM) is running${NC}"
    else
        echo -e "${YELLOW}⚠ API service (vLLM) is not running (State: ${API_RUNNING})${NC}"
    fi
    
    if [ "${UI_RUNNING}" = "running" ]; then
        echo -e "${GREEN}✓ UI service (Open WebUI) is running${NC}"
    else
        echo -e "${YELLOW}⚠ UI service (Open WebUI) is not running (State: ${UI_RUNNING})${NC}"
    fi
fi

# Check port accessibility
echo ""
echo "Checking service accessibility..."

# Check API endpoint (port 8000)
if timeout 5 bash -c "echo > /dev/tcp/${INSTANCE_IP}/8000" 2>/dev/null; then
    echo -e "${GREEN}✓ API endpoint (port 8000) is accessible${NC}"
    
    # Test API endpoint with curl
    API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://${INSTANCE_IP}:8000/health" 2>/dev/null || echo "000")
    if [ "${API_RESPONSE}" = "200" ] || [ "${API_RESPONSE}" = "000" ]; then
        echo -e "${GREEN}✓ API health check endpoint responding${NC}"
    else
        echo -e "${YELLOW}⚠ API health check returned: ${API_RESPONSE}${NC}"
    fi
else
    echo -e "${YELLOW}⚠ API endpoint (port 8000) is not accessible${NC}"
fi

# Check UI endpoint (port 3000)
if timeout 5 bash -c "echo > /dev/tcp/${INSTANCE_IP}/3000" 2>/dev/null; then
    echo -e "${GREEN}✓ UI endpoint (port 3000) is accessible${NC}"
    
    # Test UI endpoint
    UI_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://${INSTANCE_IP}:3000" 2>/dev/null || echo "000")
    if [ "${UI_RESPONSE}" = "200" ] || [ "${UI_RESPONSE}" = "302" ]; then
        echo -e "${GREEN}✓ UI web interface responding${NC}"
    else
        echo -e "${YELLOW}⚠ UI web interface returned: ${UI_RESPONSE}${NC}"
    fi
else
    echo -e "${YELLOW}⚠ UI endpoint (port 3000) is not accessible${NC}"
fi

# Check /etc/motd for deployment status
echo ""
echo "Deployment Status (from /etc/motd):"
MOTD_CONTENT=$(ssh root@"${INSTANCE_IP}" "cat /etc/motd" 2>/dev/null || echo "")
if echo "${MOTD_CONTENT}" | grep -q "Deployment Complete"; then
    echo -e "${GREEN}✓ Deployment marked as complete in /etc/motd${NC}"
elif echo "${MOTD_CONTENT}" | grep -q "ERROR"; then
    echo -e "${RED}✗ Deployment error detected in /etc/motd${NC}"
    echo "${MOTD_CONTENT}"
else
    echo -e "${YELLOW}⚠ Deployment status unclear${NC}"
fi

echo ""
echo "Summary:"
echo "  Chat UI: http://${INSTANCE_IP}:3000"
echo "  API: http://${INSTANCE_IP}:8000/v1"
echo ""
echo "For detailed logs:"
echo "  ssh root@${INSTANCE_IP} 'tail -f /var/log/ai-sandbox/deployment.log'"

