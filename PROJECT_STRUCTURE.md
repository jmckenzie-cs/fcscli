# Project Structure

This document provides an overview of the repository structure and explains the purpose of each file and directory.

## Repository Layout

```
fcs-cli-examples/
├── .github/
│   └── workflows/
│       └── fcs-scan.yml              # GitHub Actions CI/CD workflow
│
├── docs/
│   └── configuration-guide.md        # Advanced configuration documentation
│
├── examples/
│   ├── image-scan-examples.sh        # Container image scanning examples
│   └── iac-scan-examples.sh          # Infrastructure as Code scanning examples
│
├── scripts/
│   ├── install-fcs-cli.sh            # Installation automation script
│   ├── download-fcs-cli.sh           # Programmatic download via API
│   ├── batch-scan-images.sh          # Batch scanning multiple images
│   └── fcs-wrapper.sh                # Enhanced wrapper with logging & retry
│
├── .gitignore                         # Git ignore patterns
├── CONTRIBUTING.md                    # Contribution guidelines
├── LICENSE                            # MIT License
├── QUICKSTART.md                      # 5-minute getting started guide
├── README.md                          # Main documentation
└── images.txt                         # Sample image list for batch scanning
```

## File Descriptions

### Root Directory

#### [README.md](README.md)
**Purpose**: Main documentation hub
**Contents**:
- Complete overview of FCS CLI
- Installation instructions
- Configuration guide
- Usage examples
- CI/CD integration patterns
- Troubleshooting
- Best practices

**Use when**: You need comprehensive information about any aspect of the FCS CLI

#### [QUICKSTART.md](QUICKSTART.md)
**Purpose**: Fast-track guide for new users
**Contents**:
- 5-minute setup guide
- Essential commands
- First scan instructions
- Quick reference

**Use when**: You're new to FCS CLI and want to get started quickly

#### [CONTRIBUTING.md](CONTRIBUTING.md)
**Purpose**: Guidelines for contributing to the repository
**Contents**:
- Code of conduct
- Contribution process
- Style guides
- Testing guidelines
- Pull request process

**Use when**: You want to contribute improvements or report issues

#### [LICENSE](LICENSE)
**Purpose**: MIT License for the example code
**Note**: Applies to example code only, not the FCS CLI itself

#### [.gitignore](.gitignore)
**Purpose**: Specifies files to exclude from version control
**Excludes**:
- Credentials and secrets
- Scan results
- Logs
- Binaries
- OS-specific files

#### [images.txt](images.txt)
**Purpose**: Sample list of images for batch scanning
**Format**: One image per line, comments with `#`
**Use with**: `./scripts/batch-scan-images.sh images.txt`

---

### `.github/workflows/`

#### [fcs-scan.yml](.github/workflows/fcs-scan.yml)
**Purpose**: Production-ready GitHub Actions workflow
**Features**:
- Automated image scanning on push/PR
- IaC scanning with SARIF upload
- Caching for faster builds
- Matrix strategy for multiple images
- Policy enforcement
- Slack notifications
- PR comments with results

**Triggers**:
- Push to main/develop
- Pull requests
- Scheduled (daily)
- Manual dispatch

**Secrets required**:
- `FALCON_CLIENT_ID`
- `FALCON_CLIENT_SECRET`
- `SLACK_WEBHOOK_URL` (optional)

---

### `docs/`

#### [configuration-guide.md](docs/configuration-guide.md)
**Purpose**: Deep-dive into FCS CLI configuration
**Topics**:
- Configuration file structure
- Profile management
- Credential precedence
- Environment variables
- CI/CD setup
- Security best practices
- Timeout configuration
- Docker socket configuration
- Troubleshooting

**Use when**: You need advanced configuration or multi-environment setup

---

### `scripts/`

#### [install-fcs-cli.sh](scripts/install-fcs-cli.sh)
**Purpose**: Automated installation of FCS CLI
**Features**:
- Platform detection (Linux, macOS, Windows)
- Architecture detection (amd64, arm64)
- Version specification
- Custom installation directory
- Existing installation check
- Verification

**Usage**:
```bash
# Auto-detect platform
./scripts/install-fcs-cli.sh

# Specify platform and architecture
./scripts/install-fcs-cli.sh --os darwin --arch arm64

# Install specific version
./scripts/install-fcs-cli.sh --version 2.1.5

# Custom installation directory
./scripts/install-fcs-cli.sh --dir ~/bin
```

