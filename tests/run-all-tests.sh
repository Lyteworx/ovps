#!/bin/sh
# run-all-tests.sh - Run the complete OVPS test suite
#
# Usage: ./tests/run-all-tests.sh [options]
#
# Options:
#   --unit-only       Run only unit tests (no Docker required)
#   --integration     Run only integration tests (Docker required)
#   --help            Show this help message

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    GREEN=''
    RED=''
    BLUE=''
    NC=''
fi

print_header() {
    printf "\n${BLUE}%s${NC}\n" "============================================================"
    printf "${BLUE}%s${NC}\n" "$1"
    printf "${BLUE}%s${NC}\n\n" "============================================================"
}

print_usage() {
    cat << 'EOF'
OVPS Test Suite Runner

Usage: ./tests/run-all-tests.sh [options]

Options:
  --unit-only       Run only unit tests (no Docker required)
  --integration     Run only integration tests (Docker required)
  --single          Run only single-container integration test
  --multi           Run only multi-container integration test
  --help            Show this help message

Examples:
  ./tests/run-all-tests.sh                  # Run all tests
  ./tests/run-all-tests.sh --unit-only      # Quick test, no Docker needed
  ./tests/run-all-tests.sh --integration    # Only Docker-based tests

Environment Variables:
  OVPS_INIT_WAIT     Seconds to wait after starting services (default: 5)
  OVPS_HEALTH_WAIT   Seconds to wait for health checks (default: 10)
EOF
}

RUN_UNIT=1
RUN_SINGLE=1
RUN_MULTI=1

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --unit-only)
            RUN_SINGLE=0
            RUN_MULTI=0
            shift
            ;;
        --integration)
            RUN_UNIT=0
            shift
            ;;
        --single)
            RUN_UNIT=0
            RUN_MULTI=0
            shift
            ;;
        --multi)
            RUN_UNIT=0
            RUN_SINGLE=0
            shift
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

TOTAL_PASSED=0
TOTAL_FAILED=0

# Run unit tests
if [ "$RUN_UNIT" -eq 1 ]; then
    print_header "Running Unit Tests"
    if "$SCRIPT_DIR/test_ovps.sh"; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
fi

# Run single container integration test
if [ "$RUN_SINGLE" -eq 1 ]; then
    print_header "Running Single-Container Integration Test"
    if "$SCRIPT_DIR/test_integration_single_container.sh"; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
fi

# Run multi-container integration test
if [ "$RUN_MULTI" -eq 1 ]; then
    print_header "Running Multi-Container Integration Test"
    if "$SCRIPT_DIR/test_integration_multi_container.sh"; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
fi

# Final summary
print_header "Final Summary"
echo "Test suites passed: $TOTAL_PASSED"
echo "Test suites failed: $TOTAL_FAILED"
echo ""

if [ "$TOTAL_FAILED" -gt 0 ]; then
    printf "${RED}SOME TEST SUITES FAILED${NC}\n"
    exit 1
else
    printf "${GREEN}ALL TEST SUITES PASSED${NC}\n"
    exit 0
fi
