# Contributing to FCS CLI Examples

Thank you for your interest in contributing! This document provides guidelines for contributing to this repository.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Getting Started](#getting-started)
- [Contribution Guidelines](#contribution-guidelines)
- [Style Guide](#style-guide)
- [Submitting Changes](#submitting-changes)

## Code of Conduct

This project follows a code of conduct to ensure a welcoming environment for all contributors. By participating, you agree to:

- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards others

## How Can I Contribute?

### Reporting Issues

If you find a bug or have a suggestion:

1. **Check existing issues** to avoid duplicates
2. **Create a new issue** with:
   - Clear title and description
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Your environment (OS, FCS CLI version, etc.)
   - Relevant logs or screenshots

### Suggesting Enhancements

Enhancement suggestions are welcome! Please:

1. **Check if the enhancement has been suggested** before
2. **Provide a clear use case** for the enhancement
3. **Explain why this would be useful** to others
4. **Include example code or mockups** if applicable

### Contributing Code

We welcome:

- 🐛 Bug fixes
- 📝 Documentation improvements
- ✨ New example scripts
- 🎨 Improved error messages or output
- 🚀 New CI/CD integration examples
- 📊 Enhanced reporting tools

## Getting Started

### Prerequisites

- Git
- Bash (for shell scripts)
- Basic understanding of Docker and IaC tools
- (Optional) FCS CLI installed for testing

### Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/fcs-cli-examples.git
cd fcs-cli-examples

# Add upstream remote
git remote add upstream https://github.com/ORIGINAL_OWNER/fcs-cli-examples.git
```

### Create a Branch

```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Or a bugfix branch
git checkout -b fix/issue-number-description
```

## Contribution Guidelines

### Scripts

When contributing scripts:

1. **Use proper shebang**: `#!/usr/bin/env bash`
2. **Enable strict mode**: `set -euo pipefail`
3. **Add comments**: Explain complex logic
4. **Include help text**: Provide `--help` or `-h` option
5. **Handle errors gracefully**: Check prerequisites and provide clear error messages
6. **Make scripts portable**: Test on Linux and macOS if possible

Example script structure:

```bash
#!/usr/bin/env bash

# Script Name and Description
# Brief explanation of what this script does

set -euo pipefail

# Configuration
VARIABLE="${VARIABLE:-default_value}"

# Logging functions
log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; }

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Description of the script

OPTIONS:
    -h, --help    Show this help message

EXAMPLES:
    $0 --option value
EOF
    exit 1
}

# Main function
main() {
    # Your code here
    :
}

main "$@"
```

### Documentation

When contributing documentation:

1. **Use clear, concise language**
2. **Include code examples** where appropriate
3. **Test all commands** before submitting
4. **Use proper Markdown formatting**
5. **Link to related resources**

### Examples

When adding examples:

1. **Make them realistic** and practical
2. **Include comments** explaining each step
3. **Show both input and expected output**
4. **Cover edge cases** when relevant
5. **Keep them self-contained**

## Style Guide

### Shell Scripts

Follow these conventions:

```bash
# Variables: UPPER_CASE for constants, lower_case for local
CONSTANT_VALUE="example"
local_variable="value"

# Function names: lowercase with underscores
function_name() {
    local param="$1"
    # function body
}

# Conditionals: use [[ ]] instead of [ ]
if [[ -f "$file" ]]; then
    echo "File exists"
fi

# Loops: quote variables
for item in "${array[@]}"; do
    echo "$item"
done

# Error handling: check command success
if ! command -v fcs &> /dev/null; then
    log_error "FCS CLI not found"
    exit 1
fi
```

### Markdown

- Use ATX-style headers (`#` prefix)
- Use fenced code blocks with language specifiers
- Use tables for structured data
- Keep lines under 120 characters when possible
- Use relative links for internal references

### Commit Messages

Follow the conventional commits format:

```
type(scope): subject

body

footer
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(scripts): add batch scanning script

Add a new script that scans multiple images from a file.
Includes progress tracking and summary generation.

Closes #123

---

fix(docs): correct configuration example

The client-secret flag was incorrectly shown as client_secret

---

docs(readme): add troubleshooting section

Add common issues and solutions to help users debug problems
```

## Submitting Changes

### Before Submitting

1. **Test your changes** thoroughly
2. **Update documentation** if needed
3. **Add examples** for new features
4. **Check for sensitive data** (credentials, tokens, etc.)
5. **Run shellcheck** on shell scripts (if available):
   ```bash
   shellcheck scripts/*.sh
   ```

### Pull Request Process

1. **Update your fork**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Push your changes**:
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create a Pull Request** on GitHub with:
   - Clear title describing the change
   - Description of what changed and why
   - Link to related issues (if applicable)
   - Screenshots or examples (if applicable)

4. **Respond to feedback**:
   - Address reviewer comments
   - Make requested changes
   - Push updates to the same branch

### Pull Request Checklist

- [ ] My code follows the style guide
- [ ] I have tested my changes
- [ ] I have updated documentation
- [ ] My commits follow the commit message format
- [ ] I have added examples (if applicable)
- [ ] I have checked for sensitive data
- [ ] All scripts are executable (`chmod +x`)
- [ ] Scripts include help text

## Testing

### Manual Testing

Test your scripts manually:

```bash
# Test script execution
./scripts/your-script.sh --help

# Test with different inputs
./scripts/your-script.sh --option value1
./scripts/your-script.sh --option value2

# Test error handling
./scripts/your-script.sh --invalid-option
```

### Integration Testing

If you have FCS CLI installed:

```bash
# Test with real FCS CLI commands
fcs scan image alpine:latest
./scripts/your-script.sh
```

## Questions?

If you have questions:

1. Check the [README](README.md)
2. Review existing [issues](https://github.com/OWNER/REPO/issues)
3. Open a new issue for discussion

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing! 🎉
