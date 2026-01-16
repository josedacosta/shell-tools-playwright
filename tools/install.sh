#!/bin/bash
#
# install.sh - Clean Playwright installation for macOS
#
# This script performs a verified Playwright installation:
# - Checks prerequisites (Node.js, npm)
# - Offers cleanup if existing installation detected
# - Installs Playwright with selected browsers
# - Verifies installation is working correctly
#
# Usage:
#   ./install.sh                    # Global installation (default)
#   ./install.sh --local            # Install locally in current directory
#   ./install.sh --browsers all     # Install all browsers
#   ./install.sh --check            # Check only, no installation
#
# Author: Jose DA COSTA
# License: MIT

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

# Playwright browser cache locations
readonly MACOS_BROWSER_CACHE="$HOME/Library/Caches/ms-playwright"

# Minimum versions required
readonly MIN_NODE_VERSION="16.0.0"
readonly MIN_NPM_VERSION="7.0.0"

# Colors for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

INSTALL_GLOBAL=true
BROWSERS="chromium"
CHECK_ONLY=false
SKIP_CLEANUP_PROMPT=false
PROJECT_DIR=""

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
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

log_step() {
    echo -e "${MAGENTA}[STEP]${NC} $1"
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║          PLAYWRIGHT CLEAN INSTALL - macOS                    ║${NC}"
    echo -e "${BOLD}║          Version: $SCRIPT_VERSION                                      ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
    --local             Install Playwright locally in current directory
    --project DIR       Install in specific project directory (implies --local)
    --browsers BROWSER  Browsers to install (default: chromium)
                        Options: chromium, firefox, webkit, all
    --check             Check prerequisites only, no installation
    --skip-cleanup      Skip cleanup prompt if existing installation found
    --help              Show this help message
    --version           Show version information

By default, Playwright is installed globally (npm -g).

Examples:
    $SCRIPT_NAME                         # Global installation (default)
    $SCRIPT_NAME --local                 # Install in current directory
    $SCRIPT_NAME --browsers all          # Install all browsers globally
    $SCRIPT_NAME --project ~/my-project  # Install in specific project
    $SCRIPT_NAME --check                 # Check prerequisites only

Browser options:
    chromium    Google Chrome/Chromium (fastest, recommended)
    firefox     Mozilla Firefox
    webkit      Apple Safari/WebKit
    all         All browsers (chromium, firefox, webkit)

EOF
}

check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is designed for macOS only."
        log_info "Detected OS: $(uname)"
        exit 1
    fi
}

version_compare() {
    # Returns 0 if $1 >= $2, 1 otherwise
    local v1=$1
    local v2=$2

    if [[ "$v1" == "$v2" ]]; then
        return 0
    fi

    local IFS='.'
    local i ver1=($v1) ver2=($v2)

    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done

    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]:-} ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 0
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 1
        fi
    done
    return 0
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_node() {
    log_step "Checking Node.js..."

    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed."
        log_info "Install Node.js from https://nodejs.org/ or via:"
        echo "    brew install node"
        return 1
    fi

    local node_version
    node_version=$(node --version | sed 's/v//')
    log_info "Found Node.js version: $node_version"

    if ! version_compare "$node_version" "$MIN_NODE_VERSION"; then
        log_error "Node.js version $node_version is too old."
        log_info "Minimum required: $MIN_NODE_VERSION"
        return 1
    fi

    log_success "Node.js version is compatible"
    return 0
}

check_npm() {
    log_step "Checking npm..."

    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed."
        return 1
    fi

    local npm_version
    npm_version=$(npm --version)
    log_info "Found npm version: $npm_version"

    if ! version_compare "$npm_version" "$MIN_NPM_VERSION"; then
        log_error "npm version $npm_version is too old."
        log_info "Minimum required: $MIN_NPM_VERSION"
        return 1
    fi

    log_success "npm version is compatible"
    return 0
}

check_xcode_cli() {
    log_step "Checking Xcode Command Line Tools..."

    if ! xcode-select -p &> /dev/null; then
        log_warning "Xcode Command Line Tools not installed."
        log_info "Some browsers (WebKit) may require them."
        log_info "Install with: xcode-select --install"
        return 1
    fi

    log_success "Xcode Command Line Tools are installed"
    return 0
}

