# Contributing to shell-tools-playwright

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Use the bug report template
3. Include:
   - macOS version
   - Bash version (`bash --version`)
   - Node.js version (`node --version`)
   - Steps to reproduce
   - Expected vs actual behavior
   - Relevant script output

### Suggesting Features

1. Check existing issues and discussions
2. Use the feature request template
3. Describe the problem you're solving
4. Explain your proposed solution

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test thoroughly (see Testing below)
5. Commit with clear messages
6. Push to your fork
7. Open a Pull Request

## Code Style

### Shell Scripts

- Use `#!/bin/bash` shebang
- Enable strict mode: `set -euo pipefail`
- Use 4-space indentation
- Use snake_case for functions and variables
- Use UPPER_CASE for constants
- Quote all variables: `"$variable"`

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Scripts | kebab-case | `deep-uninstall.sh` |
| Functions | snake_case | `log_info` |
| Variables | snake_case | `browser_cache` |
| Constants | UPPER_CASE | `SCRIPT_VERSION` |
| Generated files | kebab-case + timestamp | `playwright-traces-20240116-143022.txt` |

### Logging

Use the standard logging functions:

```bash
log_info "Informational message"
log_success "Operation completed"
log_warning "Something to note"
log_error "Something failed"
```

### Comments

- Use American English
- Comment complex logic, not obvious code
- Keep comments concise

```bash
# Good: Explain why
# Skip hidden files to avoid permission errors
find "$dir" -not -path '*/\.*' ...

# Bad: State the obvious
# Loop through files
for file in *; do
```

## Testing

Before submitting changes:

### Basic Tests

```bash
# Test help and version
./tools/script.sh --help
./tools/script.sh --version

# Test dry-run mode
./tools/deep-uninstall.sh --dry-run
```

### Functional Tests

1. **Clean system test**: Run on system without Playwright
2. **Installed system test**: Run on system with Playwright
3. **Edge cases**: Empty directories, missing permissions, etc.

### Test Checklist

- [ ] `--help` displays usage (deep-uninstall.sh, install.sh)
- [ ] `--version` displays version (deep-uninstall.sh, install.sh)
- [ ] `--dry-run` makes no changes (deep-uninstall.sh)
- [ ] Colors display correctly in terminal
- [ ] Script handles missing dependencies gracefully
- [ ] Script works with default exclusions

## Pull Request Guidelines

### PR Title

Use a clear, descriptive title:
- `Add support for bun package manager`
- `Fix browser detection on macOS Sonoma`
- `Update documentation for custom browser paths`

### PR Description

Include:
- What changed and why
- How to test the changes
- Any breaking changes
- Related issues (use `Fixes #123` to auto-close)

### PR Checklist

- [ ] Code follows style guidelines
- [ ] Scripts are executable (`chmod +x`)
- [ ] `--help` is updated if needed
- [ ] README.md updated if needed
- [ ] Tested on macOS
- [ ] No hardcoded paths (use `$HOME`, etc.)

## Commit Messages

Write clear commit messages:

```
Add pnpm cache scanning to find-traces.sh

- Add scan_pnpm_cache function
- Include pnpm store path detection
- Update help text with pnpm mention

Fixes #42
```

### Format

```
<type>: <subject>

<body>

<footer>
```

Types: `Add`, `Fix`, `Update`, `Remove`, `Refactor`, `Docs`

## Questions?

- Open a GitHub Discussion
- Check existing issues
- Review the README and CLAUDE.md

Thank you for contributing!
