# PowerShell script to create a Linode GPU instance
# Purpose: Creates a new Linode GPU instance via Linode CLI for AI Quickstart deployment
# Usage: .\create-instance.ps1 [instance-type] [region] [root-password] [label] [model-id]

param(
    [string]$InstanceType = "",
    [string]$Region = "",
    [string]$RootPassword = "",
    [string]$Label = "",
    [string]$ModelId = "mistralai/Mistral-7B-Instruct-v0.3"
)

$ErrorActionPreference = "Stop"

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
        } else {
            Write-Error "Invalid choice. Please enter a number between 1 and $($RTX4000InstanceTypes.Count)."
        }
    }
}

function Generate-Password {
    $upperChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lowerChars = "abcdefghijklmnopqrstuvwxyz"
    $numbers = "0123456789"
    $specialChars = "!@#$&*-_"
    
    $random = New-Object System.Random
    
    # Generate at least 3 of each type
    $upperPart = -join (1..3 | ForEach-Object { $upperChars[$random.Next($upperChars.Length)] })
    $lowerPart = -join (1..3 | ForEach-Object { $lowerChars[$random.Next($lowerChars.Length)] })
    $numberPart = -join (1..3 | ForEach-Object { $numbers[$random.Next($numbers.Length)] })
    $specialPart = -join (1..3 | ForEach-Object { $specialChars[$random.Next($specialChars.Length)] })
    
    # Add more random characters
    $allChars = $upperChars + $lowerChars + $numbers + $specialChars
    $randomPart = -join (1..12 | ForEach-Object { $allChars[$random.Next($allChars.Length)] })
    
    return $upperPart + $lowerPart + $numberPart + $specialPart + $randomPart
}

# Get parameters or prompt
$InstanceType = if ($InstanceType) { Prompt-InstanceSize $InstanceType } else { Prompt-InstanceSize }
$Region = if ($Region) { Prompt-Region $Region } else { Prompt-Region }

# Handle password
$PasswordWasGenerated = $false
if ($RootPassword) {
    $PasswordWasGenerated = $false
} elseif ([System.Console]::IsInputRedirected -or -not [System.Console]::IsOutputRedirected) {
    # Interactive mode
    Write-Host ""
    Write-Info "Root Password (leave blank to generate random password):"
    $securePassword = Read-Host "Enter password" -AsSecureString
    $RootPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )
    
    if ([string]::IsNullOrWhiteSpace($RootPassword)) {
        $RootPassword = Generate-Password
        $PasswordWasGenerated = $true
        Write-Host ""
        Write-Warning "Generated root password: $RootPassword"
        Write-Warning "⚠️  Save this password for SSH access!"
    } else {
        Write-Host ""
        Write-Success "Using provided password"
    }
} else {
    # Non-interactive mode
    $RootPassword = Generate-Password
    $PasswordWasGenerated = $true
    Write-Host "Generated root password: $RootPassword" | Out-String
}

if ([string]::IsNullOrWhiteSpace($Label)) {
    $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $Label = "ai-quickstart-minstral-$timestamp"
}

$Image = "linode/ubuntu22.04"

# Determine script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$CloudInitFile = Join-Path $ProjectRoot "cloud-init\ai-sandbox.yaml"

# Check if cloud-init file exists
if (-not (Test-Path $CloudInitFile)) {
    Write-Error "Cloud-init file not found: $CloudInitFile"
    exit 1
}

# Read and substitute MODEL_ID placeholder
$cloudInitContent = Get-Content $CloudInitFile -Raw
$cloudInitContent = $cloudInitContent -replace "MODEL_ID_PLACEHOLDER", $ModelId

# Base64 encode the cloud-init content
$bytes = [System.Text.Encoding]::UTF8.GetBytes($cloudInitContent)
$cloudInitB64 = [Convert]::ToBase64String($bytes)

# Check if linode-cli is installed
if (-not (Get-Command linode-cli -ErrorAction SilentlyContinue)) {
    Write-Error "linode-cli is not installed"
    Write-Host "Install it with: pip install linode-cli"
    exit 1
}

