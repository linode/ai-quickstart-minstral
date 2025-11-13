# Maintenance

This guide covers common maintenance tasks for your AI Quickstart - Minstral LLM instance.

## Updating Services

To update the Docker containers to their latest versions:

1. **SSH into your instance**:
   ```bash
   ssh root@YOUR_INSTANCE_IP
   ```

2. **Navigate to the service directory**:
   ```bash
   cd /opt/ai-sandbox
   ```

3. **Pull the latest container images**:
   ```bash
   docker-compose pull
   ```

4. **Restart services with new images**:
   ```bash
   docker-compose up -d
   ```

The services will restart automatically with the updated containers.

## Changing Models

To switch to a different model:

1. **SSH into your instance**:
   ```bash
   ssh root@YOUR_INSTANCE_IP
   ```

2. **Edit the Docker Compose configuration**:
   ```bash
   cd /opt/ai-sandbox
   nano docker-compose.yml
   ```

3. **Update the `MODEL_ID` environment variable**:
   ```yaml
   environment:
     - MODEL_ID=meta-llama/Llama-3-8B-Instruct  # Change this to your desired model
   ```

4. **Stop the current services**:
   ```bash
   docker-compose down
   ```

5. **Start services with the new model**:
   ```bash
   docker-compose up -d
   ```

**Note**: The new model will be downloaded automatically on first use. This may take several minutes depending on the model size.

## Viewing Logs

### View All Service Logs

```bash
cd /opt/ai-sandbox
docker-compose logs -f
```

### View Specific Service Logs

**API Service logs**:
```bash
cd /opt/ai-sandbox
docker-compose logs -f api
```

**UI Service logs**:
```bash
cd /opt/ai-sandbox
docker-compose logs -f ui
```

### View Recent Logs

```bash
cd /opt/ai-sandbox
docker-compose logs --tail=100
```

## Checking Service Status

### Check if Services are Running

```bash
cd /opt/ai-sandbox
docker-compose ps
```

This shows the status of all services (should show "Up" for both services).

### Check Service Health

**API Health Check**:
```bash
curl http://localhost:8000/health
```

**UI Health Check**:
```bash
curl http://localhost:3000
```

## Restarting Services

If you need to restart services without updating:

```bash
cd /opt/ai-sandbox
docker-compose restart
```

Or restart a specific service:

```bash
docker-compose restart api    # Restart API only
docker-compose restart ui      # Restart UI only
```

## Stopping Services

To stop all services:

```bash
cd /opt/ai-sandbox
docker-compose down
```

To stop and remove containers (keeps data):

```bash
docker-compose down
```

To stop and remove everything including volumes (⚠️ deletes data):

```bash
docker-compose down -v
```

## Managing Disk Space

### Check Disk Usage

```bash
df -h
```

### Check Model Cache Size

```bash
du -sh /opt/models
```

### Clean Up Unused Docker Resources

```bash
# Remove unused containers, networks, images
docker system prune

# Remove unused volumes (be careful - this may remove model cache)
docker volume prune
```

### Remove Old Models

If you've switched models and want to free up space:

```bash
# List models in cache
ls -lh /opt/models

# Remove a specific model (replace MODEL_NAME with actual model directory)
rm -rf /opt/models/MODEL_NAME
```

## Backup and Restore

### Backup Chat History

The chat UI data is stored in `/opt/open-webui`:

```bash
# Create a backup
tar -czf webui-backup-$(date +%Y%m%d).tar.gz /opt/open-webui
```

### Restore Chat History

```bash
# Extract backup
tar -xzf webui-backup-YYYYMMDD.tar.gz -C /
```

## System Updates

Keep your Ubuntu system updated:

```bash
# Update package lists
apt update

# Upgrade packages
apt upgrade -y

# Reboot if kernel was updated
reboot
```

## Troubleshooting

### Services Won't Start

1. **Check logs**:
   ```bash
   cd /opt/ai-sandbox
   docker-compose logs
   ```

2. **Check Docker status**:
   ```bash
   systemctl status docker
   ```

3. **Check disk space**:
   ```bash
   df -h
   ```

### API Not Responding

1. **Check if service is running**:
   ```bash
   docker-compose ps
   ```

2. **Check API logs**:
   ```bash
   docker-compose logs api
   ```

3. **Test locally**:
   ```bash
   curl http://localhost:8000/health
   ```

### UI Not Loading

1. **Check if service is running**:
   ```bash
   docker-compose ps
   ```

2. **Check UI logs**:
   ```bash
   docker-compose logs ui
   ```

3. **Check if UI can reach API**:
   ```bash
   curl http://localhost:8000/health
   ```

## Getting Help

For more detailed troubleshooting, see:
- [Quickstart Guide](quickstart.md#troubleshooting)
- [Scripts README](../scripts/README.md)

