<div align="center">

```
                  █▀█ █   █▀█ █ █ █ █ █ █▀█ █ █▀▀ █ █ ▀█▀
                  █▀▀ █   █▀█  █  ▀▄▀▄▀ █▀▄ █ █ █ █▀█  █
                  ▀   ▀▀▀ ▀ ▀  ▀   ▀ ▀  ▀ ▀ ▀ ▀▀▀ ▀ ▀  ▀
                              ─── TOOLS ───
```

**Deep uninstall, clean install, and find traces of Playwright on macOS**

[![Platform](https://img.shields.io/badge/platform-macOS-blue?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-yellow?style=for-the-badge)](LICENSE)
[![Node.js](https://img.shields.io/badge/node.js-only-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org/)

</div>

---

> **Note:** This project focuses exclusively on **Playwright for Node.js**.

## Scope

### What This Project Covers

✅ **Playwright for Node.js** - The JavaScript/TypeScript testing framework installed via npm/yarn/pnpm.

### What This Project Does NOT Cover

❌ **Other language bindings:**
- **Playwright for Python** - Popular for data scraping (installed via `pip`)
- **Playwright for .NET** - Microsoft ecosystem (C#)
- **Playwright for Java** - Enterprise environments

❌ **Embedded Playwright installations:**
These are isolated versions bundled inside other software:
- **VS Code** - The official Playwright extension has its own components
- **Scraping tools** - Some data extraction tools use Playwright internally
- **Visual testing tools** - Software like Storybook may embed Playwright
- **CI/CD platforms** - Some testing services bundle Playwright

These embedded versions live inside their host application's directory, completely isolated from your own installations. **We do NOT touch these.**

### ⚠️ Important: Shared Browser Cache

The browser cache at `~/Library/Caches/ms-playwright/` is **SHARED** across all Playwright language bindings:

| Language | Shares Browser Cache? |
|----------|----------------------|
| Node.js | ✅ Yes |
| Python | ✅ Yes |
| .NET | ✅ Yes |
| Java | ✅ Yes |

**Warning:** Running `deep-uninstall.sh` will delete the shared browser cache, affecting ALL Playwright installations regardless of language. If you have Playwright Python installed alongside Node.js, you will need to reinstall the browsers for Python too.

## The Problem

Playwright stores files in multiple locations across your system:
- Browser binaries in `~/Library/Caches/ms-playwright/`
- Global npm/yarn/pnpm packages
- Package manager cache entries
- Test artifacts and reports in project directories

When Playwright misbehaves or you need a fresh start, manually tracking down all these files is tedious and error-prone. These scripts solve that.

## How Playwright Installation Works

Playwright for Node.js can be installed in two ways:

### 1. Locally in a Project (Most Common)

```bash
cd my-project
npm install -D playwright
```

This puts the package in `./node_modules/` and you use it with `npx playwright ...`

This is the typical use case for E2E testing in a web project.

### 2. Globally on the System

```bash
npm install -g playwright
```

This makes `playwright` accessible everywhere. Useful for codegen or scraping without a dedicated project.

### What install.sh Does

The script supports both modes:

| Command | Mode |
|---------|------|
| `./tools/install.sh` | Global (default) |
| `./tools/install.sh --local` | Local (current directory) |
| `./tools/install.sh --project ~/my-project` | Local (specific directory) |

### Key Point: Shared Browser Cache

The npm package (JavaScript code) can be local OR global.

The browser cache (Chromium, Firefox, WebKit) is **always in the same place**:
```
~/Library/Caches/ms-playwright/
```

Even if you install Playwright locally in 10 different projects, they all share the same browser cache (several GB).

This is why `deep-uninstall.sh` removes this shared cache—and why it affects all installations (Node.js, Python, etc.).

## Scripts

| Script | Purpose |
|--------|---------|
| `deep-uninstall.sh` | Complete removal of all Playwright files with safety confirmations |
| `install.sh` | Clean, verified Playwright installation with prerequisite checks |
| `find-traces.sh` | System-wide scan for any Playwright remnants |

## Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/shell-tools-playwright.git
cd shell-tools-playwright

# Make scripts executable (already done, but just in case)
chmod +x tools/*.sh

# Preview what would be removed (safe, no deletion)
./tools/deep-uninstall.sh --dry-run

# Find all Playwright traces on your system
./tools/find-traces.sh

# Clean install Playwright
./tools/install.sh
```

## Detailed Usage

### deep-uninstall.sh

Completely removes Playwright from your system.

```bash
# Preview mode (recommended first)
./tools/deep-uninstall.sh --dry-run

# Interactive removal with confirmations
./tools/deep-uninstall.sh
```

**What it removes:**
- Browser binaries (Chromium, Firefox, WebKit)
- Global npm/yarn/pnpm Playwright packages
- npm cache entries containing Playwright
- Custom `PLAYWRIGHT_BROWSERS_PATH` locations

**Safety features:**
- Double confirmation required (type `YES` then `DELETE PLAYWRIGHT`)
- 5-second countdown before deletion
- Dry-run mode for safe preview

### install.sh

Performs a clean, verified Playwright installation.

```bash
# Global installation (default)
./tools/install.sh

# Install locally in current directory
./tools/install.sh --local

# Install specific browsers
./tools/install.sh --browsers chromium           # Chromium only (default)
./tools/install.sh --browsers "chromium firefox" # Multiple browsers
./tools/install.sh --browsers all                # All browsers

# Install in specific project
./tools/install.sh --project ~/my-project

# Check prerequisites only
./tools/install.sh --check
```

**What it does:**
1. Checks prerequisites (Node.js 16+, npm 7+)
2. Detects existing installation (offers cleanup)
3. Installs Playwright packages
4. Downloads selected browsers
5. Verifies installation is working

### find-traces.sh

Scans your system for any Playwright-related files.

```bash
# Run scan (automatically saves report to current directory)
./tools/find-traces.sh
```

The script automatically generates a timestamped report file (`playwright-traces-YYYYMMDD-HHMMSS.txt`) in the current directory.

**What it scans:**
- Browser cache directories
- npm/yarn/pnpm caches
- Global package installations
- nvm installations (all Node versions)
- Known Playwright file locations

## Common Scenarios

### Scenario 1: Fresh Start

You're having issues with Playwright and want to start clean.

```bash
# 1. See what's installed
./tools/find-traces.sh

# 2. Preview removal
./tools/deep-uninstall.sh --dry-run

# 3. Remove everything
./tools/deep-uninstall.sh

# 4. Verify clean state
./tools/find-traces.sh

# 5. Fresh install
./tools/install.sh --browsers all
```

### Scenario 2: Troubleshooting Browser Issues

Browsers aren't launching or behaving correctly.

```bash
# 1. Check current state
./tools/find-traces.sh

# 2. Remove only browser cache (manually)
rm -rf ~/Library/Caches/ms-playwright

# 3. Reinstall browsers
npx playwright install --with-deps
```

### Scenario 3: Disk Space Recovery

Playwright browsers are taking too much space.

```bash
# 1. Check sizes
./tools/find-traces.sh

# 2. Full cleanup
./tools/deep-uninstall.sh

# 3. Reinstall with only needed browser
./tools/install.sh --browsers chromium
```

## File Locations

Playwright stores files in these locations on macOS:

| Type | Location |
|------|----------|
| Browser binaries | `~/Library/Caches/ms-playwright/` |
| npm global packages | `/usr/local/lib/node_modules/` or `~/.npm-global/` |
| npm cache | `~/.npm/` |
| yarn cache | `~/Library/Caches/Yarn/` |
| pnpm store | `~/Library/pnpm/store/` |
| Custom path | `$PLAYWRIGHT_BROWSERS_PATH` |

## Requirements

- **macOS** 10.15 (Catalina) or later
- **Bash** 3.2 or later (included with macOS)
- **Node.js** 16.0.0 or later (for install.sh)
- **npm** 7.0.0 or later (for install.sh)

## Environment Variables

| Variable | Description |
|----------|-------------|
| `PLAYWRIGHT_BROWSERS_PATH` | Custom browser installation path |
| `PLAYWRIGHT_SKIP_BROWSER_GC` | Set to `1` to disable automatic browser cleanup |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Related Resources

- [Playwright Documentation](https://playwright.dev/docs/intro)
- [Playwright GitHub](https://github.com/microsoft/playwright)
- [Playwright Discord](https://aka.ms/playwright-discord)
