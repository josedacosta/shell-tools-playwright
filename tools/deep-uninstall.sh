#!/bin/bash
# =============================================================================
# Playwright Deep Uninstall
# =============================================================================
#
# PLATFORM:     macOS only (uses macOS-specific paths and commands)
# SHELL:        Bash (tested with GNU bash 3.2+)
#
# SCOPE:        Playwright for Node.js ONLY
#
# DESCRIPTION:
#   Completely removes ALL Playwright-related files from macOS:
#   - Downloaded browsers (Chromium, Firefox, WebKit) - the heaviest part!
#   - Global npm/yarn/pnpm packages
#   - Package manager caches (npm, yarn, pnpm)
#   - Temporary files
#
# USAGE:
#   bash deep-uninstall.sh           # Interactive mode
#   bash deep-uninstall.sh --dry-run # Preview without deletion
#
# NOTE:
#   Each Playwright update downloads NEW browser binaries without removing
#   old ones. This is why the cache grows indefinitely and needs cleaning.
#
# =============================================================================
# SCOPE DETAILS
# =============================================================================
#
# This script focuses on Playwright for Node.js (npm/yarn/pnpm).
#
# NOT COVERED (protected from deletion):
#   - Playwright for Python (pip install playwright)
#   - Playwright for .NET (C#)
#   - Playwright for Java
#   - Embedded Playwright installations:
#       * VS Code Playwright extension
#       * Scraping tools that bundle Playwright
#       * Visual testing tools (Storybook, etc.)
#       * Any software with embedded Playwright
#
# These embedded versions live inside their host application's directory
# and are completely isolated from your Node.js installations.
#
# =============================================================================
# WARNING: SHARED BROWSER CACHE
# =============================================================================
#
# The browser cache at ~/Library/Caches/ms-playwright/ is SHARED between:
#   - Playwright for Node.js
#   - Playwright for Python
#   - Playwright for .NET
#   - Playwright for Java
#
# This script WILL DELETE this shared cache! If you have Playwright installed
# for other languages, they will need to reinstall browsers afterward.
#
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

# Playwright browser cache location (macOS)
# NOTE: On Linux it's ~/.cache/ms-playwright, NOT the same!
readonly BROWSER_CACHE="$HOME/Library/Caches/ms-playwright"

# Temporary files location
readonly TEMP_DIR="${TMPDIR:-/tmp}"

# =============================================================================
# IMPORTANT: Directories that are NEVER touched
# =============================================================================
# This script only removes SYSTEM-LEVEL Playwright files (caches, global packages).
# It does NOT touch your projects or their node_modules.
#
# Protected locations (never modified):
#   - $HOME/Projects/          (your development projects)
#   - Any project node_modules (local dependencies stay intact)
#   - Project config files     (playwright.config.ts, etc.)
#   - Test results/reports     (test-results/, playwright-report/)
#
# What IS removed:
#   - ~/Library/Caches/ms-playwright/  (downloaded browsers)
#   - Global npm/yarn/pnpm packages    (playwright installed with -g)
#   - Package manager caches           (not project node_modules!)
#   - Temporary files in $TMPDIR
# =============================================================================

EXCLUDE_DIRS=(
    # User projects (never touched)
    "$HOME/Projects"
    "$HOME/.Trash"
    "$HOME/Downloads"
    "$HOME/IdeaProjects"
    "$HOME/WebstormProjects"
    # Third-party applications (may contain embedded Playwright)
    "$HOME/Applications"
    "/Applications"
    # ==========================================================================
    # PLAYWRIGHT FOR PYTHON - OUT OF SCOPE
    # ==========================================================================
    "/Library/Frameworks/Python.framework"
    "/usr/local/lib/python"
    "/opt/homebrew/lib/python"
    "$HOME/.local/lib/python"
    "$HOME/Library/Python"
    # Python virtual environments
    "$HOME/.virtualenvs"
    "$HOME/.pyenv"
    # ==========================================================================
    # EMBEDDED PLAYWRIGHT INSTALLATIONS - OUT OF SCOPE
    # ==========================================================================
    # VS Code Playwright extension
    "$HOME/.vscode/extensions"
    "$HOME/.vscode-server/extensions"
    # Cursor IDE (VS Code fork)
    "$HOME/.cursor/extensions"
    # ==========================================================================
    # IDE and app configurations
    # ==========================================================================
    "$HOME/.antigravity"
    "$HOME/.cache/github-copilot"
    "$HOME/Library/Application Support/JetBrains"
    "$HOME/Library/Caches/JetBrains"
    "$HOME/Library/Caches/pypoetry"
    "$HOME/Library/Logs/JetBrains"
    # ==========================================================================
    # Claude Code (AI assistant cache - not user Playwright)
    # ==========================================================================
    "$HOME/Library/Caches/claude-cli-nodejs"
    "/private/tmp/claude"
)

