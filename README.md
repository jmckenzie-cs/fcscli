# CrowdStrike FCS CLI - Comprehensive Usage Guide

[![CrowdStrike](https://img.shields.io/badge/CrowdStrike-Falcon%20Cloud%20Security-red)](https://www.crowdstrike.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> A comprehensive guide and example repository for using the CrowdStrike Falcon Cloud Security (FCS) CLI for container image scanning and Infrastructure as Code (IaC) security assessment.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [CI/CD Integration](#cicd-integration)
- [Advanced Use Cases](#advanced-use-cases)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

The FCS CLI is a powerful security tool that enables:

- 🐳 **Container Image Assessment**: Scan Docker images for vulnerabilities and security issues
- 📋 **Infrastructure as Code Scanning**: Detect misconfigurations in IaC templates (Terraform, CloudFormation, Kubernetes, etc.)
- 🔄 **CI/CD Integration**: Seamlessly integrate security checks into your development pipeline
- 🚀 **Pre-Runtime Security**: Shift security left by catching issues before deployment

## Prerequisites

- **Operating System**: Linux (kernel 2.6.32+), macOS (10.13+), or Windows (10+)
- **CrowdStrike Subscription**: Active Falcon Cloud Security subscription
- **API Credentials**: OAuth2 Client ID and Secret with appropriate scopes
- **Container Runtime** (for image scanning): Docker, Podman, or compatible runtime

### Required API Scopes

| Feature | Required Scopes |
|---------|----------------|
| Image Scanning | `Falcon Container CLI: Read/Write`<br>`Falcon Container Image: Read/Write` |
| IaC Scanning | `Infrastructure as Code: Read/Write` |
| CLI Updates | `Cloud Security Tools Download: Read` |

## Installation

### Option 1: Manual Installation (Recommended for First-Time Users)

**Note**: FCS CLI download requires authentication through Falcon Console (no public URLs available)

1. **Download from Falcon Console:**
   - Go to: https://falcon.crowdstrike.com
   - Navigate to: **Support and resources > Resources and tools > Tool downloads**
   - Search for: **FCS CLI** or **CLI**
   - Download file for your platform (e.g., `fcs_2.2.0_Darwin_arm64.tar.gz`)

2. **Install the binary:**

```bash
# Navigate to downloads directory
cd ~/Downloads

# Extract and make executable
tar -xvzf fcs_*.tar.gz
chmod u+x fcs

# Move to PATH
sudo mv fcs /usr/local/bin/

# Verify installation
fcs --version
```

### Option 2: Assisted Installation Script

Use the provided installation script to extract and install a previously downloaded file:

```bash
# First, download FCS CLI from Falcon Console to ~/Downloads or current directory
# Then run the installation script
./scripts/install-fcs-cli.sh --os darwin --arch arm64

# Or let it auto-detect your platform
./scripts/install-fcs-cli.sh
```

The script checks for the file in:
- Current directory (`.`)
- Downloads folder (`~/Downloads`)
- If not found, provides instructions to download from Falcon Console

### Option 3: Programmatic Download (Advanced)

Use the API-based download script with your credentials:

```bash
export FALCON_CLIENT_ID="your-client-id"
export FALCON_CLIENT_SECRET="your-client-secret"
export FALCON_API_URL="https://api.us-2.crowdstrike.com"  # Adjust for your region
./scripts/download-fcs-cli.sh
```

This script authenticates via API, downloads the latest version, verifies the hash, and extracts it.

### Option 4: Self-Update (If Already Installed)

```bash
# Update to latest version
fcs update

# Update to specific version
fcs update --version 2.2.0
```

## Configuration

### Step 1: Create API Credentials

1. Navigate to Falcon console: **Support and resources > API clients and keys**
2. Click **Add new API client**
3. Configure scopes based on your needs (see [Prerequisites](#prerequisites))
4. Save the Client ID and Secret securely

### Step 2: Configure FCS CLI

#### Interactive Configuration (Recommended)

```bash
fcs configure
```

You'll be prompted for:
- Falcon Client ID
- Falcon Client Secret (hidden input)
- Falcon Region (us-1, us-2, eu-1, us-gov-1, us-gov-2)

#### Non-Interactive Configuration

```bash
fcs configure \
  --client-id "your-client-id" \
  --client-secret "your-client-secret" \
  --falcon-cloud us-1
```

#### Environment Variables (CI/CD)

```bash
export FALCON_CLIENT_ID="your-client-id"
export FALCON_CLIENT_SECRET="your-client-secret"
export FALCON_CLOUD="us-1"
```

### Step 3: Verify Configuration

```bash
# List configured profiles
fcs configure list

# Test connection with a simple scan
fcs scan image alpine:latest
```

## Usage Examples

### 1. Basic Image Scanning

```bash
# Scan a local Docker image
fcs scan image nginx:latest

# Scan a specific image digest
fcs scan image nginx@sha256:abc123...

# Scan from a private registry
fcs scan image myregistry.io/myapp:v1.0.0
```

### 2. Advanced Image Scanning Options

```bash
# Verbose output for debugging
fcs --verbose scan image myapp:latest

# JSON output for parsing
fcs scan image myapp:latest --output json

# SARIF output for security tools
fcs scan image myapp:latest --output sarif > results.sarif

# Increase timeout for large images
fcs --timeout 600 scan image large-app:latest

# Save report to file
fcs scan image myapp:latest --output json > scan-results.json
```

### 3. Infrastructure as Code Scanning

```bash
# Scan Terraform files
fcs scan iac ./terraform/

# Scan Kubernetes manifests
fcs scan iac ./k8s/manifests/

# Scan CloudFormation templates
fcs scan iac ./cloudformation/

# Scan with specific output format
fcs scan iac ./infrastructure/ --output json
```

### 4. Multi-Profile Configuration

```bash
# Create development profile
fcs configure --profile development

# Create production profile
fcs configure --profile production

# Use specific profile for scanning
fcs --profile production scan image prod-app:latest

# Set default profile via environment
export FCS_PROFILE=production
fcs scan image prod-app:latest
```

### 5. Batch Scanning Script

```bash
# Scan multiple images from a file
./scripts/batch-scan-images.sh images.txt

# Scan all images in local Docker registry
./scripts/scan-all-local-images.sh
```

## CI/CD Integration

### GitHub Actions

Create `.github/workflows/fcs-scan.yml`:

```yaml
name: FCS Security Scan

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  security-scan:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Download FCS CLI
        run: |
          curl -L -o fcs.tar.gz https://path-to-download/fcs_2.2.0_Linux_x86_64.tar.gz
          tar -xzf fcs.tar.gz
          chmod +x fcs
          sudo mv fcs /usr/local/bin/

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

      - name: Build Docker image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Scan Docker image
        run: |
          fcs scan image myapp:${{ github.sha }} --output json > scan-results.json

      - name: Upload scan results
        uses: actions/upload-artifact@v3
        with:
          name: fcs-scan-results
          path: scan-results.json

      - name: Scan IaC files
        run: |
          fcs scan iac ./infrastructure/ --output sarif > iac-results.sarif

      - name: Upload SARIF results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: iac-results.sarif
```

### GitLab CI

Create `.gitlab-ci.yml`:

```yaml
stages:
  - security

fcs-scan:
  stage: security
  image: docker:latest
  services:
    - docker:dind

  before_script:
    - apk add --no-cache curl jq
    - curl -L -o fcs.tar.gz https://path-to-download/fcs_2.2.0_Linux_x86_64.tar.gz
    - tar -xzf fcs.tar.gz
    - chmod +x fcs
    - mv fcs /usr/local/bin/

  script:
    - fcs configure --client-id "$FALCON_CLIENT_ID" --client-secret "$FALCON_CLIENT_SECRET" --falcon-cloud us-1
    - docker build -t $CI_PROJECT_NAME:$CI_COMMIT_SHA .
    - fcs scan image $CI_PROJECT_NAME:$CI_COMMIT_SHA --output json > scan-results.json
    - fcs scan iac ./infrastructure/ --output json > iac-results.json

  artifacts:
    reports:
      container_scanning: scan-results.json
    paths:
      - scan-results.json
      - iac-results.json
    expire_in: 30 days

  variables:
    FALCON_CLIENT_ID: $FALCON_CLIENT_ID
    FALCON_CLIENT_SECRET: $FALCON_CLIENT_SECRET
```

### Jenkins Pipeline

Create `Jenkinsfile`:

```groovy
pipeline {
    agent any

    environment {
        FALCON_CLIENT_ID = credentials('falcon-client-id')
        FALCON_CLIENT_SECRET = credentials('falcon-client-secret')
        FALCON_CLOUD = 'us-1'
    }

    stages {
        stage('Setup FCS CLI') {
            steps {
                sh '''
                    curl -L -o fcs.tar.gz https://path-to-download/fcs_2.2.0_Linux_x86_64.tar.gz
                    tar -xzf fcs.tar.gz
                    chmod +x fcs
                    sudo mv fcs /usr/local/bin/
                '''
            }
        }

        stage('Configure FCS') {
            steps {
                sh '''
                    fcs configure \
                        --client-id "${FALCON_CLIENT_ID}" \
                        --client-secret "${FALCON_CLIENT_SECRET}" \
                        --falcon-cloud "${FALCON_CLOUD}"
                '''
            }
        }

        stage('Build Image') {
            steps {
                sh 'docker build -t myapp:${BUILD_NUMBER} .'
            }
        }

        stage('Scan Image') {
            steps {
                sh 'fcs scan image myapp:${BUILD_NUMBER} --output json > scan-results.json'
            }
        }

        stage('Scan IaC') {
            steps {
                sh 'fcs scan iac ./infrastructure/ --output json > iac-results.json'
            }
        }

        stage('Archive Results') {
            steps {
                archiveArtifacts artifacts: '*-results.json', fingerprint: true
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
```

## Advanced Use Cases

### 1. Programmatic Download and Update

See [`scripts/download-fcs-cli.sh`](scripts/download-fcs-cli.sh) for a complete example of programmatically downloading the FCS CLI.

**Important**: Set the correct region for your environment:

```bash
# For us-2 region
export FALCON_CLIENT_ID="your-client-id"
export FALCON_CLIENT_SECRET="your-client-secret"
export FALCON_API_URL="https://api.us-2.crowdstrike.com"
./scripts/download-fcs-cli.sh

# For us-1 region (default)
export FALCON_CLIENT_ID="your-client-id"
export FALCON_CLIENT_SECRET="your-client-secret"
./scripts/download-fcs-cli.sh
```

See [Region Configuration](#region-configuration) for all region URLs.

### 2. Custom Wrapper Script

See [`scripts/fcs-wrapper.sh`](scripts/fcs-wrapper.sh) for a wrapper that adds logging, error handling, and notifications.

### 3. Policy Enforcement

```bash
# Scan and fail build if critical vulnerabilities found
./scripts/enforce-policy.sh scan image myapp:latest --severity critical
```

### 4. Multi-Region Scanning

```bash
# Scan using different regional endpoints
./scripts/multi-region-scan.sh myapp:latest
```

### 5. Automated Reporting

```bash
# Generate HTML report from JSON output
./scripts/generate-report.sh scan-results.json > report.html
```

## Troubleshooting

### Common Issues

#### Authentication Errors

```bash
# Error: API key validation failed
# Solution: Verify credentials and region
fcs configure list

# Test with verbose output
fcs --verbose scan image alpine:latest
```

#### Timeout Issues

```bash
# Error: context deadline exceeded
# Solution: Increase timeout
fcs --timeout 900 scan image large-app:latest

# Or set via environment
export FCS_TIMEOUT=900
```

#### Container Runtime Issues

```bash
# Specify custom Docker socket
export DOCKER_HOST=unix:///custom/docker.sock
fcs scan image myapp:latest
```

#### Region Mismatch

```bash
# Verify your region matches Falcon console URL
# us-1: https://falcon.crowdstrike.com
# us-2: https://falcon.us-2.crowdstrike.com
# eu-1: https://falcon.eu-1.crowdstrike.com

fcs configure --falcon-cloud us-1
```

### Debug Mode

```bash
# Enable verbose logging
fcs --verbose scan image myapp:latest

# Set environment variable
export FCS_VERBOSE=true
fcs scan image myapp:latest
```

### Getting Help

```bash
# General help
fcs --help

# Command-specific help
fcs scan --help
fcs scan image --help
fcs configure --help
```

## Best Practices

### 1. Security

- ✅ Use separate API keys for different environments (dev, staging, prod)
- ✅ Apply principle of least privilege (minimum required scopes)
- ✅ Store credentials in secret management systems (not in code)
- ✅ Rotate API keys regularly
- ✅ Use read-only scopes where possible

### 2. CI/CD Integration

- ✅ Cache the FCS CLI binary to speed up builds
- ✅ Use specific CLI versions (not "latest") for reproducibility
- ✅ Set appropriate timeouts for large images
- ✅ Archive scan results as build artifacts
- ✅ Implement policy gates based on severity

### 3. Performance

- ✅ Use local image caching to avoid re-scanning
- ✅ Scan only changed images in CI/CD
- ✅ Implement parallel scanning for multiple images
- ✅ Use appropriate timeout values based on image size

### 4. Workflow

- ✅ Scan images before pushing to registry
- ✅ Scan IaC templates before applying
- ✅ Integrate with PR workflows for early feedback
- ✅ Generate reports for compliance and auditing
- ✅ Track vulnerability trends over time

## Project Structure

```
.
├── README.md                          # This file
├── .github/
│   └── workflows/
│       └── fcs-scan.yml              # GitHub Actions workflow
├── scripts/
│   ├── install-fcs-cli.sh            # Installation script
│   ├── download-fcs-cli.sh           # Programmatic download
│   ├── batch-scan-images.sh          # Batch image scanning
│   ├── scan-all-local-images.sh      # Scan all local images
│   ├── fcs-wrapper.sh                # Enhanced wrapper script
│   ├── enforce-policy.sh             # Policy enforcement
│   ├── multi-region-scan.sh          # Multi-region scanning
│   └── generate-report.sh            # Report generation
├── examples/
│   ├── image-scan-examples.sh        # Image scanning examples
│   ├── iac-scan-examples.sh          # IaC scanning examples
│   └── ci-cd-examples/               # CI/CD integration examples
└── docs/
    ├── api-reference.md              # API details
    ├── configuration-guide.md        # Advanced configuration
    └── troubleshooting-guide.md      # Extended troubleshooting
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Resources

- [CrowdStrike Falcon Documentation](https://docs.crowdstrike.com/home)
- [FCS CLI Official Documentation](https://docs.crowdstrike.com/r/s1018dc7)
- [CrowdStrike API Documentation](https://docs.crowdstrike.com/r/a2a7fc0e)

## Support

For issues with the FCS CLI itself, contact CrowdStrike Support.
For issues with this example repository, please open a GitHub issue.

---

**Disclaimer**: This is an unofficial example repository. For official documentation, please refer to the CrowdStrike Falcon console.