check_existing_installation() {
    log_step "Checking for existing Playwright installation..."

    local found_existing=false

    # Check browser cache
    if [[ -d "$MACOS_BROWSER_CACHE" ]]; then
        local size
        size=$(du -sh "$MACOS_BROWSER_CACHE" 2>/dev/null | cut -f1)
        log_warning "Found existing browser cache: $MACOS_BROWSER_CACHE ($size)"
        found_existing=true
    fi

    # Check global packages
    if command -v npm &> /dev/null; then
        local global_pw
        global_pw=$(npm list -g --depth=0 2>/dev/null | grep -i "playwright" || true)
        if [[ -n "$global_pw" ]]; then
            log_warning "Found global Playwright packages:"
            echo "$global_pw" | while read -r line; do
                echo "    $line"
            done
            found_existing=true
        fi
    fi

    # Check current directory
    if [[ -f "package.json" ]] && grep -q "playwright" "package.json" 2>/dev/null; then
        log_warning "Found Playwright in current project's package.json"
        found_existing=true
    fi

    if $found_existing; then
        return 0
    else
        log_success "No existing Playwright installation detected"
        return 1
    fi
}

run_all_checks() {
    local all_passed=true

    echo ""
    log_info "Running prerequisite checks..."
    echo ""

    if ! check_node; then
        all_passed=false
    fi

    if ! check_npm; then
        all_passed=false
    fi

    check_xcode_cli || true  # Non-fatal

    echo ""

    if $all_passed; then
        log_success "All prerequisite checks passed!"
        return 0
    else
        log_error "Some prerequisite checks failed."
        return 1
    fi
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

prompt_cleanup() {
    if $SKIP_CLEANUP_PROMPT; then
        return 1
    fi

    echo ""
    echo -e "${YELLOW}An existing Playwright installation was detected.${NC}"
    echo "It is recommended to clean up before a fresh install."
    echo ""
    echo -e "Would you like to run ${BOLD}deep-uninstall.sh${NC} first? (y/N)"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

select_browsers() {
    if [[ -n "$BROWSERS" && "$BROWSERS" != "prompt" ]]; then
        return
    fi

    echo ""
    echo -e "${BOLD}Select browsers to install:${NC}"
    echo ""
    echo "  1) Chromium only (recommended, fastest)"
    echo "  2) Chromium + Firefox"
    echo "  3) Chromium + WebKit"
    echo "  4) All browsers (Chromium, Firefox, WebKit)"
    echo "  5) Custom selection"
    echo ""
    echo -n "Your choice [1]: "
    read -r choice

    case "${choice:-1}" in
        1)
            BROWSERS="chromium"
            ;;
        2)
            BROWSERS="chromium firefox"
            ;;
        3)
            BROWSERS="chromium webkit"
            ;;
        4)
            BROWSERS="chromium firefox webkit"
            ;;
        5)
            echo ""
            echo "Enter browsers separated by space (chromium firefox webkit):"
            read -r BROWSERS
            ;;
        *)
            BROWSERS="chromium"
            ;;
    esac

    log_info "Selected browsers: $BROWSERS"
}

install_playwright() {
    local install_dir="${PROJECT_DIR:-.}"

    echo ""
    log_step "Installing Playwright..."

    if $INSTALL_GLOBAL; then
        log_info "Installing globally with npm..."
        npm install -g playwright @playwright/test
    else
        if [[ -n "$PROJECT_DIR" ]]; then
            cd "$PROJECT_DIR"
        fi

        # Check for package.json
        if [[ ! -f "package.json" ]]; then
            log_info "No package.json found, creating one..."
            npm init -y
        fi

        log_info "Installing Playwright as dev dependency..."
        npm install -D playwright @playwright/test
    fi

    log_success "Playwright packages installed"
}

