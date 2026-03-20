# FCS CLI Configuration Guide

## Overview

This guide covers advanced configuration options for the FCS CLI, including profile management, credential handling, and environment-specific setups.

## Configuration File Location

The FCS CLI stores configuration in:
- **Primary**: `~/.crowdstrike/fcs.json`
- **Legacy**: `fcs_profiles.json` (automatically migrated)
- **XDG compliant**: `$XDG_CONFIG_HOME/.crowdstrike/fcs.json`

## Configuration File Structure

```json
{
  "active_profile": "default",
  "profiles": {
    "default": {
      "client_id": "your-client-id",
      "client_secret": "your-client-secret",
      "falcon_region": "us-1",
      "custom_domains": {
        "api": "https://api.crowdstrike.com",
        "container_upload": "https://container-upload.us-1.crowdstrike.com",
        "image_assessment": "https://container-upload.us-1.crowdstrike.com"
      }
    },
    "production": {
      "client_id": "prod-client-id",
      "client_secret": "prod-client-secret",
      "falcon_region": "us-1"
    },
    "development": {
      "client_id": "dev-client-id",
      "client_secret": "dev-client-secret",
      "falcon_region": "us-2"
    }
  }
}
```

## Credential Precedence

The FCS CLI evaluates credentials in this order:

1. **Command-line flags** (highest priority)
   ```bash
   fcs --client-id "xxx" --client-secret "yyy" scan image nginx:latest
   ```

2. **Environment variables**
   ```bash
   export FALCON_CLIENT_ID="xxx"
   export FALCON_CLIENT_SECRET="yyy"
   export FALCON_CLOUD="us-1"
   fcs scan image nginx:latest
   ```

3. **Named profile**
   ```bash
   fcs --profile production scan image nginx:latest
   ```

4. **Default profile** (lowest priority)
   ```bash
   fcs scan image nginx:latest
   ```

## Profile Management

### Creating Profiles

#### Interactive Creation
```bash
fcs configure --profile production
```

#### Non-Interactive Creation
```bash
fcs configure --profile production \
  --client-id "prod-client-id" \
  --client-secret "prod-client-secret" \
  --falcon-cloud us-1
```

### Listing Profiles
```bash
fcs configure list
```

### Switching Profiles

#### Per-command
```bash
fcs --profile production scan image myapp:latest
```

#### Set default for session
```bash
export FCS_PROFILE=production
fcs scan image myapp:latest
```

### Editing Profiles

Edit the configuration file directly:
```bash
# macOS/Linux
vim ~/.crowdstrike/fcs.json

# Or use configure again
fcs configure --profile production
```

## Region Configuration

### Available Regions

| Region | URL | API Base URL |
|--------|-----|--------------|
| us-1 | https://falcon.crowdstrike.com | https://api.crowdstrike.com |
| us-2 | https://falcon.us-2.crowdstrike.com | https://api.us-2.crowdstrike.com |
| eu-1 | https://falcon.eu-1.crowdstrike.com | https://api.eu-1.crowdstrike.com |
| us-gov-1 | https://falcon.laggar.gcw.crowdstrike.com | https://api.laggar.gcw.crowdstrike.com |
| us-gov-2 | https://falcon.us-gov-2.crowdstrike.mil | https://api.us-gov-2.crowdstrike.mil |

### Setting Region
```bash
fcs configure --falcon-cloud us-1
```

## Environment Variables

### Complete List

| Variable | Description | Example |
|----------|-------------|---------|
| `FALCON_CLIENT_ID` | API Client ID | `abc123...` |
| `FALCON_CLIENT_SECRET` | API Client Secret | `xyz789...` |
| `FALCON_CLOUD` | Region identifier | `us-1` |
| `FCS_PROFILE` | Profile to use | `production` |
| `FCS_TIMEOUT` | Operation timeout (seconds) | `600` |
| `FCS_VERBOSE` | Enable verbose logging | `true` |
| `XDG_CONFIG_HOME` | Config directory (Linux/macOS) | `~/.config` |
| `DOCKER_HOST` | Docker socket path | `unix:///var/run/docker.sock` |

### Using Environment Variables

#### Bash/Zsh
```bash
export FALCON_CLIENT_ID="your-client-id"
export FALCON_CLIENT_SECRET="your-client-secret"
export FALCON_CLOUD="us-1"
```

#### Fish Shell
```fish
set -x FALCON_CLIENT_ID "your-client-id"
set -x FALCON_CLIENT_SECRET "your-client-secret"
set -x FALCON_CLOUD "us-1"
```

#### PowerShell (Windows)
```powershell
$env:FALCON_CLIENT_ID = "your-client-id"
$env:FALCON_CLIENT_SECRET = "your-client-secret"
$env:FALCON_CLOUD = "us-1"
```

## CI/CD Configuration

### GitHub Actions

Store credentials as secrets:
1. Go to repository **Settings > Secrets and variables > Actions**
2. Add secrets:
   - `FALCON_CLIENT_ID`
   - `FALCON_CLIENT_SECRET`