# Global state
DRY_RUN=false
ITEMS_FOUND=0
ITEMS_REMOVED=0
TOTAL_SIZE=0

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_kill() {
    echo -e "${MAGENTA}[KILL]${NC} $1"
}

log_dry() {
    echo -e "${DIM}[DRY-RUN]${NC} Would remove: $1"
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

print_header() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                     PLAYWRIGHT DEEP UNINSTALL                            ║${NC}"
    echo -e "${CYAN}${BOLD}║                         (Node.js Only)                                   ║${NC}"
    echo -e "${CYAN}${BOLD}║                     Version: $SCRIPT_VERSION                                        ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}Scope:${NC} Playwright for Node.js only"
    echo -e "${DIM}Not covered: Python/pip, .NET, Java, embedded installations (VS Code, etc.)${NC}"
    echo ""
    echo -e "${RED}${BOLD}⚠ Warning:${NC} Browser cache ~/Library/Caches/ms-playwright/ is SHARED"
    echo -e "${DIM}between Node.js, Python, .NET, and Java. This script WILL delete it!${NC}"
    echo ""
}

print_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
    --dry-run       Preview what would be removed without deleting anything
    --help          Show this help message
    --version       Show version information

Components removed:
    1.  Browser binaries      ~/Library/Caches/ms-playwright (~500MB-2GB)
    2.  npm global packages   playwright, @playwright/test
    3.  yarn global packages  playwright, @playwright/test
    4.  pnpm global packages  playwright, @playwright/test
    5.  npm cache             ~/.npm/_cacache/*playwright*
    6.  yarn cache            ~/Library/Caches/Yarn/*playwright*
    7.  pnpm store            ~/Library/pnpm/store/*playwright*
    8.  Temporary files       \$TMPDIR/*playwright*
    9.  npx cache             ~/.npm/_npx/*playwright*
    10. bun cache             ~/.bun/install/cache/*playwright*
    11. Claude Code cache     ~/.claude/*playwright*
    12. Playwright Go cache   ~/Library/Caches/ms-playwright-go
    13. WebKit data           ~/Library/*/org.webkit.Playwright
    14. System temp caches    /private/var/folders/*playwright*
    15. pnpm metadata         ~/Library/pnpm/store/v10/index/*playwright*
    16. nvm global packages   ~/.nvm/versions/node/*/lib/node_modules/playwright*
    17. Homebrew packages     /opt/homebrew/lib/node_modules/playwright* (Apple Silicon)
    18. Orphaned symlinks     /usr/local/bin/playwright, ~/.yarn/bin/playwright, etc.

NOT removed (protected):
    User directories:
    - \$HOME/Projects/                    Your development projects
    - \$HOME/Downloads/                   Your downloaded files
    - \$HOME/IdeaProjects/                IntelliJ project folder
    - \$HOME/WebstormProjects/            WebStorm project folder
    - \$HOME/Applications/                User apps

    System applications:
    - /Applications/                      Apps with embedded Playwright (GoLand, etc.)

    Playwright for Python (OUT OF SCOPE):
    - /Library/Frameworks/Python.framework
    - \$HOME/.virtualenvs/                Python virtual environments
    - \$HOME/.pyenv/                      pyenv installations

    Embedded Playwright (OUT OF SCOPE):
    - \$HOME/.vscode/extensions/          VS Code Playwright extension
    - \$HOME/.cursor/extensions/          Cursor IDE extensions

    IDE configurations:
    - \$HOME/.antigravity/                Antigravity config
    - \$HOME/.cache/github-copilot/       GitHub Copilot cache
    - \$HOME/Library/Application Support/JetBrains/
    - \$HOME/Library/Caches/JetBrains/
    - \$HOME/Library/Caches/pypoetry/
    - \$HOME/Library/Logs/JetBrains/

    Claude Code (AI assistant):
    - \$HOME/Library/Caches/claude-cli-nodejs/
    - /private/tmp/claude/

Examples:
    $SCRIPT_NAME                    # Interactive removal
    $SCRIPT_NAME --dry-run          # Preview only (recommended first!)

EOF
}

