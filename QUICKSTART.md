# Quick Start Guide - FCS CLI

Get up and running with the CrowdStrike Falcon Cloud Security CLI in 5 minutes.

## Prerequisites

✅ Active CrowdStrike Falcon subscription
✅ Access to Falcon console
✅ Docker installed (for image scanning)

## Step 1: Download FCS CLI (2 minutes)

### Option A: Manual Download

1. Go to Falcon console: [https://falcon.crowdstrike.com](https://falcon.crowdstrike.com)
2. Navigate to **Support and resources > Tool downloads**
3. Search for "FCS CLI"
4. Download for your platform

### Option B: Use Our Script

```bash
git clone https://github.com/YOUR_USERNAME/fcs-cli-examples.git
cd fcs-cli-examples
./scripts/install-fcs-cli.sh --os darwin --arch arm64
```

## Step 2: Create API Credentials (1 minute)

1. In Falcon console, go to **Support and resources > API clients and keys**
2. Click **Add new API client**
3. Name it: "FCS CLI"
4. Select scopes:
   - ✅ Falcon Container CLI: Read/Write
   - ✅ Falcon Container Image: Read/Write
   - ✅ Infrastructure as Code: Read/Write
5. Click **Add**
6. **Copy and save** the Client ID and Secret (you won't see the secret again!)

## Step 3: Configure FCS CLI (1 minute)

```bash
fcs configure
```

Enter when prompted:
- **Falcon Client ID**: Paste your Client ID
- **Falcon Client Secret**: Paste your Client Secret
- **Falcon Region**: Choose based on your console URL:
  - `us-1` → https://falcon.crowdstrike.com
  - `us-2` → https://falcon.us-2.crowdstrike.com
  - `eu-1` → https://falcon.eu-1.crowdstrike.com

## Step 4: Run Your First Scan (1 minute)

### Scan a Container Image

```bash
fcs scan image nginx:latest
```

Expected output:
```
Scanning image: nginx:latest
✓ Image assessment complete
✓ Found X vulnerabilities
  - Critical: X
  - High: X
  - Medium: X
  - Low: X
```

### Scan Infrastructure as Code

```bash
# Create a sample Terraform file
mkdir -p ./terraform
cat > ./terraform/main.tf << 'EOF'
resource "aws_s3_bucket" "example" {
  bucket = "my-test-bucket"
}
EOF

# Scan it
fcs scan iac ./terraform/
```

## What's Next?

### Learn More

- 📖 [Full README](README.md) - Complete documentation
- 🔧 [Configuration Guide](docs/configuration-guide.md) - Advanced setup
- 💡 [Image Scan Examples](examples/image-scan-examples.sh) - More scanning examples
- 🏗️ [IaC Scan Examples](examples/iac-scan-examples.sh) - IaC scanning patterns

### Try Advanced Features

```bash
# Save results as JSON
fcs scan image nginx:latest --output json > results.json

# Batch scan multiple images
./scripts/batch-scan-images.sh images.txt

# Use the enhanced wrapper
./scripts/fcs-wrapper.sh scan image nginx:latest

# Verbose mode for debugging
fcs --verbose scan image nginx:latest
```

### Integrate into CI/CD

- [GitHub Actions Example](.github/workflows/fcs-scan.yml)
- [GitLab CI Example](README.md#gitlab-ci)
- [Jenkins Example](README.md#jenkins-pipeline)

## Common Issues

### "Command not found: fcs"

**Solution**: Add FCS CLI to your PATH
```bash
# macOS
sudo mv fcs /usr/local/bin/

# Linux
sudo mv fcs /usr/bin/

# Or add current directory to PATH
export PATH=$PATH:$(pwd)
```

### "Authentication failed"

**Solution**: Verify credentials and region
```bash
# Check configuration
fcs configure list

# Reconfigure if needed
fcs configure
```

### "Timeout exceeded"

**Solution**: Increase timeout for large images
```bash
fcs --timeout 600 scan image large-image:latest
```

## Quick Reference

### Common Commands

```bash
# Configure
fcs configure                              # Interactive setup
fcs configure --profile production         # Create new profile

# Scan Images
fcs scan image <image>                     # Basic scan
fcs scan image <image> --output json       # JSON output
fcs --verbose scan image <image>           # Verbose mode

# Scan IaC
fcs scan iac <path>                        # Scan directory
fcs scan iac <path> --output sarif         # SARIF output

# Utility
fcs --version                              # Show version
fcs --help                                 # Show help
fcs update                                 # Update to latest
```

### Environment Variables

```bash
export FALCON_CLIENT_ID="your-id"
export FALCON_CLIENT_SECRET="your-secret"
export FALCON_CLOUD="us-1"
export FCS_TIMEOUT=600
export FCS_VERBOSE=true
```

## Getting Help

- 📚 [Full Documentation](README.md)
- 🐛 [Report Issues](https://github.com/YOUR_USERNAME/fcs-cli-examples/issues)
- 💬 CrowdStrike Support Portal
- 📖 [Official FCS CLI Docs](https://falcon.crowdstrike.com/documentation)

---

**Time to first scan**: ~5 minutes ⚡

Ready to secure your containers and infrastructure! 🚀