**Requirements**: Manual download step (can't bypass Falcon console authentication)

#### [download-fcs-cli.sh](scripts/download-fcs-cli.sh)
**Purpose**: Programmatic download using CrowdStrike API
**Features**:
- OAuth2 authentication
- Version enumeration
- Platform-specific download
- SHA256 verification
- Automatic token handling

**Usage**:
```bash
export FALCON_CLIENT_ID="your-id"
export FALCON_CLIENT_SECRET="your-secret"
./scripts/download-fcs-cli.sh
```

**Requirements**:
- `curl`
- `jq`
- API client with "Cloud Security Tools Download: Read" scope

**Use cases**:
- CI/CD pipelines
- Automated deployments
- Version pinning
- Airgapped environments (pre-download)

#### [batch-scan-images.sh](scripts/batch-scan-images.sh)
**Purpose**: Scan multiple images from a file
**Features**:
- Read images from text file
- Progress tracking
- Parallel scanning (configurable)
- Summary report generation
- Error handling
- Individual result files

**Usage**:
```bash
# Basic batch scan
./scripts/batch-scan-images.sh images.txt

# Parallel scanning
./scripts/batch-scan-images.sh --parallel 4 images.txt

# Custom output directory
./scripts/batch-scan-images.sh --output-dir ./results images.txt

# SARIF format
./scripts/batch-scan-images.sh --format sarif images.txt

# Fail on first error
./scripts/batch-scan-images.sh --fail-on-error images.txt
```

**Input file format**:
```
nginx:latest
alpine:3.14
# Comments are supported
myregistry.io/myapp:v1.0.0
```

**Output**:
- Individual scan results per image
- Summary report with statistics
- Exit code based on failures

#### [fcs-wrapper.sh](scripts/fcs-wrapper.sh)
**Purpose**: Enhanced wrapper around FCS CLI
**Features**:
- Automatic logging to files
- Retry logic on failures
- Slack notifications (optional)
- Result parsing and metrics
- Error handling
- Execution timing

**Usage**:
```bash
# Basic usage
./scripts/fcs-wrapper.sh scan image nginx:latest

# With Slack notifications
export ENABLE_SLACK_NOTIFICATIONS=true
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
./scripts/fcs-wrapper.sh scan image nginx:latest

# Configure retry behavior
export MAX_RETRIES=5
export RETRY_DELAY=10
./scripts/fcs-wrapper.sh scan image myapp:latest
```

**Environment variables**:
- `LOG_DIR`: Log directory (default: `./logs`)
- `MAX_RETRIES`: Retry attempts (default: `3`)
- `RETRY_DELAY`: Delay between retries in seconds (default: `5`)
- `ENABLE_SLACK_NOTIFICATIONS`: Enable Slack (default: `false`)
- `SLACK_WEBHOOK_URL`: Webhook URL for notifications

**Use cases**:
- Production environments
- CI/CD pipelines
- Cron jobs
- Auditing requirements

---

### `examples/`

#### [image-scan-examples.sh](examples/image-scan-examples.sh)
**Purpose**: Comprehensive image scanning examples
**Contents**:
- Basic image scanning
- Private registry authentication
- Output formats (JSON, SARIF)
- Verbose mode
- Timeout configuration
- Profile usage
- Result parsing with `jq`
- CI/CD patterns
- Batch scanning
- Docker integration
- Custom socket configuration
- Automated reporting

**Format**: Executable script that displays examples
**Run**: `./examples/image-scan-examples.sh`

#### [iac-scan-examples.sh](examples/iac-scan-examples.sh)
**Purpose**: Comprehensive IaC scanning examples
**Contents**:
- Basic IaC scanning
- Multiple IaC types (Terraform, Kubernetes, CloudFormation)
- Output formats
- Verbose mode
- Profile usage
- CI/CD integration
- Result parsing
- Terraform-specific examples
- Kubernetes manifest examples
- CloudFormation examples
- Policy enforcement
- Pre-commit hooks
- Report generation
- Multi-environment scanning

**Format**: Executable script that displays examples
**Run**: `./examples/iac-scan-examples.sh`

---

## Usage Patterns

### For New Users
1. Start with [QUICKSTART.md](QUICKSTART.md)
2. Run your first scan
3. Review [README.md](README.md) for more details

### For CI/CD Integration
1. Review [.github/workflows/fcs-scan.yml](.github/workflows/fcs-scan.yml)
2. Adapt to your CI/CD platform (GitLab, Jenkins, etc.)
3. Use scripts for automation

### For Advanced Configuration
1. Read [docs/configuration-guide.md](docs/configuration-guide.md)
2. Set up profiles for different environments
3. Configure timeouts and custom endpoints

### For Automation
1. Use [scripts/download-fcs-cli.sh](scripts/download-fcs-cli.sh) for programmatic download
2. Use [scripts/batch-scan-images.sh](scripts/batch-scan-images.sh) for multiple images
3. Use [scripts/fcs-wrapper.sh](scripts/fcs-wrapper.sh) for production deployments

### For Learning
1. Review [examples/image-scan-examples.sh](examples/image-scan-examples.sh)
2. Review [examples/iac-scan-examples.sh](examples/iac-scan-examples.sh)
3. Experiment with different options

---

## Maintenance

### Adding New Scripts
1. Place in `scripts/` directory
2. Follow naming convention: `verb-noun.sh`
3. Include help text and usage function
4. Make executable: `chmod +x scripts/your-script.sh`
5. Update this document

### Adding New Examples
1. Place in `examples/` directory
2. Follow existing format
3. Include comments explaining each command
4. Test all examples
5. Update README.md

### Adding New Documentation
1. Place in `docs/` directory
2. Use clear headings and formatting
3. Include code examples
4. Link from README.md

---

## Dependencies

### Required for Scripts
- `bash` (v4.0+)
- `curl`
- `jq` (for JSON parsing)
- `tar` or `unzip` (for extraction)

### Optional
- `docker` (for image scanning)
- `git` (for version control)
- `shellcheck` (for script linting)

---

## Testing

### Manual Testing
```bash
# Test installation script
./scripts/install-fcs-cli.sh --help

# Test batch scanning
echo "alpine:latest" > test-images.txt
./scripts/batch-scan-images.sh test-images.txt

# Test wrapper
./scripts/fcs-wrapper.sh --help
```

### Integration Testing
```bash
# Requires FCS CLI installed and configured
fcs scan image alpine:latest
./scripts/batch-scan-images.sh images.txt
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- How to contribute
- Code style guidelines
- Testing requirements
- Pull request process

---

## Support

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/fcs-cli-examples/issues)
- **Documentation**: This repository
- **FCS CLI Support**: CrowdStrike Support Portal
- **Official Docs**: [Falcon Documentation](https://falcon.crowdstrike.com/documentation)

---

**Last Updated**: 2026-03-19