check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is designed for macOS only."
        log_info "Detected OS: $(uname)"
        log_info "On Linux, browser cache is at: ~/.cache/ms-playwright"
        exit 1
    fi
}

format_size() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc) MB"
    elif [[ $bytes -ge 1024 ]]; then
        echo "$(echo "scale=2; $bytes / 1024" | bc) KB"
    else
        echo "$bytes bytes"
    fi
}

get_dir_size() {
    local dir=$1
    if [[ -d "$dir" ]]; then
        local kb
        kb=$(du -sk "$dir" 2>/dev/null | cut -f1)
        echo $((kb * 1024))
    else
        echo 0
    fi
}

# Check if a path is inside an excluded directory
is_excluded() {
    local path=$1
    for excluded in "${EXCLUDE_DIRS[@]}"; do
        # Check if path starts with excluded directory
        if [[ "$path" == "$excluded"* ]]; then
            return 0  # true, is excluded
        fi
    done
    return 1  # false, not excluded
}

remove_item() {
    local item=$1
    local description=$2

    # Check if item is in an excluded directory
    if is_excluded "$item"; then
        echo -e "   ${GREEN}✓${NC} Skipped (protected): $item"
        return
    fi

    if [[ -e "$item" ]]; then
        local size
        size=$(get_dir_size "$item")
        TOTAL_SIZE=$((TOTAL_SIZE + size))

        if $DRY_RUN; then
            log_dry "$item ($(format_size "$size")) - $description"
        else
            rm -rf "$item"
            log_kill "$item ($(format_size "$size")) - $description"
            ((ITEMS_REMOVED++)) || true
        fi
        ((ITEMS_FOUND++)) || true
    fi
}

# =============================================================================
# DETECTION & REMOVAL FUNCTIONS
# =============================================================================

