#!/bin/bash
# =============================================================================
# Playwright Traces Finder
# =============================================================================
#
# PLATFORM:     macOS only (uses macOS-specific paths and commands)
# SHELL:        Bash (tested with GNU bash 3.2+)
#
# SCOPE:        Playwright for Node.js ONLY
#
# DESCRIPTION:
#   Scans the entire macOS filesystem to find all remaining files and folders
#   associated with Playwright for Node.js. Useful for verifying a complete
#   uninstall or diagnosing issues with residual files.
#
# USAGE:
#   bash find-traces.sh    # Run scan
#
# OUTPUT:
#   - Displays results in the terminal with color highlighting
#   - Exports a plain text report (.txt) for easy sharing with LLMs
#
# =============================================================================
# SCOPE DETAILS
# =============================================================================
#
# This script focuses on Playwright for Node.js (npm/yarn/pnpm).
#
# NOT COVERED (excluded from scan):
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
# This script WILL find and report this shared cache. If you delete it,
# ALL Playwright installations (regardless of language) will need to
# reinstall browsers.
#
# =============================================================================

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
# OUTPUT FILE SETUP
# =============================================================================

# Create output directory and file (save in current working directory)
OUTPUT_DIR="$(pwd)"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
OUTPUT_FILE="$OUTPUT_DIR/playwright-traces-${TIMESTAMP}.txt"

# =============================================================================
# CONFIGURATION
# =============================================================================

# Directories to search
SEARCH_DIRS=(
    "/"
)

# Directories to exclude from search
# =============================================================================
# These directories are excluded because they contain:
# - User projects (we don't touch your code)
# - Playwright for Python (pip) - OUT OF SCOPE
# - Playwright for .NET/Java - OUT OF SCOPE
# - Embedded Playwright (VS Code, Storybook, etc.) - OUT OF SCOPE
# - Third-party applications that bundle Playwright
# - IDE configurations and caches
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

# Playwright-specific patterns
PATTERNS=(
    "*playwright*"
    "*ms-playwright*"
    "*@playwright*"
)

# Known specific locations to always check (from reverse-engineer reports)
# These are checked explicitly even if not found by general search
KNOWN_LOCATIONS=(
    # Browser cache (main location ~1GB)
    "$HOME/Library/Caches/ms-playwright"
    "$HOME/Library/Caches/ms-playwright-go"
    # npm global
    "/usr/local/lib/node_modules/playwright"
    "/usr/local/lib/node_modules/playwright-core"
    "/usr/local/lib/node_modules/@playwright"
    "/usr/local/bin/playwright"
    # Homebrew Apple Silicon
    "/opt/homebrew/lib/node_modules/playwright"
    "/opt/homebrew/lib/node_modules/playwright-core"
    "/opt/homebrew/lib/node_modules/@playwright"
    "/opt/homebrew/bin/playwright"
    # Yarn global (Classic v1)
    "$HOME/.config/yarn/global/node_modules/playwright"
    "$HOME/.config/yarn/global/node_modules/playwright-core"
    "$HOME/.config/yarn/global/node_modules/@playwright"
    "$HOME/.yarn/bin/playwright"
    # Yarn Berry (v2+)
    "$HOME/.yarn/berry/global"
    # pnpm global
    "$HOME/Library/pnpm/global/5/node_modules/playwright"
    "$HOME/Library/pnpm/global/5/node_modules/playwright-core"
    "$HOME/Library/pnpm/global/5/node_modules/@playwright"
    "$HOME/Library/pnpm/playwright"
    # WebKit Playwright
    "$HOME/Library/Caches/org.webkit.Playwright"
    "$HOME/Library/Preferences/org.webkit.Playwright.plist"
    "$HOME/Library/WebKit/org.webkit.Playwright"
    # npx cache
    "$HOME/.npm/_npx"
    # bun cache
    "$HOME/.bun/install/cache"
)

# =============================================================================
# NOTE: VS Code Playwright extension is NOT included
# =============================================================================
# The VS Code Playwright extension (ms-playwright.playwright) is considered
# an "embedded" installation that lives inside VS Code's directory.
# We do NOT scan or delete embedded Playwright installations.
# =============================================================================

