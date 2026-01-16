# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Email the maintainers directly or use GitHub's private vulnerability reporting
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Security Considerations

These scripts perform file system operations. Users should:

1. **Review before running**: Always use `--dry-run` first
2. **Understand the scope**: Scripts can delete files across your system
3. **Backup important data**: Before running destructive operations
4. **Run as regular user**: Do not run with `sudo` unless absolutely necessary

## Script Safety Features

- Double confirmation required for deletions
- 5-second countdown before destructive actions
- Dry-run mode available on all scripts
- Clear logging of all operations
- No network operations (offline-only)

## Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial assessment**: Within 7 days
- **Fix timeline**: Depends on severity

Thank you for helping keep this project secure.
