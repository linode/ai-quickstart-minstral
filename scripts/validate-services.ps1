# PowerShell script to validate services after deployment
# Purpose: Validates that AI Quickstart services are running and accessible
# Usage: .\validate-services.ps1 <instance-ip>

param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceIp
)

$ErrorActionPreference = "Stop"

function Write-Success { param($msg) Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "✗ $msg" -ForegroundColor Red }

Write-Success "Validating AI Quickstart - Mistral LLM services on $InstanceIp..."
Write-Host ""

# Check SSH connectivity
try {
    $null = ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "root@$InstanceIp" "echo 'Connected'" 2>&1
    Write-Success "SSH connection successful"
} catch {
    Write-Error "Cannot connect to instance via SSH"
    exit 1
}

# Check if cloud-init deployment has run
try {
    $null = ssh "root@$InstanceIp" "[ -f /opt/ai-sandbox/docker-compose.yml ]" 2>&1
    Write-Success "Docker Compose configuration found"
} catch {
    Write-Warning "Cloud-init deployment may not have completed yet"
}

# Check if Docker Compose services are running
try {
    $servicesStatus = ssh "root@$InstanceIp" "cd /opt/ai-sandbox && docker-compose ps --format json" 2>&1
    
    if ($servicesStatus) {
        $services = $servicesStatus | ConvertFrom-Json
        
        $apiRunning = ($services | Where-Object { $_.Service -eq "api" }).State
        $uiRunning = ($services | Where-Object { $_.Service -eq "ui" }).State
        
        if ($apiRunning -eq "running") {
            Write-Success "API service (vLLM) is running"
        } else {
            Write-Warning "API service (vLLM) is not running (State: $apiRunning)"
        }
        
        if ($uiRunning -eq "running") {
            Write-Success "UI service (Open WebUI) is running"
        } else {
            Write-Warning "UI service (Open WebUI) is not running (State: $uiRunning)"
        }
    } else {
        Write-Warning "Docker Compose services not found or not running"
    }
} catch {
    Write-Warning "Could not check Docker Compose services status"
}

# Check port accessibility
Write-Host ""
Write-Host "Checking service accessibility..."

# Check API endpoint (port 8000)
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $connect = $tcpClient.BeginConnect($InstanceIp, 8000, $null, $null)
    $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)
    if ($wait) {
        $tcpClient.EndConnect($connect)
        $tcpClient.Close()
        Write-Success "API endpoint (port 8000) is accessible"
        
        # Test API endpoint with Invoke-WebRequest
        try {
            $response = Invoke-WebRequest -Uri "http://${InstanceIp}:8000/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Success "API health check endpoint responding"
            } else {
                Write-Warning "API health check returned: $($response.StatusCode)"
            }
        } catch {
            Write-Warning "API health check endpoint not responding"
        }
    } else {
        Write-Warning "API endpoint (port 8000) is not accessible"
    }
} catch {
    Write-Warning "API endpoint (port 8000) is not accessible"
}

# Check UI endpoint (port 3000)
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $connect = $tcpClient.BeginConnect($InstanceIp, 3000, $null, $null)
    $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)
    if ($wait) {
        $tcpClient.EndConnect($connect)
        $tcpClient.Close()
        Write-Success "UI endpoint (port 3000) is accessible"
        
        # Test UI endpoint
        try {
            $response = Invoke-WebRequest -Uri "http://${InstanceIp}:3000" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 302) {
                Write-Success "UI web interface responding"
            } else {
                Write-Warning "UI web interface returned: $($response.StatusCode)"
            }
        } catch {
            Write-Warning "UI web interface not responding"
        }
    } else {
        Write-Warning "UI endpoint (port 3000) is not accessible"
    }
} catch {
    Write-Warning "UI endpoint (port 3000) is not accessible"
}

# Check /etc/motd for deployment status
Write-Host ""
Write-Host "Deployment Status (from /etc/motd):"
try {
    $motdContent = ssh "root@$InstanceIp" "cat /etc/motd" 2>&1
    
    if ($motdContent -match "Deployment Complete") {
        Write-Success "Deployment marked as complete in /etc/motd"
    } elseif ($motdContent -match "ERROR") {
        Write-Error "Deployment error detected in /etc/motd"
        Write-Host $motdContent
    } else {
        Write-Warning "Deployment status unclear"
    }
} catch {
    Write-Warning "Could not read /etc/motd"
}

Write-Host ""
Write-Host "Summary:"
Write-Host "  Chat UI: http://${InstanceIp}:3000"
Write-Host "  API: http://${InstanceIp}:8000/v1"
Write-Host ""
Write-Host "For detailed logs:"
Write-Host "  ssh root@$InstanceIp 'tail -f /var/log/ai-sandbox/deployment.log'"