# =============================================================================
# HEADER
# =============================================================================
clear
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║                       PLAYWRIGHT TRACES FINDER                           ║${NC}"
echo -e "${CYAN}${BOLD}║                         (Node.js Only)                                   ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# SCOPE NOTICE
# =============================================================================
echo -e "${YELLOW}${BOLD}Scope:${NC} Playwright for Node.js only"
echo -e "${DIM}Not covered: Python/pip, .NET, Java, embedded installations (VS Code, etc.)${NC}"
echo ""
echo -e "${YELLOW}${BOLD}⚠ Warning:${NC} Browser cache ~/Library/Caches/ms-playwright/ is SHARED"
echo -e "${DIM}between Node.js, Python, .NET, and Java. Deleting it affects ALL languages.${NC}"
echo ""

# =============================================================================
# DISPLAY CONFIGURATION
# =============================================================================
echo -e "${BOLD}Configuration:${NC}"
echo ""
echo -e "  ${GREEN}${BOLD}Search locations:${NC}"
for dir in "${SEARCH_DIRS[@]}"; do
    if [[ "$dir" == "/" ]]; then
        echo -e "    ${GREEN}✓${NC} ${BOLD}/${NC} ${DIM}(entire system)${NC}"
    else
        echo -e "    ${GREEN}✓${NC} $dir"
    fi
done
echo ""
echo -e "  ${RED}${BOLD}Excluded locations:${NC}"
for dir in "${EXCLUDE_DIRS[@]}"; do
    echo -e "    ${RED}✗${NC} $dir"
done
echo ""
echo -e "  ${MAGENTA}${BOLD}Search patterns:${NC}"
for pattern in "${PATTERNS[@]}"; do
    echo -e "    ${MAGENTA}?${NC} $pattern"
done
echo ""
echo -e "  ${YELLOW}${BOLD}Known locations checked:${NC} ${DIM}${#KNOWN_LOCATIONS[@]} specific paths${NC}"
echo ""

# =============================================================================
# RUN SEARCH
# =============================================================================
echo -e "${YELLOW}${BOLD}Starting search...${NC}"
echo -e "${DIM}This may take several minutes depending on your disk size.${NC}"
echo ""

START=$(date +%s)

# Create temporary file for results
RESULTS_FILE=$(mktemp)

# Function to check if path should be excluded
is_excluded() {
    local path="$1"
    for excluded in "${EXCLUDE_DIRS[@]}"; do
        if [[ "$path" == "$excluded"* ]]; then
            return 0  # true, is excluded
        fi
    done
    return 1  # false, not excluded
}

# First, check known locations explicitly (fast check)
echo -e "${DIM}Checking known locations...${NC}"
for location in "${KNOWN_LOCATIONS[@]}"; do
    if [[ -e "$location" ]] && ! is_excluded "$location"; then
        echo "$location"
    fi
done > "$RESULTS_FILE"

