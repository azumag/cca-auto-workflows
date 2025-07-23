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