Use in workflow:
```yaml
- name: Configure FCS CLI
  env:
    FALCON_CLIENT_ID: ${{ secrets.FALCON_CLIENT_ID }}
    FALCON_CLIENT_SECRET: ${{ secrets.FALCON_CLIENT_SECRET }}
    FALCON_CLOUD: us-1
  run: |
    fcs configure \
      --client-id "${FALCON_CLIENT_ID}" \
      --client-secret "${FALCON_CLIENT_SECRET}" \
      --falcon-cloud "${FALCON_CLOUD}"
```

### GitLab CI

Store as CI/CD variables:
1. Go to **Settings > CI/CD > Variables**
2. Add variables:
   - `FALCON_CLIENT_ID` (Protected, Masked)
   - `FALCON_CLIENT_SECRET` (Protected, Masked)

Use in pipeline:
```yaml
variables:
  FALCON_CLIENT_ID: $FALCON_CLIENT_ID
  FALCON_CLIENT_SECRET: $FALCON_CLIENT_SECRET
  FALCON_CLOUD: us-1

script:
  - fcs configure --client-id "$FALCON_CLIENT_ID" --client-secret "$FALCON_CLIENT_SECRET" --falcon-cloud "$FALCON_CLOUD"
```

### Jenkins

Store in Jenkins Credentials:
1. Go to **Manage Jenkins > Credentials**
2. Add credentials:
   - Type: Secret text
   - ID: `falcon-client-id` and `falcon-client-secret`

Use in pipeline:
```groovy
environment {
    FALCON_CLIENT_ID = credentials('falcon-client-id')
    FALCON_CLIENT_SECRET = credentials('falcon-client-secret')
}
```

## Timeout Configuration

### Default Timeout
Default timeout: 300 seconds (5 minutes)

### Configuring Timeout

#### Per-command
```bash
fcs --timeout 600 scan image large-app:latest
```

#### Via environment variable
```bash
export FCS_TIMEOUT=900
fcs scan image large-app:latest
```

### Recommended Timeouts

| Image Size | Recommended Timeout |
|------------|-------------------|
| Small (<500MB) | 300s (default) |
| Medium (500MB-2GB) | 600s |
| Large (2GB-5GB) | 900s |
| Very Large (>5GB) | 1200s+ |

## Docker Socket Configuration

### Default Socket
FCS CLI automatically detects the Docker socket.

### Custom Socket

#### Linux/macOS
```bash
export DOCKER_HOST=unix:///custom/path/docker.sock
fcs scan image nginx:latest
```

#### Windows (Named Pipe)
```powershell
$env:DOCKER_HOST = "npipe:////./pipe/docker_engine"
```

#### TCP Socket (Remote Docker)
```bash
export DOCKER_HOST=tcp://remote-docker-host:2375
fcs scan image nginx:latest
```

## Security Best Practices

### 1. Credential Storage

❌ **Don't:**
```bash
# Don't store credentials in scripts
fcs configure --client-id "abc123" --client-secret "xyz789"
```

✅ **Do:**
```bash
# Use environment variables or secret managers
export FALCON_CLIENT_ID=$(vault read -field=client_id secret/crowdstrike)
export FALCON_CLIENT_SECRET=$(vault read -field=client_secret secret/crowdstrike)
```

### 2. API Key Permissions

Create API keys with minimum required scopes:

**Image Scanning Only:**
- Falcon Container CLI: Read/Write
- Falcon Container Image: Read/Write

**IaC Scanning Only:**
- Infrastructure as Code: Read/Write

**Both + Updates:**
- All above scopes
- Cloud Security Tools Download: Read

### 3. Environment Isolation

Use separate profiles for different environments:
```bash
# Development
fcs configure --profile dev

# Staging
fcs configure --profile staging

# Production
fcs configure --profile prod
```

### 4. Key Rotation

Regularly rotate API keys:
1. Create new API client in Falcon console
2. Update configuration:
   ```bash
   fcs configure --profile production
   ```
3. Test with new credentials
4. Delete old API client

## Troubleshooting Configuration

### Check Current Configuration
```bash
fcs configure list
```

### Verify Connectivity
```bash
fcs --verbose scan image alpine:latest
```

### Test with Specific Credentials
```bash
fcs --client-id "xxx" --client-secret "yyy" --falcon-cloud us-1 scan image alpine:latest
```

### Debug Configuration Issues
```bash
# Enable verbose mode
export FCS_VERBOSE=true

# Check which profile is active
fcs configure list | grep "active"

# Test authentication
fcs --verbose scan image alpine:latest 2>&1 | grep -i auth
```

## Advanced: Custom API Endpoints

For advanced use cases (e.g., proxy, testing):

Edit `~/.crowdstrike/fcs.json`:
```json
{
  "profiles": {
    "custom": {
      "client_id": "xxx",
      "client_secret": "yyy",
      "falcon_region": "us-1",
      "custom_domains": {
        "api": "https://custom-api.example.com",
        "container_upload": "https://custom-upload.example.com",
        "image_assessment": "https://custom-assessment.example.com"
      }
    }
  }
}
```

## Migration from Legacy Configuration

If you have `fcs_profiles.json`:

```bash
# Automatic migration
fcs migrate-config

# Manual migration
# The old format will be detected and you'll be prompted to migrate
fcs configure
```

Backup is stored at: `fcs_profiles.json.backup`