# 1. Browser binaries (THE HEAVIEST PART - 500MB to several GB)
handle_browser_cache() {
    echo ""
    echo -e "${BOLD}1. Browser Binaries${NC} ${DIM}(~/Library/Caches/ms-playwright)${NC}"
    echo ""

    # Try official uninstall command first (recommended by Playwright docs)
    if command -v npx &> /dev/null; then
        if $DRY_RUN; then
            log_dry "npx playwright uninstall --all"
        else
            echo "   Running official uninstall command..."
            npx playwright uninstall --all 2>/dev/null || true
        fi
    fi

    # Check custom path first
    local cache_path="$BROWSER_CACHE"
    if [[ -n "${PLAYWRIGHT_BROWSERS_PATH:-}" ]]; then
        cache_path="$PLAYWRIGHT_BROWSERS_PATH"
        log_info "Custom PLAYWRIGHT_BROWSERS_PATH detected: $cache_path"
    fi

    if [[ -d "$cache_path" ]]; then
        echo "   Found browsers:"
        for browser_dir in "$cache_path"/*; do
            if [[ -d "$browser_dir" ]]; then
                local name size
                name=$(basename "$browser_dir")
                size=$(get_dir_size "$browser_dir")
                echo -e "     ${RED}→${NC} $name ($(format_size "$size"))"
            fi
        done
        echo ""
        remove_item "$cache_path" "Browser cache"
    else
        echo -e "   ${GREEN}✓${NC} No browser cache found"
    fi

    # Check for hermetic installation (PLAYWRIGHT_BROWSERS_PATH=0)
    # This installs browsers in node_modules/playwright-core/.local-browsers
    local hermetic_path="./node_modules/playwright-core/.local-browsers"
    if [[ -d "$hermetic_path" ]]; then
        echo ""
        echo "   Found hermetic installation:"
        remove_item "$hermetic_path" "Hermetic browsers (node_modules)"
    fi
}

# 2. npm global packages
handle_npm_global() {
    echo ""
    echo -e "${BOLD}2. npm Global Packages${NC}"
    echo ""

    if ! command -v npm &> /dev/null; then
        echo -e "   ${DIM}npm not installed, skipping${NC}"
        return
    fi

    local packages
    packages=$(npm list -g --depth=0 2>/dev/null | grep -i "playwright" || true)

    if [[ -n "$packages" ]]; then
        echo "$packages" | while read -r line; do
            echo -e "     ${RED}→${NC} $line"
        done
        echo ""

        # Get package names for removal
        local pkg_names
        pkg_names=$(npm list -g --depth=0 --json 2>/dev/null | grep -o '"@playwright[^"]*"\|"playwright[^"]*"' | tr -d '"' || true)

        if [[ -n "$pkg_names" ]]; then
            echo "$pkg_names" | while read -r pkg; do
                if $DRY_RUN; then
                    log_dry "npm uninstall -g $pkg"
                else
                    npm uninstall -g "$pkg" 2>/dev/null || true
                    log_kill "npm uninstall -g $pkg"
                fi
                ((ITEMS_FOUND++)) || true
            done
        fi
    else
        echo -e "   ${GREEN}✓${NC} No global packages found"
    fi
}

# 3. yarn global packages
handle_yarn_global() {
    echo ""
    echo -e "${BOLD}3. yarn Global Packages${NC}"
    echo ""

    if ! command -v yarn &> /dev/null; then
        echo -e "   ${DIM}yarn not installed, skipping${NC}"
        return
    fi

    local packages
    packages=$(yarn global list 2>/dev/null | grep -i "playwright" || true)

    if [[ -n "$packages" ]]; then
        echo "$packages" | while read -r line; do
            echo -e "     ${RED}→${NC} $line"
        done
        echo ""

        local pkg_names
        pkg_names=$(echo "$packages" | grep -o '@playwright[^ ]*\|playwright[^ ]*' || true)

        if [[ -n "$pkg_names" ]]; then
            echo "$pkg_names" | while read -r pkg; do
                if $DRY_RUN; then
                    log_dry "yarn global remove $pkg"
                else
                    yarn global remove "$pkg" 2>/dev/null || true
                    log_kill "yarn global remove $pkg"
                fi
                ((ITEMS_FOUND++)) || true
            done
        fi
    else
        echo -e "   ${GREEN}✓${NC} No global packages found"
    fi
}

# 4. pnpm global packages
handle_pnpm_global() {
    echo ""
    echo -e "${BOLD}4. pnpm Global Packages${NC}"
    echo ""

    if ! command -v pnpm &> /dev/null; then
        echo -e "   ${DIM}pnpm not installed, skipping${NC}"
        return
    fi

    local packages
    packages=$(pnpm list -g 2>/dev/null | grep -i "playwright" || true)

    if [[ -n "$packages" ]]; then
        echo "$packages" | while read -r line; do
            echo -e "     ${RED}→${NC} $line"
        done
        echo ""

        local pkg_names
        pkg_names=$(echo "$packages" | grep -o '@playwright[^ ]*\|playwright[^ ]*' || true)

        if [[ -n "$pkg_names" ]]; then
            echo "$pkg_names" | while read -r pkg; do
                if $DRY_RUN; then
                    log_dry "pnpm remove -g $pkg"
                else
                    pnpm remove -g "$pkg" 2>/dev/null || true
                    log_kill "pnpm remove -g $pkg"
                fi
                ((ITEMS_FOUND++)) || true
            done
        fi
    else
        echo -e "   ${GREEN}✓${NC} No global packages found"
    fi
}

# 5. npm cache
handle_npm_cache() {
    echo ""
    echo -e "${BOLD}5. npm Cache${NC}"
    echo ""

    if ! command -v npm &> /dev/null; then
        echo -e "   ${DIM}npm not installed, skipping${NC}"
        return
    fi

    local cache_dir
    cache_dir=$(npm config get cache 2>/dev/null)

    if [[ -d "$cache_dir" ]]; then
        local entries
        entries=$(find "$cache_dir" -maxdepth 4 -type d -name "*playwright*" 2>/dev/null | head -20 || true)

        if [[ -n "$entries" ]]; then
            echo "$entries" | while read -r entry; do
                remove_item "$entry" "npm cache"
            done
        else
            echo -e "   ${GREEN}✓${NC} No Playwright entries in npm cache"
        fi
    fi
}

# 6. yarn cache
handle_yarn_cache() {
    echo ""
    echo -e "${BOLD}6. yarn Cache${NC} ${DIM}(~/Library/Caches/Yarn)${NC}"
    echo ""

    if ! command -v yarn &> /dev/null; then
        echo -e "   ${DIM}yarn not installed, skipping${NC}"
        return
    fi

    local cache_dir
    cache_dir=$(yarn cache dir 2>/dev/null || echo "$HOME/Library/Caches/Yarn")

    if [[ -d "$cache_dir" ]]; then
        local entries
        entries=$(find "$cache_dir" -maxdepth 4 -type d -name "*playwright*" 2>/dev/null | head -20 || true)

        if [[ -n "$entries" ]]; then
            echo "$entries" | while read -r entry; do
                remove_item "$entry" "yarn cache"
            done
        else
            echo -e "   ${GREEN}✓${NC} No Playwright entries in yarn cache"
        fi
    fi
}

# 7. pnpm store
handle_pnpm_store() {
    echo ""
    echo -e "${BOLD}7. pnpm Store${NC} ${DIM}(~/Library/pnpm/store)${NC}"
    echo ""

    if ! command -v pnpm &> /dev/null; then
        echo -e "   ${DIM}pnpm not installed, skipping${NC}"
        return
    fi

    local store_dir
    store_dir=$(pnpm store path 2>/dev/null || echo "$HOME/Library/pnpm/store")

    if [[ -d "$store_dir" ]]; then
        local entries
        entries=$(find "$store_dir" -maxdepth 4 -type d -name "*playwright*" 2>/dev/null | head -20 || true)

        if [[ -n "$entries" ]]; then
            echo "$entries" | while read -r entry; do
                remove_item "$entry" "pnpm store"
            done
        else
            echo -e "   ${GREEN}✓${NC} No Playwright entries in pnpm store"
        fi
    fi
}

# 8. Temporary files
handle_temp_files() {
    echo ""
    echo -e "${BOLD}8. Temporary Files${NC} ${DIM}(\$TMPDIR)${NC}"
    echo ""

    if [[ -d "$TEMP_DIR" ]]; then
        local entries
        entries=$(find "$TEMP_DIR" -maxdepth 2 -name "*playwright*" 2>/dev/null | head -20 || true)

        if [[ -n "$entries" ]]; then
            echo "$entries" | while read -r entry; do
                remove_item "$entry" "temp file"
            done
        else
            echo -e "   ${GREEN}✓${NC} No Playwright temp files found"
        fi
    fi
}

# 9. npm npx cache
handle_npx_cache() {
    echo ""
    echo -e "${BOLD}9. npm npx Cache${NC} ${DIM}(~/.npm/_npx)${NC}"
    echo ""

    local npx_cache="$HOME/.npm/_npx"

    if [[ -d "$npx_cache" ]]; then
        local entries
        entries=$(find "$npx_cache" -type d -name "*playwright*" 2>/dev/null | head -20 || true)

        if [[ -n "$entries" ]]; then
            echo "$entries" | while read -r entry; do
                remove_item "$entry" "npx cache"
            done
        else
            echo -e "   ${GREEN}✓${NC} No Playwright entries in npx cache"
        fi
    else
        echo -e "   ${DIM}npx cache not found, skipping${NC}"
    fi
}

# 10. bun cache
handle_bun_cache() {
    echo ""
    echo -e "${BOLD}10. bun Cache${NC} ${DIM}(~/.bun/install/cache)${NC}"
    echo ""

    local bun_cache="$HOME/.bun/install/cache"

    if [[ -d "$bun_cache" ]]; then
        local entries
        entries=$(find "$bun_cache" -maxdepth 2 -type d -name "*playwright*" 2>/dev/null | head -20 || true)

        if [[ -n "$entries" ]]; then
            echo "$entries" | while read -r entry; do
                remove_item "$entry" "bun cache"
            done
        else
            echo -e "   ${GREEN}✓${NC} No Playwright entries in bun cache"
        fi
    else
        echo -e "   ${DIM}bun cache not found, skipping${NC}"
    fi
}

# 11. Claude Code cache/plugins
handle_claude_cache() {
    echo ""
    echo -e "${BOLD}11. Claude Code Cache${NC} ${DIM}(~/.claude)${NC}"
    echo ""

    local claude_dir="$HOME/.claude"

    if [[ -d "$claude_dir" ]]; then
        local entries
        entries=$(find "$claude_dir" -name "*playwright*" 2>/dev/null | head -20 || true)

        if [[ -n "$entries" ]]; then
            echo "$entries" | while read -r entry; do
                remove_item "$entry" "Claude cache"
            done
        else
            echo -e "   ${GREEN}✓${NC} No Playwright entries in Claude cache"
        fi
    else
        echo -e "   ${DIM}Claude directory not found, skipping${NC}"
    fi
}

# 12. Playwright for Go language
handle_playwright_go() {
    echo ""
    echo -e "${BOLD}12. Playwright Go Cache${NC} ${DIM}(~/Library/Caches/ms-playwright-go)${NC}"
    echo ""

    local go_cache="$HOME/Library/Caches/ms-playwright-go"

    if [[ -d "$go_cache" ]]; then
        remove_item "$go_cache" "Playwright Go browser cache"
    else
        echo -e "   ${GREEN}✓${NC} No Playwright Go cache found"
    fi
}

# 13. WebKit Playwright caches and data
handle_webkit_playwright() {
    echo ""
    echo -e "${BOLD}13. WebKit Playwright Data${NC} ${DIM}(org.webkit.Playwright)${NC}"
    echo ""

    local found=false

    # WebKit cache
    local webkit_cache="$HOME/Library/Caches/org.webkit.Playwright"
    if [[ -d "$webkit_cache" ]]; then
        remove_item "$webkit_cache" "WebKit Playwright cache"
        found=true
    fi

    # WebKit preferences
    local webkit_prefs="$HOME/Library/Preferences/org.webkit.Playwright.plist"
    if [[ -f "$webkit_prefs" ]]; then
        remove_item "$webkit_prefs" "WebKit Playwright preferences"
        found=true
    fi

    # WebKit data
    local webkit_data="$HOME/Library/WebKit/org.webkit.Playwright"
    if [[ -d "$webkit_data" ]]; then
        remove_item "$webkit_data" "WebKit Playwright data"
        found=true
    fi

    if ! $found; then
        echo -e "   ${GREEN}✓${NC} No WebKit Playwright data found"
    fi
}

# 14. System temp folders (private/var/folders)
handle_system_temp() {
    echo ""
    echo -e "${BOLD}14. System Temp Caches${NC} ${DIM}(/private/var/folders)${NC}"
    echo ""

    local var_folders="/private/var/folders"

    if [[ -d "$var_folders" ]]; then
        local entries
        entries=$(find "$var_folders" -maxdepth 5 -name "*org.webkit.Playwright*" -o -name "*ms-playwright*" 2>/dev/null | head -20 || true)

        if [[ -n "$entries" ]]; then
            echo "$entries" | while read -r entry; do
                remove_item "$entry" "system temp cache"
            done
        else
            echo -e "   ${GREEN}✓${NC} No Playwright entries in system temp"
        fi
    else
        echo -e "   ${DIM}System temp folders not accessible, skipping${NC}"
    fi
}

# 15. pnpm metadata index
handle_pnpm_metadata() {
    echo ""
    echo -e "${BOLD}15. pnpm Metadata Index${NC} ${DIM}(~/Library/pnpm/store/v10/index)${NC}"
    echo ""

    local pnpm_index="$HOME/Library/pnpm/store/v10/index"

    if [[ -d "$pnpm_index" ]]; then
        local entries
        entries=$(find "$pnpm_index" -name "*playwright*" 2>/dev/null | head -20 || true)

        if [[ -n "$entries" ]]; then
            echo "$entries" | while read -r entry; do
                remove_item "$entry" "pnpm metadata"
            done
        else
            echo -e "   ${GREEN}✓${NC} No Playwright entries in pnpm metadata"
        fi
    else
        echo -e "   ${DIM}pnpm metadata index not found, skipping${NC}"
    fi
}

# 16. nvm global packages (each Node version has its own)
handle_nvm_global() {
    echo ""
    echo -e "${BOLD}16. nvm Global Packages${NC} ${DIM}(~/.nvm/versions/node/*/lib/node_modules)${NC}"
    echo ""

    local nvm_dir="${NVM_DIR:-$HOME/.nvm}"

    if [[ ! -d "$nvm_dir/versions/node" ]]; then
        echo -e "   ${DIM}nvm not installed or no Node versions, skipping${NC}"
        return
    fi

    local found=false
    for node_version in "$nvm_dir/versions/node"/*; do
        if [[ -d "$node_version/lib/node_modules" ]]; then
            local version_name
            version_name=$(basename "$node_version")

            for pkg in playwright playwright-core @playwright; do
                local pkg_path="$node_version/lib/node_modules/$pkg"
                if [[ -d "$pkg_path" ]]; then
                    echo -e "     ${RED}→${NC} Node $version_name: $pkg"
                    if $DRY_RUN; then
                        log_dry "rm -rf $pkg_path"
                    else
                        rm -rf "$pkg_path"
                        log_kill "$pkg_path"
                    fi
                    ((ITEMS_FOUND++)) || true
                    found=true
                fi
            done
        fi
    done

    if ! $found; then
        echo -e "   ${GREEN}✓${NC} No Playwright packages in any nvm Node version"
    fi
}

# 17. Homebrew paths (Apple Silicon vs Intel)
handle_homebrew_paths() {
    echo ""
    echo -e "${BOLD}17. Homebrew Global Packages${NC} ${DIM}(/opt/homebrew or /usr/local)${NC}"
    echo ""

    local found=false

    # Determine Homebrew prefix
    local brew_prefixes=("/opt/homebrew" "/usr/local")

    for brew_prefix in "${brew_prefixes[@]}"; do
        if [[ -d "$brew_prefix/lib/node_modules" ]]; then
            for pkg in playwright playwright-core @playwright; do
                local pkg_path="$brew_prefix/lib/node_modules/$pkg"
                if [[ -d "$pkg_path" ]]; then
                    echo -e "     ${RED}→${NC} $pkg_path"
                    remove_item "$pkg_path" "Homebrew global package"
                    found=true
                fi
            done
        fi
    done

    if ! $found; then
        echo -e "   ${GREEN}✓${NC} No Playwright packages in Homebrew paths"
    fi
}

# 18. Orphaned symlinks
handle_orphaned_symlinks() {
    echo ""
    echo -e "${BOLD}18. Orphaned Symlinks${NC} ${DIM}(binary symlinks)${NC}"
    echo ""

    local symlink_locations=(
        "/usr/local/bin/playwright"
        "/opt/homebrew/bin/playwright"
        "$HOME/.yarn/bin/playwright"
        "$HOME/Library/pnpm/playwright"
    )

    local found=false

    for symlink in "${symlink_locations[@]}"; do
        # Check if it's a symlink (broken or not)
        if [[ -L "$symlink" ]]; then
            # Check if it's broken (target doesn't exist)
            if [[ ! -e "$symlink" ]]; then
                echo -e "     ${RED}→${NC} Broken symlink: $symlink"
                if $DRY_RUN; then
                    log_dry "rm $symlink"
                else
                    rm "$symlink"
                    log_kill "$symlink (broken symlink)"
                fi
                ((ITEMS_FOUND++)) || true
                found=true
            else
                # Symlink exists and target exists - check if target is playwright
                local target
                target=$(readlink "$symlink" 2>/dev/null || true)
                if [[ "$target" == *"playwright"* ]]; then
                    echo -e "     ${RED}→${NC} Active symlink: $symlink -> $target"
                    if $DRY_RUN; then
                        log_dry "rm $symlink"
                    else
                        rm "$symlink"
                        log_kill "$symlink (symlink)"
                    fi
                    ((ITEMS_FOUND++)) || true
                    found=true
                fi
            fi
        elif [[ -f "$symlink" ]]; then
            # Not a symlink but a file named playwright
            echo -e "     ${RED}→${NC} Binary file: $symlink"
            remove_item "$symlink" "playwright binary"
            found=true
        fi
    done

    if ! $found; then
        echo -e "   ${GREEN}✓${NC} No orphaned playwright symlinks found"
    fi
}

# =============================================================================
# CONFIRMATION
# =============================================================================

confirm_removal() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║                       WARNING - DESTRUCTIVE ACTION                       ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "This will permanently remove all Playwright-related files."
    echo "This action CANNOT be undone."
    echo ""
    echo -e "Estimated space to recover: ${GREEN}$(format_size "$TOTAL_SIZE")${NC}"
    echo ""
    echo -e "${YELLOW}Type 'YES' to confirm:${NC}"
    read -r confirmation

    if [[ "$confirmation" != "YES" ]]; then
        log_info "Aborted by user."
        exit 0
    fi

    echo ""
    echo -e "${YELLOW}Type 'DELETE PLAYWRIGHT' to proceed:${NC}"
    read -r final_confirmation

    if [[ "$final_confirmation" != "DELETE PLAYWRIGHT" ]]; then
        log_info "Aborted by user."
        exit 0
    fi

    echo ""
    log_warning "Starting removal in 5 seconds... Press Ctrl+C to cancel."
    for i in 5 4 3 2 1; do
        echo -ne "\r   Countdown: $i "
        sleep 1
    done
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            --version)
                echo "$SCRIPT_NAME version $SCRIPT_VERSION"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    print_header
    check_macos

    if $DRY_RUN; then
        echo -e "${CYAN}${BOLD}>>> DRY-RUN MODE - No files will be deleted <<<${NC}"
        echo ""
    fi

    # Show protected directories
    echo -e "${BOLD}Configuration:${NC}"
    echo ""
    echo -e "  ${GREEN}${BOLD}Protected locations (never touched):${NC}"
    for dir in "${EXCLUDE_DIRS[@]}"; do
        echo -e "    ${GREEN}✓${NC} $dir"
    done
    echo -e "    ${GREEN}✓${NC} Project node_modules/ ${DIM}(local dependencies)${NC}"
    echo -e "    ${GREEN}✓${NC} Project configs ${DIM}(playwright.config.ts, etc.)${NC}"
    echo ""
    echo -e "  ${RED}${BOLD}Will be removed:${NC}"
    echo -e "    ${RED}✗${NC} ~/Library/Caches/ms-playwright/ ${DIM}(browsers ~500MB-2GB)${NC}"
    echo -e "    ${RED}✗${NC} ~/Library/Caches/ms-playwright-go/ ${DIM}(Go language browsers)${NC}"
    echo -e "    ${RED}✗${NC} Global packages ${DIM}(npm -g, yarn global, pnpm -g)${NC}"
    echo -e "    ${RED}✗${NC} nvm global packages ${DIM}(all Node versions)${NC}"
    echo -e "    ${RED}✗${NC} Homebrew packages ${DIM}(/opt/homebrew or /usr/local)${NC}"
    echo -e "    ${RED}✗${NC} Package manager caches ${DIM}(npm, yarn, pnpm, npx, bun)${NC}"
    echo -e "    ${RED}✗${NC} Claude Code cache ${DIM}(~/.claude/*playwright*)${NC}"
    echo -e "    ${RED}✗${NC} WebKit Playwright ${DIM}(caches, prefs, data)${NC}"
    echo -e "    ${RED}✗${NC} System temp caches ${DIM}(/private/var/folders)${NC}"
    echo -e "    ${RED}✗${NC} Temporary files ${DIM}(\$TMPDIR)${NC}"
    echo -e "    ${RED}✗${NC} Orphaned symlinks ${DIM}(bin/playwright)${NC}"
    echo ""

    echo -e "${BOLD}Scanning for Playwright components...${NC}"

    # Run all detection/removal handlers
    handle_browser_cache
    handle_npm_global
    handle_yarn_global
    handle_pnpm_global
    handle_npm_cache
    handle_yarn_cache
    handle_pnpm_store
    handle_temp_files
    handle_npx_cache
    handle_bun_cache
    handle_claude_cache
    handle_playwright_go
    handle_webkit_playwright
    handle_system_temp
    handle_pnpm_metadata
    handle_nvm_global
    handle_homebrew_paths
    handle_orphaned_symlinks

    # Summary
    echo ""
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Summary:${NC}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    if [[ $ITEMS_FOUND -eq 0 ]]; then
        echo -e "   ${GREEN}${BOLD}✓ No Playwright components found. System is clean!${NC}"
        echo ""
        exit 0
    fi

    echo -e "   Items found:    ${YELLOW}$ITEMS_FOUND${NC}"
    echo -e "   Total size:     ${YELLOW}$(format_size "$TOTAL_SIZE")${NC}"
    echo ""

    if $DRY_RUN; then
        echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}   This was a dry-run. No files were deleted.${NC}"
        echo -e "${CYAN}   Run without --dry-run to perform actual removal.${NC}"
        echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
    else
        # Reset counters and run again with actual removal
        ITEMS_FOUND=0
        ITEMS_REMOVED=0
        TOTAL_SIZE=0

        # First pass to calculate total size
        handle_browser_cache
        handle_npm_global
        handle_yarn_global
        handle_pnpm_global
        handle_npm_cache
        handle_yarn_cache
        handle_pnpm_store
        handle_temp_files
        handle_npx_cache
        handle_bun_cache
        handle_claude_cache
        handle_playwright_go
        handle_webkit_playwright
        handle_system_temp
        handle_pnpm_metadata
        handle_nvm_global
        handle_homebrew_paths
        handle_orphaned_symlinks

        confirm_removal

        # Second pass with actual removal
        DRY_RUN=false
        handle_browser_cache
        handle_npm_global
        handle_yarn_global
        handle_pnpm_global
        handle_npm_cache
        handle_yarn_cache
        handle_pnpm_store
        handle_temp_files
        handle_npx_cache
        handle_bun_cache
        handle_claude_cache
        handle_playwright_go
        handle_webkit_playwright
        handle_system_temp
        handle_pnpm_metadata
        handle_nvm_global
        handle_homebrew_paths
        handle_orphaned_symlinks

        echo ""
        echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}${BOLD}   ✓ Playwright uninstallation complete!${NC}"
        echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "   Next steps:"
        echo "     1. Run 'find-traces.sh' to verify complete removal"
        echo "     2. Run 'install.sh' for a fresh installation"
        echo ""
    fi
}

main "$@"