# Also check for nvm installations (multiple Node versions)
if [[ -d "$HOME/.nvm/versions/node" ]]; then
    for node_version in "$HOME/.nvm/versions/node"/*; do
        if [[ -d "$node_version/lib/node_modules" ]]; then
            for pkg in playwright playwright-core @playwright; do
                local_path="$node_version/lib/node_modules/$pkg"
                if [[ -d "$local_path" ]] && ! is_excluded "$local_path"; then
                    echo "$local_path" >> "$RESULTS_FILE"
                fi
            done
        fi
    done
fi

# Run find and filter results (general search)
echo -e "${DIM}Running full system scan...${NC}"
for search_dir in "${SEARCH_DIRS[@]}"; do
    find "$search_dir" \
        -path "$HOME/.Trash" -prune -o \
        -path "/System/Volumes/Data" -prune -o \
        -path "/System" -prune -o \
        -path "/private/var/db" -prune -o \
        -path "/private/var/folders/zz" -prune -o \
        \( -iname "*playwright*" -o -iname "*ms-playwright*" -o -iname "*@playwright*" \) \
        -print 2>/dev/null
done | while IFS= read -r line; do
    # Filter out excluded directories
    if ! is_excluded "$line"; then
        echo "$line"
    fi
done >> "$RESULTS_FILE"

# Remove duplicates and sort
sort -u "$RESULTS_FILE" -o "$RESULTS_FILE"

END=$(date +%s)
DURATION=$((END - START))

# =============================================================================
# DISPLAY RESULTS
# =============================================================================
RESULT_COUNT=$(wc -l < "$RESULTS_FILE" | tr -d ' ')
SCAN_DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Results:${NC}"
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# =============================================================================
# WRITE TO OUTPUT FILE (plain text for LLM consumption)
# =============================================================================
{
    echo "==============================================================================="
    echo "PLAYWRIGHT TRACES FINDER - SCAN REPORT"
    echo "==============================================================================="
    echo ""
    echo "Scope:          Playwright for Node.js ONLY"
    echo "Scan date:      $SCAN_DATE"
    echo "Scan duration:  ${DURATION}s"
    echo "Files found:    $RESULT_COUNT"
    echo ""
    echo "==============================================================================="
    echo "SCOPE INFORMATION"
    echo "==============================================================================="
    echo ""
    echo "This report covers Playwright for Node.js (npm/yarn/pnpm) installations."
    echo ""
    echo "NOT COVERED (excluded from scan):"
    echo "  - Playwright for Python (pip install playwright)"
    echo "  - Playwright for .NET (C#)"
    echo "  - Playwright for Java"
    echo "  - Embedded Playwright (VS Code extension, Storybook, scraping tools, etc.)"
    echo ""
    echo "WARNING: SHARED BROWSER CACHE"
    echo "  The browser cache ~/Library/Caches/ms-playwright/ is SHARED between"
    echo "  Node.js, Python, .NET, and Java. Deleting it affects ALL languages."
    echo ""
    echo "==============================================================================="
    echo "SEARCH CONFIGURATION"
    echo "==============================================================================="
    echo ""
    echo "Search patterns used:"
    for pattern in "${PATTERNS[@]}"; do
        echo "  - $pattern"
    done
    echo ""
    echo "Excluded directories:"
    for dir in "${EXCLUDE_DIRS[@]}"; do
        echo "  - $dir"
    done
    echo ""
    echo "Known locations checked (${#KNOWN_LOCATIONS[@]} paths):"
    for loc in "${KNOWN_LOCATIONS[@]}"; do
        echo "  - $loc"
    done
    echo ""
    echo "nvm installations checked: ~/.nvm/versions/node/*/lib/node_modules/playwright*"
    echo ""
    echo "==============================================================================="
    echo "RESULTS"
    echo "==============================================================================="
    echo ""
    if [[ $RESULT_COUNT -eq 0 ]]; then
        echo "No Playwright traces found. The system is clean."
    else
        echo "Found $RESULT_COUNT file(s)/folder(s) related to Playwright:"
        echo ""
        while IFS= read -r line; do
            if [[ "$line" != /System/Volumes/Data/* ]]; then
                echo "$line"
            fi
        done < "$RESULTS_FILE"
    fi
    echo ""
    echo "==============================================================================="
    echo "END OF REPORT"
    echo "==============================================================================="
} > "$OUTPUT_FILE"

# =============================================================================
# DISPLAY TO SCREEN
# =============================================================================
if [[ $RESULT_COUNT -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  ✓ No Playwright traces found!${NC}"
    echo -e "${GREEN}    Your system is clean.${NC}"
else
    echo -e "${YELLOW}${BOLD}  ⚠ Found $RESULT_COUNT file(s)/folder(s) related to Playwright:${NC}"
    echo ""

    while IFS= read -r line; do
        # Skip /System/Volumes/Data duplicates for cleaner output
        if [[ "$line" != /System/Volumes/Data/* ]]; then
            echo -e "    ${RED}→${NC} $line"
        fi
    done < "$RESULTS_FILE"
fi

echo ""
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Summary:${NC}"
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Files found:${NC}    $RESULT_COUNT"
echo -e "  ${BOLD}Scan duration:${NC}  ${DURATION}s"
echo -e "  ${BOLD}Scan completed:${NC} $SCAN_DATE"
echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  📄 Report saved to:${NC}"
echo -e "${GREEN}     $OUTPUT_FILE${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Cleanup
rm -f "$RESULTS_FILE"
