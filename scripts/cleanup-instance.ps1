# PowerShell script to delete a Linode instance
# Purpose: Safely removes test instances and cleans up associated files
# Usage: .\cleanup-instance.ps1 <instance-id> [-Force]

param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceId,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Success { param($msg) Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "✗ $msg" -ForegroundColor Red }

# Check if linode-cli is installed
if (-not (Get-Command linode-cli -ErrorAction SilentlyContinue)) {
    Write-Error "linode-cli is not installed"
    exit 1
}

# Get instance info
try {
    $instanceInfo = linode-cli linodes view $InstanceId --json 2>&1 | ConvertFrom-Json
    
    if (-not $instanceInfo -or $instanceInfo.Count -eq 0) {
        Write-Error "Instance $InstanceId not found"
        exit 1
    }
    
    $instanceLabel = $instanceInfo[0].label
    $instanceIp = $instanceInfo[0].ipv4[0]
    
    Write-Warning "Warning: This will delete the Linode instance!"
    Write-Host ""
    Write-Host "Instance Details:"
    Write-Host "  ID: $InstanceId"
    Write-Host "  Label: $instanceLabel"
    Write-Host "  IP: $instanceIp"
    Write-Host ""
    
    if (-not $Force) {
        $confirm = Read-Host "Are you sure you want to delete this instance? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Host "Cancelled."
            exit 0
        }
    }
    
    Write-Host "Deleting instance $InstanceId..."
    
    try {
        linode-cli linodes delete $InstanceId 2>&1 | Out-Null
        Write-Success "Instance deleted successfully"
        
        # Clean up instance info file if it exists
        $instanceInfoFile = ".instance-info-$InstanceId.json"
        if (Test-Path $instanceInfoFile) {
            Remove-Item $instanceInfoFile -Force
            Write-Host "Cleaned up instance info file"
        }
    } catch {
        Write-Error "Failed to delete instance"
        Write-Host $_.Exception.Message
        exit 1
    }
    
} catch {
    Write-Error "Failed to retrieve instance information"
    Write-Host $_.Exception.Message
    exit 1
}