install_browsers() {
    echo ""
    log_step "Installing browsers: $BROWSERS"

    local browser_args=""
    for browser in $BROWSERS; do
        case "$browser" in
            chromium|firefox|webkit)
                browser_args="$browser_args --with-deps $browser"
                ;;
            all)
                browser_args="--with-deps"
                ;;
            *)
                log_warning "Unknown browser: $browser, skipping"
                ;;
        esac
    done

    if $INSTALL_GLOBAL; then
        npx playwright install $browser_args
    else
        npx playwright install $browser_args
    fi

    log_success "Browsers installed"
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_installation() {
    echo ""
    log_step "Verifying installation..."

    # Check Playwright is accessible
    local pw_version
    if $INSTALL_GLOBAL; then
        pw_version=$(npx playwright --version 2>/dev/null || echo "")
    else
        pw_version=$(npx playwright --version 2>/dev/null || echo "")
    fi

    if [[ -z "$pw_version" ]]; then
        log_error "Could not verify Playwright installation"
        return 1
    fi

    log_success "Playwright version: $pw_version"

    # Check browser cache
    if [[ -d "$MACOS_BROWSER_CACHE" ]]; then
        local size
        size=$(du -sh "$MACOS_BROWSER_CACHE" 2>/dev/null | cut -f1)
        log_success "Browser cache: $MACOS_BROWSER_CACHE ($size)"
    fi

    # List installed browsers (official command)
    echo ""
    log_info "Installed browsers (npx playwright install --list):"
    npx playwright install --list 2>/dev/null || true

    # Run simple test
    echo ""
    log_info "Running quick verification test..."

    local test_result
    test_result=$(npx playwright test --list 2>&1 || echo "no tests")

    if [[ "$test_result" == *"no tests"* || "$test_result" == *"No tests found"* ]]; then
        log_info "No tests configured (expected for fresh install)"
    else
        log_success "Test discovery working"
    fi

    # Check browsers are executable
    echo ""
    log_info "Checking browser executables..."

    for browser in $BROWSERS; do
        if [[ "$browser" == "all" ]]; then
            for b in chromium firefox webkit; do
                check_browser_executable "$b"
            done
        else
            check_browser_executable "$browser"
        fi
    done

    return 0
}

check_browser_executable() {
    local browser=$1
    local browser_path=""

    case "$browser" in
        chromium)
            browser_path=$(find "$MACOS_BROWSER_CACHE" -name "chrome" -type f 2>/dev/null | head -1 || true)
            ;;
        firefox)
            browser_path=$(find "$MACOS_BROWSER_CACHE" -name "firefox" -type f 2>/dev/null | head -1 || true)
            ;;
        webkit)
            browser_path=$(find "$MACOS_BROWSER_CACHE" -name "Playwright.app" -type d 2>/dev/null | head -1 || true)
            ;;
    esac

    if [[ -n "$browser_path" ]]; then
        log_success "$browser browser found"
    else
        log_warning "$browser browser not found in cache"
    fi
}

print_summary() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║                   INSTALLATION COMPLETE                      ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "Playwright is ready to use!"
    echo ""
    echo "Quick start commands:"
    echo ""
    echo "  # Run tests"
    echo "  npx playwright test"
    echo ""
    echo "  # Open UI mode"
    echo "  npx playwright test --ui"
    echo ""
    echo "  # Generate tests with codegen"
    echo "  npx playwright codegen example.com"
    echo ""
    echo "  # Show installed browsers"
    echo "  npx playwright --version"
    echo ""
    echo "Documentation: https://playwright.dev/docs/intro"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --local)
                INSTALL_GLOBAL=false
                shift
                ;;
            --project)
                PROJECT_DIR="$2"
                INSTALL_GLOBAL=false
                shift 2
                ;;
            --browsers)
                BROWSERS="$2"
                if [[ "$BROWSERS" == "all" ]]; then
                    BROWSERS="chromium firefox webkit"
                fi
                shift 2
                ;;
            --check)
                CHECK_ONLY=true
                shift
                ;;
            --skip-cleanup)
                SKIP_CLEANUP_PROMPT=true
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

    # Run prerequisite checks
    if ! run_all_checks; then
        exit 1
    fi

    # Check-only mode
    if $CHECK_ONLY; then
        echo ""
        check_existing_installation || true
        echo ""
        log_info "Check-only mode complete."
        exit 0
    fi

    # Check for existing installation
    if check_existing_installation; then
        if prompt_cleanup; then
            local script_dir
            script_dir="$(cd "$(dirname "$0")" && pwd)"
            if [[ -x "$script_dir/deep-uninstall.sh" ]]; then
                "$script_dir/deep-uninstall.sh"
            else
                log_warning "deep-uninstall.sh not found. Proceeding with installation..."
            fi
        fi
    fi

    # Select browsers
    select_browsers

    # Install
    install_playwright
    install_browsers

    # Verify
    if verify_installation; then
        print_summary
    else
        log_error "Installation verification failed"
        log_info "Try running 'deep-uninstall.sh' and reinstalling"
        exit 1
    fi
}

main "$@"
