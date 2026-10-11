# AGENTS.md - AI Guidance for shell-tools-playwright

This file provides context for AI assistants working on this project.

## Project Overview

macOS utility scripts for complete management of Playwright installations:
- Deep uninstallation with safety mechanisms
- Clean installation with verification
- System-wide trace scanning

## Project Scope: Node.js Only

**This project focuses exclusively on Playwright for Node.js.**

### NOT Covered by This Project

**Other language bindings:**
- **Playwright for Python** - Popular for data scraping, installed via `pip install playwright`
- **Playwright for .NET** - Microsoft ecosystem (C#)
- **Playwright for Java** - Enterprise environments

**Embedded/Hidden Playwright installations:**
These are isolated versions bundled inside other software:
- **VS Code** - The official Playwright extension installs its own components
- **Scraping tools** - Some "turnkey" data extraction tools use Playwright internally
- **Visual testing tools** - Software like Storybook may use Playwright
- **CI/CD tools** - Some testing platforms bundle their own Playwright
- Any other software that embeds Playwright in its own directory

These embedded versions live inside their host application's directory and are completely isolated from your own installations. **We do NOT delete these.**

### Critical Warning: Shared Browser Cache

The browser cache at `~/Library/Caches/ms-playwright/` is **SHARED** between:
- Playwright for Node.js
- Playwright for Python
- Playwright for .NET
- Playwright for Java

**Our scripts WILL delete this shared cache!**

Example: If you have both Playwright Python and Playwright Node.js installed, they share the same Chrome/Firefox/WebKit browsers in `ms-playwright/`. Running `deep-uninstall.sh` will delete these browsers, affecting ALL Playwright installations regardless of language.

## Architecture

```
shell-tools-playwright/
├── tools/                    # Main scripts
│   ├── deep-uninstall.sh    # Complete Playwright removal
│   ├── install.sh           # Clean installation with checks
│   └── find-traces.sh       # System scan for remnants
├── .github/                  # GitHub templates
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
├── jose/                     # Personal/private directory (gitignored)
└── [documentation files]
```

## Playwright File Locations (macOS)

| Component | Path |
|-----------|------|
| Browser cache | `~/Library/Caches/ms-playwright/` |
| Custom path | `$PLAYWRIGHT_BROWSERS_PATH` |
| npm global | `/usr/local/lib/node_modules/playwright*` |
| npm cache | `~/.npm/_cacache/*playwright*` |
| yarn cache | `~/Library/Caches/Yarn/v6/*playwright*` |
| pnpm store | `~/Library/pnpm/store/*playwright*` |

**Important:** On macOS, the cache is `~/Library/Caches/ms-playwright/`, NOT `~/.cache/ms-playwright/` (that's Linux).

## Browser Patterns

Scripts must handle these browser directories in the cache:

```
chromium-*        # Chromium builds
firefox-*         # Firefox builds
webkit-*          # WebKit builds
ffmpeg-*          # FFmpeg for video support
```

## Code Conventions

### File Naming Rules

**Files in `./tools/` and `./jose/` directories:**
- All `.sh`, `.txt`, `.json`, `.md` files MUST use kebab-case
- Examples: `deep-uninstall.sh`, `find-traces.sh`
- Generated files: kebab-case with timestamp (`playwright-traces-20240116-143022.txt`)
- Exception: `jose/PROMPTS.md` stays UPPERCASE

**GitHub files (`.github/` and root):**
- Use the most popular case convention for public open source repositories:
  - `README.md` - UPPERCASE
  - `LICENSE` - UPPERCASE (no extension)
  - `CONTRIBUTING.md` - UPPERCASE
  - `CODE_OF_CONDUCT.md` - SCREAMING_SNAKE_CASE
  - `SECURITY.md` - UPPERCASE
  - `CODEOWNERS` - UPPERCASE (no extension)
  - `PULL_REQUEST_TEMPLATE.md` - SCREAMING_SNAKE_CASE
  - `.github/ISSUE_TEMPLATE/bug_report.md` - snake_case (GitHub default)
  - `.github/ISSUE_TEMPLATE/feature_request.md` - snake_case (GitHub default)
  - `.github/ISSUE_TEMPLATE/config.yml` - lowercase

### Code Naming
- Scripts: kebab-case (`deep-uninstall.sh`)
- Functions/variables: snake_case (`log_info`, `browser_cache`)
- Constants: UPPER_CASE (`BROWSER_CACHE`, `SCRIPT_VERSION`)

### Logging Functions
All scripts use consistent colored output:
```bash
log_info()      # [INFO] - Blue (install) or Cyan (deep-uninstall)
log_success()   # [OK] - Green
log_warning()   # [WARNING] - Yellow
log_error()     # [ERROR] - Red
log_kill()      # [KILL] - Magenta (deep-uninstall only)
log_step()      # [STEP] - Magenta (install only)
log_dry()       # [DRY-RUN] - Dim (deep-uninstall only)
```

### Script Structure
Each script follows this pattern:
1. Constants and color definitions
2. Global variables
3. Logging functions
4. Helper functions
5. Core functionality functions
6. Main function with argument parsing

### Safety Mechanisms
- `deep-uninstall.sh` requires double confirmation + countdown, supports `--dry-run`
- `install.sh` offers cleanup before installation
- `find-traces.sh` is read-only (no deletion, just scanning)

## Package Managers

Scripts handle three package managers:
1. **npm** - Primary, most common
2. **yarn** - Classic and Berry
3. **pnpm** - Content-addressable store

Each has different global package and cache locations.

## Testing Changes

When modifying scripts:
1. Test `--help` and `--version` flags
2. Test `--dry-run` mode (no side effects)
3. Test on clean system (no Playwright)
4. Test on system with Playwright installed
5. Verify color output in terminal

## Common Tasks

### Adding a new scan location to find-traces.sh
1. Add path to `KNOWN_LOCATIONS` array for explicit checks
2. Or add path to `EXCLUDE_DIRS` if it should be skipped
3. The script uses `find` with patterns `*playwright*`, `*ms-playwright*`, `*@playwright*`

### Adding a new removal target to deep-uninstall.sh
1. Create a new `handle_*` function (e.g., `handle_new_cache`)
2. Check if path exists, then call `remove_item "$path" "description"`
3. Add call to your function in `main()` (both scan and removal passes)
4. Update `EXCLUDE_DIRS` if needed
5. Test with `--dry-run` first

### Modifying installation flow
1. Add prerequisite check if needed
2. Update `run_all_checks` function
3. Update verification in `verify_installation`
4. Document in README.md

## Language

Use American English for all:
- Code comments
- User-facing messages
- Documentation
- Commit messages
