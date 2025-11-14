# Windows Deployment Guide

This guide covers deploying AI Quickstart - Mistral LLM from Windows using PowerShell scripts.

## Prerequisites

### 1. Install Python

Python is required for the Linode CLI:

1. Download Python from [python.org](https://www.python.org/downloads/)
2. During installation, check "Add Python to PATH"
3. Verify installation:
   ```powershell
   python --version
   ```

### 2. Install Linode CLI

Install the Linode CLI using pip:

```powershell
pip install linode-cli
```

Configure the CLI with your API token:

```powershell
linode-cli configure
```

Follow the prompts to enter your Linode API token. You can generate a token in the [Linode Cloud Manager](https://cloud.linode.com/profile/tokens).

### 3. Install jq (Optional but Recommended)

jq is useful for JSON parsing, though PowerShell can parse JSON natively:

**Option 1: Using winget (Windows 10/11)**
```powershell
winget install jqlang.jq
```

**Option 2: Manual Installation**
1. Download from [jq releases](https://github.com/jqlang/jq/releases)
2. Extract and add to your PATH

### 4. Configure SSH (Optional but Recommended)

SSH is built into Windows 10/11. Generate an SSH key:

```powershell
ssh-keygen -t ed25519
```

Press Enter to accept default location (`C:\Users\YourUsername\.ssh\id_ed25519`).

### 5. Check Prerequisites

Run the prerequisites check script:

```powershell
.\scripts\check-prerequisites.ps1
```

This will verify all required tools are installed and configured.

## Deployment

### Quick Start: Full Deployment

Deploy everything in one command:

```powershell
.\scripts\deploy-full.ps1
```

The script will prompt you interactively for:
- Region (RTX4000-available regions)
- Instance size (RTX4000 options)
- Model ID (optional, defaults to `mistralai/Mistral-7B-Instruct-v0.3`)

**Non-Interactive Mode** (for automation):

```powershell
.\scripts\deploy-full.ps1 -InstanceType "g2-gpu-rtx4000a1-s" -Region "us-sea" -ModelId "mistralai/Mistral-7B-Instruct-v0.3"
```

### Available Regions (RTX4000)

- Chicago, US (`us-ord`)
- Frankfurt 2, DE (`de-fra-2`)
- Osaka, JP (`jp-osa`)
- Paris, FR (`fr-par`)
- Seattle, WA, US (`us-sea`)
- Singapore 2, SG (`sg-sin-2`)

### Available Instance Sizes (RTX4000)

- Small (`g2-gpu-rtx4000a1-s`) - $350/month
- Medium (`g2-gpu-rtx4000a1-m`) - $446/month
- Large (`g2-gpu-rtx4000a1-l`) - $638/month
- X-Large (`g2-gpu-rtx4000a1-xl`) - $1022/month
- And more options (x2 and x4 GPU configurations available)

## Individual Scripts

### Create Instance

Create a new Linode GPU instance:

```powershell
.\scripts\create-instance.ps1
```

Or with parameters:

```powershell
.\scripts\create-instance.ps1 -InstanceType "g2-gpu-rtx4000a1-s" -Region "us-sea" -RootPassword "YourPassword123" -Label "my-instance"
```

### Validate Services

Validate that services are running:

```powershell
.\scripts\validate-services.ps1 -InstanceIp "192.168.1.100"
```

### Cleanup Instance

Delete a test instance:

```powershell
.\scripts\cleanup-instance.ps1 -InstanceId "12345678"
```

With force flag (no confirmation):

```powershell
.\scripts\cleanup-instance.ps1 -InstanceId "12345678" -Force
```

## PowerShell Execution Policy

If you encounter execution policy errors, you may need to allow script execution:

**Option 1: Run with bypass (for current session)**
```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\deploy-full.ps1
```

**Option 2: Set execution policy for current user (persistent)**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Option 3: Unblock specific scripts**
```powershell
Unblock-File .\scripts\*.ps1
```

## Alternative: Using WSL (Windows Subsystem for Linux)

If you prefer using the bash scripts, you can use WSL:

### Install WSL

1. Open PowerShell as Administrator
2. Run:
   ```powershell
   wsl --install
   ```
3. Restart your computer
4. Follow the prompts to set up Ubuntu

### Use Bash Scripts in WSL

1. Navigate to your project in WSL:
   ```bash
   cd /mnt/c/Users/YourUsername/Documents/GitHub/Linode/gpu-instance-quickstart
   ```

2. Install dependencies in WSL:
   ```bash
   sudo apt-get update
   sudo apt-get install python3-pip jq
   pip3 install linode-cli
   ```

3. Use the bash scripts as documented in the main [Quick Start Guide](quickstart.md)

## Troubleshooting

### PowerShell Script Errors

**"The term 'linode-cli' is not recognized"**
- Ensure Python is installed and in PATH
- Verify linode-cli is installed: `pip list | Select-String linode-cli`
- Try: `python -m pip install linode-cli`

**"Execution policy" errors**
- See "PowerShell Execution Policy" section above

**"Cannot connect via SSH"**
- Ensure SSH is enabled: `Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'`
- Install if needed: `Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0`

### Instance Creation Fails

- Check Linode CLI is configured: `linode-cli profile view`
- Verify you have GPU instance access
- Check API token permissions in Linode Cloud Manager
- Verify password meets requirements (11-128 chars, mixed case, numbers, special chars)

### Services Not Accessible

- Wait 3-5 minutes for services to initialize
- Re-run validation: `.\scripts\validate-services.ps1 -InstanceIp "YOUR_IP"`
- Check deployment logs: `ssh root@YOUR_IP 'tail -f /var/log/ai-sandbox/deployment.log'`

## Differences from Linux/macOS Scripts

The PowerShell scripts provide the same functionality as the bash scripts but with Windows-specific adaptations:

- Uses PowerShell native JSON parsing (jq optional)
- Uses Windows-style paths (`\` instead of `/`)
- Uses PowerShell cmdlets for file operations
- Uses `Invoke-WebRequest` instead of `curl` for HTTP requests
- Uses `Test-NetConnection` for port checking

## Next Steps

After successful deployment:

1. Test the chat interface: `http://YOUR_INSTANCE_IP:3000`
2. Test the API: `http://YOUR_INSTANCE_IP:8000/v1`
3. Configure firewall rules to protect your services
4. Review the [Security Guide](security.md) for best practices

## Additional Resources

- [Main Quick Start Guide](quickstart.md) - General deployment instructions
- [Scripts README](../scripts/README.md) - Detailed script documentation
- [Architecture Documentation](architecture.md) - System architecture details
- [API Usage Guide](api-usage.md) - API reference and examples

