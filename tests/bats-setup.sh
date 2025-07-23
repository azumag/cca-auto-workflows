#!/bin/bash
#
# BATS Setup Script for Claude Code Auto Workflows Tests
# This script sets up the BATS testing environment

set -euo pipefail

BATS_VERSION="1.10.0"
BATS_SUPPORT_VERSION="0.3.0"
BATS_ASSERT_VERSION="2.1.0"
BATS_FILE_VERSION="0.4.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS_DIR="$SCRIPT_DIR/bats"

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

# Create BATS directory structure
setup_directories() {
    log_info "Setting up BATS directory structure..."
    
    mkdir -p "$BATS_DIR"/{bin,lib}
    mkdir -p "$SCRIPT_DIR"/{helpers,fixtures,mocks}
}

# Install BATS core
install_bats_core() {
    log_info "Installing BATS core v$BATS_VERSION..."
    
    local bats_archive="$BATS_DIR/bats-core-$BATS_VERSION.tar.gz"
    
    if [[ ! -f "$BATS_DIR/bin/bats" ]]; then
        curl -L "https://github.com/bats-core/bats-core/archive/v$BATS_VERSION.tar.gz" -o "$bats_archive"
        tar -xzf "$bats_archive" -C "$BATS_DIR" --strip-components=1
        rm "$bats_archive"
        
        # Make bats executable
        chmod +x "$BATS_DIR/bin/bats"
        chmod +x "$BATS_DIR/libexec"/*
    fi
    
    log_info "BATS core installed successfully"
}

# Install BATS support libraries
install_bats_support() {
    log_info "Installing BATS support libraries..."
    
    # BATS support
    if [[ ! -d "$BATS_DIR/lib/bats-support" ]]; then
        local support_archive="$BATS_DIR/bats-support-$BATS_SUPPORT_VERSION.tar.gz"
        curl -L "https://github.com/bats-core/bats-support/archive/v$BATS_SUPPORT_VERSION.tar.gz" -o "$support_archive"
        tar -xzf "$support_archive" -C "$BATS_DIR/lib"
        mv "$BATS_DIR/lib/bats-support-$BATS_SUPPORT_VERSION" "$BATS_DIR/lib/bats-support"
        rm "$support_archive"
    fi
    
    # BATS assert
    if [[ ! -d "$BATS_DIR/lib/bats-assert" ]]; then
        local assert_archive="$BATS_DIR/bats-assert-$BATS_ASSERT_VERSION.tar.gz"
        curl -L "https://github.com/bats-core/bats-assert/archive/v$BATS_ASSERT_VERSION.tar.gz" -o "$assert_archive"
        tar -xzf "$assert_archive" -C "$BATS_DIR/lib"
        mv "$BATS_DIR/lib/bats-assert-$BATS_ASSERT_VERSION" "$BATS_DIR/lib/bats-assert"
        rm "$assert_archive"
    fi
    
    # BATS file
    if [[ ! -d "$BATS_DIR/lib/bats-file" ]]; then
        local file_archive="$BATS_DIR/bats-file-$BATS_FILE_VERSION.tar.gz"
        curl -L "https://github.com/bats-core/bats-file/archive/v$BATS_FILE_VERSION.tar.gz" -o "$file_archive"
        tar -xzf "$file_archive" -C "$BATS_DIR/lib"
        mv "$BATS_DIR/lib/bats-file-$BATS_FILE_VERSION" "$BATS_DIR/lib/bats-file"
        rm "$file_archive"
    fi
    
    log_info "BATS support libraries installed successfully"
}

# Create test runner script
create_test_runner() {
    log_info "Creating test runner script..."
    
    cat > "$SCRIPT_DIR/run-tests.sh" << 'EOF'
#!/bin/bash
#
# Test runner for Claude Code Auto Workflows BATS tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS_BIN="$SCRIPT_DIR/bats/bin/bats"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if BATS is installed
if [[ ! -f "$BATS_BIN" ]]; then
    log_error "BATS not found. Please run: tests/bats-setup.sh"
    exit 1
fi

# Parse arguments
COVERAGE=false
VERBOSE=false
SPECIFIC_TEST=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --coverage)
            COVERAGE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --test)
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "  --coverage    Generate test coverage report"
            echo "  --verbose     Verbose output"
            echo "  --test FILE   Run specific test file"
            echo "  --help        Show this help"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run tests
log_info "Running BATS tests..."

if [[ -n "$SPECIFIC_TEST" ]]; then
    if [[ -f "$SCRIPT_DIR/$SPECIFIC_TEST" ]]; then
        "$BATS_BIN" "$SCRIPT_DIR/$SPECIFIC_TEST"
    else
        log_error "Test file not found: $SPECIFIC_TEST"
        exit 1
    fi
elif [[ "$VERBOSE" == "true" ]]; then
    "$BATS_BIN" --verbose-run "$SCRIPT_DIR"/*.bats
else
    "$BATS_BIN" "$SCRIPT_DIR"/*.bats
fi

log_info "Test execution completed"
EOF

    chmod +x "$SCRIPT_DIR/run-tests.sh"
    log_info "Test runner created: tests/run-tests.sh"
}

# Main setup function
main() {
    log_info "Setting up BATS testing environment..."
    
    setup_directories
    install_bats_core
    install_bats_support
    create_test_runner
    
    log_info "BATS setup completed successfully!"
    log_info "Run tests with: tests/run-tests.sh"
}

main "$@"