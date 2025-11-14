# PowerShell script for end-to-end deployment workflow
# Purpose: Creates a Linode GPU instance with cloud-init and validates deployment
# Usage: .\deploy-full.ps1 [instance-type] [region] [model-id]

param(
    [string]$InstanceType = "",
    [string]$Region = "",
    [string]$ModelId = "mistralai/Mistral-7B-Instruct-v0.3"
)

$ErrorActionPreference = "Stop"

# Determine script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$LogDir = Join-Path $ProjectRoot "logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = Join-Path $LogDir "deploy-$timestamp.log"

# RTX4000 Configuration
$RTX4000Regions = @(
    @{Id="us-ord"; Label="Chicago, US"},
    @{Id="de-fra-2"; Label="Frankfurt 2, DE"},
    @{Id="jp-osa"; Label="Osaka, JP"},
    @{Id="fr-par"; Label="Paris, FR"},
    @{Id="us-sea"; Label="Seattle, WA, US"},
    @{Id="sg-sin-2"; Label="Singapore 2, SG"}
)

$RTX4000InstanceTypes = @(
    @{Id="g2-gpu-rtx4000a1-s"; Label="RTX4000 Ada x1 Small - $350/month"},
    @{Id="g2-gpu-rtx4000a1-m"; Label="RTX4000 Ada x1 Medium - $446/month"},
    @{Id="g2-gpu-rtx4000a1-l"; Label="RTX4000 Ada x1 Large - $638/month"},
    @{Id="g2-gpu-rtx4000a1-xl"; Label="RTX4000 Ada x1 X-Large - $1022/month"},
    @{Id="g2-gpu-rtx4000a2-s"; Label="RTX4000 Ada x2 Small - $700/month"},
    @{Id="g2-gpu-rtx4000a2-m"; Label="RTX4000 Ada x2 Medium - $892/month"},
    @{Id="g2-gpu-rtx4000a2-hs"; Label="RTX4000 Ada x2 Medium High Storage - $992/month"},
    @{Id="g2-gpu-rtx4000a4-s"; Label="RTX4000 Ada x4 Small - $1976/month"},
    @{Id="g2-gpu-rtx4000a4-m"; Label="RTX4000 Ada x4 Medium - $2384/month"}
)

function Write-Success { param($msg) Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "✗ $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host $msg -ForegroundColor Cyan }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $Message" | Add-Content -Path $LogFile
}

function Show-Error {
    param([string]$Message, [string]$Details = "")
    Write-Log "ERROR: $Message"
    if ($Details) {
        Write-Log "ERROR DETAILS: $Details"
    }
    Write-Error $Message
    if ($Details) {
        Write-Host $Details
    }
    Write-Warning "Check log file for details: $LogFile"
}

function Prompt-Region {
    param([string]$ProvidedRegion)
    
    if ($ProvidedRegion) {
        $valid = $RTX4000Regions | Where-Object { $_.Id -eq $ProvidedRegion }
        if ($valid) {
            return $ProvidedRegion
        } else {
            Write-Warning "Invalid region '$ProvidedRegion'. Showing options..."
        }
    }
    
    Write-Host ""
    Write-Info "Select Region (RTX4000 available regions):"
    $index = 1
    foreach ($region in $RTX4000Regions) {
        Write-Host "  $index) $($region.Label) ($($region.Id))"
        $index++
    }
    
    while ($true) {
        $choice = Read-Host "Enter choice [1-$($RTX4000Regions.Count)]"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $RTX4000Regions.Count) {
            return $RTX4000Regions[[int]$choice - 1].Id
        } elseif ([string]::IsNullOrWhiteSpace($choice)) {
            Write-Warning "No input provided. Using default region."
            return $RTX4000Regions[0].Id
        } else {
            Write-Error "Invalid choice. Please enter a number between 1 and $($RTX4000Regions.Count)."
        }
    }
}

function Prompt-InstanceSize {
    param([string]$ProvidedSize)
    
    if ($ProvidedSize) {
        $valid = $RTX4000InstanceTypes | Where-Object { $_.Id -eq $ProvidedSize }
        if ($valid) {
            return $ProvidedSize
        } else {
            Write-Warning "Invalid instance type '$ProvidedSize'. Showing options..."
        }
    }
    
    Write-Host ""
    Write-Info "Select Instance Size (RTX4000):"
    $index = 1
    foreach ($size in $RTX4000InstanceTypes) {
        Write-Host "  $index) $($size.Label) ($($size.Id))"
        $index++
    }
    
    while ($true) {
        $choice = Read-Host "Enter choice [1-$($RTX4000InstanceTypes.Count)]"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $RTX4000InstanceTypes.Count) {
            return $RTX4000InstanceTypes[[int]$choice - 1].Id
        } elseif ([string]::IsNullOrWhiteSpace($choice)) {
            Write-Warning "No input provided. Using default instance type."
            return $RTX4000InstanceTypes[0].Id
        } else {
            Write-Error "Invalid choice. Please enter a number between 1 and $($RTX4000InstanceTypes.Count)."
        }
    }
}