# Check if linode-cli is configured
try {
    $null = linode-cli profile view 2>&1
} catch {
    Write-Warning "linode-cli may not be configured"
    Write-Host "Run: linode-cli configure"
}

# Password validation
if ($RootPassword.Length -lt 11 -or $RootPassword.Length -gt 128) {
    Write-Error "Password must be 11-128 characters long"
    exit 1
}

Write-Success "Creating Linode GPU instance..."
Write-Host "Instance Type: $InstanceType"
Write-Host "Region: $Region"
Write-Host "Label: $Label"
Write-Host ""

# Find SSH key
$sshKey = ""
$sshPaths = @(
    "$env:USERPROFILE\.ssh\id_rsa.pub",
    "$env:USERPROFILE\.ssh\id_ed25519.pub",
    "$env:USERPROFILE\.ssh\id_ecdsa.pub"
)

foreach ($keyPath in $sshPaths) {
    if (Test-Path $keyPath) {
        $sshKey = Get-Content $keyPath -Raw
        if ($sshKey) {
            Write-Host "Using SSH key: $keyPath"
            break
        }
    }
}

# Create the instance
Write-Host "Calling linode-cli to create instance..." | Out-String

$createArgs = @(
    "linodes", "create",
    "--type", $InstanceType,
    "--region", $Region,
    "--image", $Image,
    "--root_pass", $RootPassword,
    "--label", $Label,
    "--metadata.user_data", $cloudInitB64,
    "--no-defaults",
    "--json"
)

if ($sshKey) {
    $createArgs += "--authorized_keys"
    $createArgs += $sshKey.Trim()
}

try {
    $instanceJson = linode-cli @createArgs 2>&1
    $instanceData = $instanceJson | ConvertFrom-Json
    
    if (-not $instanceData -or $instanceData.Count -eq 0) {
        throw "Failed to create instance"
    }
    
    $instanceId = $instanceData[0].id
    $instanceIp = $instanceData[0].ipv4[0]
    
    if (-not $instanceId -or $instanceId -eq "null") {
        throw "Failed to parse instance ID"
    }
    
    Write-Success "Instance created successfully!"
    Write-Host ""
    Write-Host "Instance ID: $instanceId"
    Write-Host "Instance IP: $instanceIp"
    if ($PasswordWasGenerated) {
        Write-Host "Root Password: $RootPassword"
        Write-Warning "⚠️  IMPORTANT: Save this password for SSH access!"
    } else {
        Write-Host "Root Password: [provided by user]"
    }
    Write-Host "Label: $Label"
    Write-Host ""
    
    # Save instance info to file
    $instanceInfoFile = ".instance-info-$instanceId.json"
    $instanceInfo = @{
        instance_id = $instanceId
        instance_ip = $instanceIp
        instance_type = $InstanceType
        region = $Region
        label = $Label
        root_password = $RootPassword
        created_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    } | ConvertTo-Json
    
    Set-Content -Path $instanceInfoFile -Value $instanceInfo
    
    Write-Success "Instance information saved to: $instanceInfoFile"
    Write-Host ""
    Write-Host "Cloud-init configuration has been applied. The instance will automatically:"
    Write-Host "  - Install Docker and dependencies"
    Write-Host "  - Configure NVIDIA drivers"
    Write-Host "  - Deploy AI Quickstart - Mistral LLM services"
    Write-Host ""
    Write-Host "Monitor deployment:"
    Write-Host "  ssh root@$instanceIp 'tail -f /var/log/cloud-init-output.log'"
    Write-Host "  ssh root@$instanceIp 'tail -f /var/log/ai-sandbox/deployment.log'"
    Write-Host ""
    Write-Host "SSH access:"
    Write-Host "  ssh root@$instanceIp"
    
} catch {
    Write-Error "Error creating instance"
    Write-Host $_.Exception.Message
    Write-Host ""
    Write-Warning "Troubleshooting:"
    Write-Host "  1. Check your Linode API token: linode-cli profile view"
    Write-Host "  2. Verify you have access to GPU instances"
    Write-Host "  3. Check if the instance type is available in the selected region"
    Write-Host "  4. Verify your password meets requirements (11-128 chars, mixed case, numbers, special chars)"
    exit 1
}

