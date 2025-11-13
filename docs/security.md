# Security

## ⚠️ Important Security Warning

**By default, both services are exposed to the internet without authentication.**

This means:
- Anyone with your instance IP address can access the Chat UI on port `3000`
- Anyone with your instance IP address can use the API on port `8000`
- There is no built-in authentication or access control

## Required: Configure a Firewall

**You must configure a Linode Cloud Firewall** to protect your services. This is the primary security measure for AI Quickstart - Minstral LLM.

### Setting Up a Linode Cloud Firewall

1. **Create a Firewall** in the Linode Cloud Manager:
   - Navigate to **Firewalls** in the left sidebar
   - Click **Create Firewall**
   - Give it a descriptive name (e.g., "AI Quickstart - Minstral LLM Firewall")

2. **Configure Inbound Rules**:
   - **SSH (Port 22)**: Allow from your IP address only
   - **Chat UI (Port 3000)**: Allow from specific IP addresses or IP ranges you trust
   - **API (Port 8000)**: Allow from specific IP addresses or IP ranges you trust
   - **Block all other inbound traffic**

3. **Configure Outbound Rules**:
   - Allow all outbound traffic (default)

4. **Attach to Your Instance**:
   - Select your GPU instance
   - Apply the firewall

### Example Firewall Rules

**Inbound Rules:**
- SSH (22): Allow from `YOUR_IP_ADDRESS/32`
- Custom (3000): Allow from `YOUR_IP_ADDRESS/32` (Chat UI)
- Custom (8000): Allow from `YOUR_IP_ADDRESS/32` (API)
- All other ports: Drop

**Outbound Rules:**
- All ports: Accept

## Security Best Practices

### 1. Use SSH Key Authentication

Instead of password authentication, use SSH keys:

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy public key to instance
ssh-copy-id root@YOUR_INSTANCE_IP
```

### 2. Restrict SSH Access

- Only allow SSH from trusted IP addresses
- Consider using a VPN or bastion host for additional security
- Disable password authentication if using SSH keys

### 3. Regular Updates

Keep your instance and containers updated:

```bash
# Update system packages
apt update && apt upgrade -y

# Update Docker containers
cd /opt/ai-sandbox
docker-compose pull
docker-compose up -d
```

### 4. Monitor Access

- Regularly review firewall logs
- Monitor instance resource usage
- Set up alerts for unusual activity

### 5. Use HTTPS (Future Enhancement)

Currently, the services run over HTTP. For production use, consider:
- Setting up a reverse proxy (nginx/traefik) with SSL certificates
- Using Let's Encrypt for free SSL certificates
- Configuring the services behind the proxy

## Security Warning in MOTD

A security warning is displayed in the system Message of the Day (`/etc/motd`) when you SSH into the instance. This serves as a reminder to configure proper firewall rules.

## Limitations (V1)

The current version has the following security limitations:

- **No automatic API authentication**: You must use a firewall
- **No user accounts for the UI**: The chat interface is open by default
- **No automatic HTTPS/SSL**: Services run over HTTP

These limitations are planned to be addressed in future versions.

## Reporting Security Issues

If you discover a security vulnerability, please:
1. **Do not** open a public issue
2. Contact the maintainers directly
3. Provide details about the vulnerability

## Additional Resources

- [Linode Cloud Firewall Documentation](https://www.linode.com/docs/guides/cloud-firewall/)
- [Linode Security Best Practices](https://www.linode.com/docs/guides/linux-security-basics/)