# Initialize logging
Write-Log "=== AI Quickstart - Mistral LLM Deployment Started ==="
Write-Log "Script: $ScriptDir\deploy-full.ps1"
Write-Log "Working directory: $ProjectRoot"

# Get parameters or use defaults
$isInteractive = [System.Console]::IsInputRedirected -eq $false -and [System.Console]::IsOutputRedirected -eq $false

if ($InstanceType) {
    $InstanceType = Prompt-InstanceSize $InstanceType
} elseif ($isInteractive) {
    Write-Info "=== AI Quickstart - Mistral LLM Deployment Configuration ==="
    Write-Info "📋 Log file: $LogFile"
    Write-Host ""
    $InstanceType = Prompt-InstanceSize
} else {
    Write-Warning "Non-interactive mode: Using defaults"
    $InstanceType = $RTX4000InstanceTypes[0].Id
}

if ($Region) {
    $Region = Prompt-Region $Region
} elseif ($isInteractive) {
    $Region = Prompt-Region
} else {
    $Region = $RTX4000Regions[0].Id
}

# Verify cloud-init file exists
$cloudInitFile = Join-Path $ProjectRoot "cloud-init\ai-sandbox.yaml"
if (-not (Test-Path $cloudInitFile)) {
    Show-Error "Cloud-init file not found: $cloudInitFile"
    exit 1
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║     AI Quickstart - Mistral LLM - Full Deployment Workflow ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""
Write-Host "Configuration:"
Write-Host "  Instance Type: $InstanceType"
Write-Host "  Region: $Region"
Write-Host "  Model ID: $ModelId"
Write-Host "  Deployment: Cloud-init (automatic on first boot)"
Write-Host ""

# Step 1: Create instance with cloud-init
Write-Success "Step 1: Creating Linode GPU instance with cloud-init..."
Set-Location $ProjectRoot

Write-Log "Calling create-instance.ps1 with: type=$InstanceType, region=$Region, model=$ModelId"

try {
    $instanceOutput = & "$ScriptDir\create-instance.ps1" -InstanceType $InstanceType -Region $Region -ModelId $ModelId 2>&1 | Tee-Object -FilePath $LogFile -Append
    $createExitCode = $LASTEXITCODE
    
    Write-Log "create-instance.ps1 exit code: $createExitCode"
    Write-Log "create-instance.ps1 full output: $instanceOutput"
    
    if ($createExitCode -ne 0) {
        Show-Error "Failed to create instance" $instanceOutput
        exit 1
    }
    
    # Extract instance ID from output
    $instanceIdMatch = [regex]::Match($instanceOutput, 'Instance ID: (\d+)')
    if ($instanceIdMatch.Success) {
        $instanceId = $instanceIdMatch.Groups[1].Value
    } else {
        Show-Error "Failed to parse instance ID from create-instance.ps1 output" "Output was: $instanceOutput"
        exit 1
    }
    
    Write-Log "Instance created successfully: $instanceId"
    Write-Success "Instance created: $instanceId"
    Write-Info "Cloud-init will automatically deploy services on first boot"
    Write-Host ""
    
    # Get instance IP from the info file
    $instanceInfoFile = ".instance-info-$instanceId.json"
    
    if (-not (Test-Path $instanceInfoFile)) {
        Write-Log "WARNING: Instance info file not found: $instanceInfoFile"
        Write-Warning "⚠️  Warning: Instance info file not created"
        Write-Host "Attempting to create it manually..."
        
        try {
            $instanceData = linode-cli linodes view $instanceId --json 2>&1 | ConvertFrom-Json
            $instanceIp = $instanceData[0].ipv4[0]
            
            $instanceInfo = @{
                instance_id = $instanceId
                instance_ip = $instanceIp
                instance_type = $InstanceType
                region = $Region
                created_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                created_by = "deploy-full.ps1"
            } | ConvertTo-Json
            
            Set-Content -Path $instanceInfoFile -Value $instanceInfo
            Write-Log "Manually created instance info file: $instanceInfoFile"
        } catch {
            Show-Error "Failed to retrieve instance data from Linode API" $_.Exception.Message
            exit 1
        }
    } else {
        Write-Log "Instance info file found: $instanceInfoFile"
    }
    
    # Verify instance exists via API
    Write-Host "Verifying instance exists via Linode API..."
    Write-Log "Verifying instance $instanceId exists"
    
    try {
        $verifyOutput = linode-cli linodes view $instanceId --json 2>&1 | ConvertFrom-Json
        $instanceStatus = $verifyOutput[0].status
        Write-Log "Instance status: $instanceStatus"
        Write-Success "Instance verified: status=$instanceStatus"
    } catch {
        Write-Log "WARNING: Cannot verify instance (linode-cli not available or error)"
        Write-Warning "⚠️  Skipping instance verification"
    }
    
    # Get instance IP
    if (Test-Path $instanceInfoFile) {
        $instanceInfo = Get-Content $instanceInfoFile | ConvertFrom-Json
        $instanceIp = $instanceInfo.instance_ip
    }
    
    if (-not $instanceIp -or $instanceIp -eq "null") {
        try {
            $instanceData = linode-cli linodes view $instanceId --json 2>&1 | ConvertFrom-Json
            $instanceIp = $instanceData[0].ipv4[0]
        } catch {
            Show-Error "Cannot determine instance IP" "Instance ID: $instanceId"
            exit 1
        }
    }
    
    Write-Log "Instance IP: $instanceIp"
    
    # Step 2: Wait for cloud-init to complete
    Write-Success "Step 2: Waiting for cloud-init deployment to complete..."
    Write-Host "Cloud-init is running automatically on first boot."
    Write-Host "This may take 3-5 minutes..."
    Write-Log "Waiting for cloud-init deployment on instance $instanceId"
    
    # Wait for SSH to be available
    Write-Host "Waiting for SSH to be available..."
    $sshReady = $false
    for ($i = 1; $i -le 60; $i++) {
        try {
            $null = ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes "root@$instanceIp" "echo 'SSH ready'" 2>&1
            $sshReady = $true
            Write-Success "SSH connection established"
            break
        } catch {
            if ($i % 10 -eq 0) {
                Write-Host "  Still waiting for SSH... ($i/60 attempts)"
            }
            Start-Sleep -Seconds 5
        }
    }
    
    if (-not $sshReady) {
        Write-Warning "⚠️  Warning: SSH not ready yet, but continuing..."
        Write-Host "Cloud-init may still be running. Services will start automatically."
    }
    
    # Wait additional time for cloud-init to complete
    Write-Host "Waiting for services to initialize (this may take 3-5 minutes)..."
    Start-Sleep -Seconds 120
    
    # Step 3: Validate deployment
    Write-Success "Step 3: Validating deployment..."
    Write-Log "Validating services on instance $instanceIp"
    
    try {
        & "$ScriptDir\validate-services.ps1" $instanceIp 2>&1 | Tee-Object -FilePath $LogFile -Append
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "⚠️  Warning: Some services may not be ready yet"
            Write-Host "Wait a few more minutes and run validation again:"
            Write-Host "  .\scripts\validate-services.ps1 $instanceIp"
            Write-Log "WARNING: Service validation failed or services not ready"
        }
    } catch {
        Write-Warning "⚠️  Warning: Validation script encountered an error"
        Write-Log "WARNING: Validation error: $($_.Exception.Message)"
    }
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║              Deployment Complete!                        ║" -ForegroundColor Blue
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Instance Information:"
    Write-Host "  Instance ID: $instanceId"
    Write-Host "  Instance IP: $instanceIp"
    Write-Host "  Model: $ModelId"
    Write-Host ""
    Write-Host "Access Your Services:"
    Write-Host "  Chat UI: http://$instanceIp`:3000"
    Write-Host "  API: http://$instanceIp`:8000/v1"
    Write-Host ""
    Write-Host "SSH Access:"
    Write-Host "  ssh root@$instanceIp"
    Write-Host ""
    Write-Host "Monitor Deployment:"
    Write-Host "  ssh root@$instanceIp 'tail -f /var/log/cloud-init-output.log'"
    Write-Host "  ssh root@$instanceIp 'tail -f /var/log/ai-sandbox/deployment.log'"
    Write-Host ""
    
    # Extract and display root password
    if (Test-Path $instanceInfoFile) {
        $instanceInfo = Get-Content $instanceInfoFile | ConvertFrom-Json
        $rootPass = $instanceInfo.root_password
        if ($rootPass -and $rootPass -ne "null") {
            Write-Host "Root Password:" -ForegroundColor Yellow
            Write-Host "  $rootPass"
            Write-Host ""
        }
    }
    
    Write-Host "Instance info saved to: $instanceInfoFile"
    Write-Host ""
    Write-Warning "⚠️  Remember to configure firewall rules to protect your services!"
    Write-Host ""
    Write-Info "📋 Deployment log: $LogFile"
    Write-Info "   View with: Get-Content $LogFile -Wait"
    Write-Log "Deployment completed successfully. Instance: $instanceId, IP: $instanceIp"
    
} catch {
    Show-Error "Deployment failed" $_.Exception.Message
    exit 1
}

