# PowerShell script to check prerequisites for Windows deployment
# Purpose: Validates that all required tools and dependencies are installed
# Usage: .\check-prerequisites.ps1

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Success { param($msg) Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "✗ $msg" -ForegroundColor Red }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$Errors = 0

Write-Host "Checking prerequisites for AI Quickstart - Mistral LLM deployment..." -ForegroundColor Cyan
Write-Host ""

# Check Python (required for linode-cli)
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonVersion = python --version 2>&1
    Write-Success "Python is installed"
    Write-Host "  Version: $pythonVersion"
} elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    $pythonVersion = python3 --version 2>&1
    Write-Success "Python3 is installed"
    Write-Host "  Version: $pythonVersion"
} else {
    Write-Error "Python is not installed"
    Write-Host "  Install from: https://www.python.org/downloads/"
    $Errors++
}

# Check linode-cli
if (Get-Command linode-cli -ErrorAction SilentlyContinue) {
    Write-Success "linode-cli is installed"
    $linodeVersion = linode-cli --version 2>&1
    Write-Host "  Version: $linodeVersion"
    
    # Check if configured
    try {
        $null = linode-cli profile view 2>&1
        Write-Success "linode-cli is configured"
        
        # Test API connectivity
        Write-Host "  Testing API connectivity..."
        try {
            $null = linode-cli regions list --json 2>&1
            Write-Success "API connectivity verified"
            
            # Check GPU instance availability
            $gpuTypes = linode-cli linodes types --json 2>&1 | ConvertFrom-Json | Where-Object { $_.id -like "g2-gpu*" }
            if ($gpuTypes) {
                Write-Success "GPU instance types accessible"
            } else {
                Write-Warning "Cannot find GPU instance types (may not have access)"
            }
        } catch {
            Write-Warning "API connectivity test failed"
            Write-Host "  Check your API token permissions"
        }
    } catch {
        Write-Warning "linode-cli is not configured"
        Write-Host "  Run: linode-cli configure"
        $Errors++
    }
} else {
    Write-Error "linode-cli is not installed"
    Write-Host "  Install with: pip install linode-cli"
    Write-Host "  Or: python -m pip install linode-cli"
    $Errors++
}

# Check jq (optional but recommended)
if (Get-Command jq -ErrorAction SilentlyContinue) {
    Write-Success "jq is installed"
} else {
    Write-Warning "jq is not installed (optional but recommended for JSON parsing)"
    Write-Host "  Install with: winget install jqlang.jq"
    Write-Host "  Or download from: https://github.com/jqlang/jq/releases"
    Write-Host "  Note: PowerShell can parse JSON natively, but jq is useful for complex parsing"
}

# Check SSH (optional but recommended)
$sshKeyFound = $false
$sshPaths = @(
    "$env:USERPROFILE\.ssh\id_rsa.pub",
    "$env:USERPROFILE\.ssh\id_ed25519.pub",
    "$env:USERPROFILE\.ssh\id_ecdsa.pub"
)

foreach ($keyPath in $sshPaths) {
    if (Test-Path $keyPath) {
        Write-Success "SSH public key found: $keyPath"
        $sshKeyFound = $true
        break
    }
}

if (-not $sshKeyFound) {
    Write-Warning "SSH public key not found (optional - password auth will be used)"
    Write-Host "  To enable key-based auth, generate with: ssh-keygen -t ed25519"
}

# Check cloud-init file
$cloudInitFile = Join-Path $ProjectRoot "cloud-init\ai-sandbox.yaml"
if (Test-Path $cloudInitFile) {
    Write-Success "Cloud-init file found: cloud-init\ai-sandbox.yaml"
} else {
    Write-Error "Cloud-init file not found: cloud-init\ai-sandbox.yaml"
    $Errors++
}

# Check Docker Compose template
$dockerComposeFile = Join-Path $ProjectRoot "docker\docker-compose.yml.template"
if (Test-Path $dockerComposeFile) {
    Write-Success "Docker Compose template found: docker\docker-compose.yml.template"
} else {
    Write-Warning "Docker Compose template not found (will use inline generation)"
}

Write-Host ""
if ($Errors -eq 0) {
    Write-Success "All critical prerequisites met!"
    Write-Host ""
    Write-Host "You can now run:"
    Write-Host "  .\scripts\deploy-full.ps1" -ForegroundColor Cyan
    exit 0
} else {
    Write-Error "Some prerequisites are missing"
    Write-Host "Please install missing tools before proceeding"
    exit 1
}

