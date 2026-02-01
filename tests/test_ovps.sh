#!/bin/sh
# test_ovps.sh - Automated test suite for OVPS
#
# Usage: ./tests/test_ovps.sh
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OVPS="$PROJECT_DIR/ovps"
TEST_DIR="/tmp/ovps-test-$$"

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_test() {
    printf "${YELLOW}[TEST]${NC} %s\n" "$1"
}

log_pass() {
    printf "${GREEN}[PASS]${NC} %s\n" "$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    printf "${RED}[FAIL]${NC} %s\n" "$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_info() {
    printf "[INFO] %s\n" "$1"
}

# Run a test
run_test() {
    test_name="$1"
    shift
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "$test_name"
    if "$@"; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

# Assert file exists
assert_file_exists() {
    [ -f "$1" ]
}

# Assert directory exists
assert_dir_exists() {
    [ -d "$1" ]
}

# Assert file contains pattern
assert_file_contains() {
    grep -q "$2" "$1" 2>/dev/null
}

# Assert file does NOT contain pattern
assert_file_not_contains() {
    ! grep -q "$2" "$1" 2>/dev/null
}

# Assert command succeeds
assert_cmd_succeeds() {
    "$@" >/dev/null 2>&1
}

# Assert command output contains pattern
assert_cmd_output_contains() {
    pattern="$1"
    shift
    "$@" 2>&1 | grep -q "$pattern"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test directory: $TEST_DIR"
    rm -rf "$TEST_DIR"
}

# Set trap for cleanup
trap cleanup EXIT

# ============================================================
# Test Setup
# ============================================================

log_info "=================================================="
log_info "OVPS Automated Test Suite"
log_info "=================================================="
log_info "Test directory: $TEST_DIR"
log_info ""

mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# ============================================================
# Test: ovps help
# ============================================================

run_test "ovps help shows usage" \
    assert_cmd_output_contains "Usage:" "$OVPS" help

run_test "ovps help shows add-version command" \
    assert_cmd_output_contains "add-version" "$OVPS" help

run_test "ovps help shows versions command" \
    assert_cmd_output_contains "versions" "$OVPS" help

run_test "ovps help shows rollback command" \
    assert_cmd_output_contains "rollback" "$OVPS" help

# ============================================================
# Test: ovps new
# ============================================================

PACKAGE_DIR="$TEST_DIR/testvendor-testapp-v1.0.0"

run_test "ovps new creates package" \
    assert_cmd_succeeds "$OVPS" new testvendor testapp v1.0.0 "$PACKAGE_DIR"

run_test "Package directory exists" \
    assert_dir_exists "$PACKAGE_DIR"

run_test "manifest.yaml exists" \
    assert_file_exists "$PACKAGE_DIR/manifest.yaml"

run_test "docker-compose.yaml exists" \
    assert_file_exists "$PACKAGE_DIR/compose/docker-compose.yaml"

run_test "install.sh exists" \
    assert_file_exists "$PACKAGE_DIR/scripts/install.sh"

run_test "upgrade.sh exists" \
    assert_file_exists "$PACKAGE_DIR/scripts/upgrade.sh"

run_test "validate_containers.sh exists" \
    assert_file_exists "$PACKAGE_DIR/scripts/validate_containers.sh"

run_test "healthcheck.sh exists" \
    assert_file_exists "$PACKAGE_DIR/scripts/healthcheck.sh"

run_test "containers/v1.0.0 directory exists" \
    assert_dir_exists "$PACKAGE_DIR/containers/v1.0.0"

# ============================================================
# Test: Issue #5 - No network pull in install.sh
# ============================================================

run_test "install.sh does NOT contain 'pull' command" \
    assert_file_not_contains "$PACKAGE_DIR/scripts/install.sh" '\$COMPOSE_CMD pull'

run_test "install.sh contains offline mode message" \
    assert_file_contains "$PACKAGE_DIR/scripts/install.sh" "offline mode"

# ============================================================
# Test: Issue #2 - Version tracking in install.sh
# ============================================================

run_test "install.sh tracks deployed version" \
    assert_file_contains "$PACKAGE_DIR/scripts/install.sh" ".deployed-version"

# ============================================================
# Test: Issue #13 - Configurable sleep values
# ============================================================

run_test "install.sh uses OVPS_INIT_WAIT" \
    assert_file_contains "$PACKAGE_DIR/scripts/install.sh" "OVPS_INIT_WAIT"

run_test "install.sh uses OVPS_HEALTH_WAIT" \
    assert_file_contains "$PACKAGE_DIR/scripts/install.sh" "OVPS_HEALTH_WAIT"

run_test "upgrade.sh uses OVPS_INIT_WAIT" \
    assert_file_contains "$PACKAGE_DIR/scripts/upgrade.sh" "OVPS_INIT_WAIT"

run_test "upgrade.sh uses OVPS_HEALTH_WAIT" \
    assert_file_contains "$PACKAGE_DIR/scripts/upgrade.sh" "OVPS_HEALTH_WAIT"

run_test "healthcheck.sh uses OVPS_HEALTH_CHECK_TIMEOUT" \
    assert_file_contains "$PACKAGE_DIR/scripts/healthcheck.sh" "OVPS_HEALTH_CHECK_TIMEOUT"

# ============================================================
# Test: Issue #11 - Dry-run mode in upgrade.sh
# ============================================================

run_test "upgrade.sh supports --dry-run flag" \
    assert_file_contains "$PACKAGE_DIR/scripts/upgrade.sh" "\-\-dry-run"

run_test "upgrade.sh has DRY_RUN variable" \
    assert_file_contains "$PACKAGE_DIR/scripts/upgrade.sh" "DRY_RUN="

run_test "upgrade.sh outputs [DRY-RUN] messages" \
    assert_file_contains "$PACKAGE_DIR/scripts/upgrade.sh" "\[DRY-RUN\]"

# ============================================================
# Test: Issue #3 - Multi-version container loading
# ============================================================

run_test "validate_containers.sh supports --version flag" \
    assert_file_contains "$PACKAGE_DIR/scripts/validate_containers.sh" "\-\-version"

run_test "validate_containers.sh uses TARGET_VERSION" \
    assert_file_contains "$PACKAGE_DIR/scripts/validate_containers.sh" "TARGET_VERSION"

run_test "upgrade.sh supports --to-version flag" \
    assert_file_contains "$PACKAGE_DIR/scripts/upgrade.sh" "\-\-to-version"

run_test "upgrade.sh passes version to validate_containers.sh" \
    assert_file_contains "$PACKAGE_DIR/scripts/upgrade.sh" "validate_containers.sh --load --version"

# ============================================================
# Test: Issue #2 - Version detection from deployed-version
# ============================================================

run_test "upgrade.sh reads from .deployed-version file" \
    assert_file_contains "$PACKAGE_DIR/scripts/upgrade.sh" "DEPLOYED_VERSION_FILE"

run_test "upgrade.sh updates deployed version after upgrade" \
    assert_file_contains "$PACKAGE_DIR/scripts/upgrade.sh" 'echo "\$TO_VERSION" > "\$DEPLOYED_VERSION_FILE"'

# ============================================================
# Test: Issue #4 - OCI format loading
# ============================================================

run_test "validate_containers.sh supports .oci files" \
    assert_file_contains "$PACKAGE_DIR/scripts/validate_containers.sh" '\.oci'

run_test "validate_containers.sh mentions skopeo for OCI" \
    assert_file_contains "$PACKAGE_DIR/scripts/validate_containers.sh" "skopeo"

# ============================================================
# Test: Issue #7 - containers.yaml validation
# ============================================================

run_test "validate_containers.sh checks containers.yaml" \
    assert_file_contains "$PACKAGE_DIR/scripts/validate_containers.sh" "containers.yaml"

# ============================================================
# Test: Issue #6 - No alpine placeholder in compose
# ============================================================

run_test "docker-compose.yaml does NOT have alpine placeholder" \
    assert_file_not_contains "$PACKAGE_DIR/compose/docker-compose.yaml" "alpine:latest"

run_test "docker-compose.yaml has empty services mapping" \
    assert_file_contains "$PACKAGE_DIR/compose/docker-compose.yaml" "services: {}"

# ============================================================
# Test: ovps validate
# ============================================================

run_test "ovps validate succeeds on new package" \
    assert_cmd_succeeds "$OVPS" validate "$PACKAGE_DIR"

# ============================================================
# Test: Issue #1 - ovps add-version
# ============================================================

run_test "ovps add-version succeeds" \
    assert_cmd_succeeds "$OVPS" add-version "$PACKAGE_DIR" v1.1.0

run_test "New version directory created" \
    assert_dir_exists "$PACKAGE_DIR/containers/v1.1.0"

run_test "Manifest updated to new version" \
    assert_file_contains "$PACKAGE_DIR/manifest.yaml" "v1.1.0"

run_test "Scripts regenerated with new version" \
    assert_file_contains "$PACKAGE_DIR/scripts/install.sh" "v1.1.0"

# ============================================================
# Test: Issue #10 - ovps versions
# ============================================================

run_test "ovps versions shows v1.0.0" \
    assert_cmd_output_contains "v1.0.0" "$OVPS" versions "$PACKAGE_DIR"

run_test "ovps versions shows v1.1.0" \
    assert_cmd_output_contains "v1.1.0" "$OVPS" versions "$PACKAGE_DIR"

run_test "ovps versions shows manifest version" \
    assert_cmd_output_contains "Manifest version" "$OVPS" versions "$PACKAGE_DIR"

run_test "ovps versions shows deployed version status" \
    assert_cmd_output_contains "Deployed version" "$OVPS" versions "$PACKAGE_DIR"

# ============================================================
# Test: Issue #9 - ovps rollback (listing mode)
# ============================================================

run_test "ovps rollback lists backups" \
    assert_cmd_output_contains "Available backups" "$OVPS" rollback "$PACKAGE_DIR"

# ============================================================
# Test: Dry-run upgrade execution
# ============================================================

run_test "Dry-run upgrade executes without error" \
    assert_cmd_succeeds "$PACKAGE_DIR/scripts/upgrade.sh" --dry-run --to-version v1.1.0

run_test "Dry-run upgrade shows DRY-RUN messages" \
    assert_cmd_output_contains "\[DRY-RUN\]" "$PACKAGE_DIR/scripts/upgrade.sh" --dry-run --to-version v1.1.0

# ============================================================
# Test: ovps checksums
# ============================================================

run_test "ovps checksums succeeds" \
    assert_cmd_succeeds "$OVPS" checksums "$PACKAGE_DIR"

run_test "sha256.txt exists" \
    assert_file_exists "$PACKAGE_DIR/checksums/sha256.txt"

# ============================================================
# Test: ovps finalize
# ============================================================

run_test "ovps finalize succeeds" \
    assert_cmd_succeeds "$OVPS" finalize "$PACKAGE_DIR"

# ============================================================
# Test: ovps package
# ============================================================

ARCHIVE_FILE="$TEST_DIR/testpackage.tar.gz"

run_test "ovps package creates archive" \
    assert_cmd_succeeds "$OVPS" package "$PACKAGE_DIR" "$ARCHIVE_FILE"

run_test "Archive file exists" \
    assert_file_exists "$ARCHIVE_FILE"

# ============================================================
# Test: Issue #12 - Error handling in cmd_package
# ============================================================

# Create a package with validation warnings to test error handling
WARN_PACKAGE="$TEST_DIR/warn-package"
"$OVPS" new warnvendor warnapp v1.0.0 "$WARN_PACKAGE" >/dev/null 2>&1

run_test "ovps package handles validation warnings gracefully" \
    assert_cmd_succeeds "$OVPS" package "$WARN_PACKAGE" "$TEST_DIR/warn.tar.gz"

# ============================================================
# Test: Issue #8 - Manifest cross-validation
# ============================================================

# The validate_manifest.sh should check cross-file consistency
run_test "Manifest validator checks container references" \
    assert_file_contains "$PROJECT_DIR/validators/validate_manifest.sh" "container references"

run_test "Manifest validator checks service references" \
    assert_file_contains "$PROJECT_DIR/validators/validate_manifest.sh" "service references"

# ============================================================
# Test: Add another version to test multi-version
# ============================================================

run_test "ovps add-version succeeds for v2.0.0" \
    assert_cmd_succeeds "$OVPS" add-version "$PACKAGE_DIR" v2.0.0

run_test "v2.0.0 directory created" \
    assert_dir_exists "$PACKAGE_DIR/containers/v2.0.0"

run_test "ovps versions shows all three versions" \
    assert_cmd_output_contains "v2.0.0" "$OVPS" versions "$PACKAGE_DIR"

# ============================================================
# Test: Validate containers.sh with --version flag
# ============================================================

run_test "validate_containers.sh --version v1.0.0 works" \
    assert_cmd_succeeds "$PACKAGE_DIR/scripts/validate_containers.sh" --version v1.0.0

run_test "validate_containers.sh --version v1.1.0 works" \
    assert_cmd_succeeds "$PACKAGE_DIR/scripts/validate_containers.sh" --version v1.1.0

# ============================================================
# Test: Docker compose validation
# ============================================================

if command -v docker >/dev/null 2>&1; then
    run_test "docker-compose.yaml is valid" \
        assert_cmd_succeeds docker compose -f "$PACKAGE_DIR/compose/docker-compose.yaml" config
else
    log_info "Skipping Docker compose validation (Docker not available)"
fi

# ============================================================
# Test Summary
# ============================================================

echo ""
echo "=================================================="
echo "Test Summary"
echo "=================================================="
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "=================================================="

if [ $TESTS_FAILED -gt 0 ]; then
    printf "${RED}SOME TESTS FAILED${NC}\n"
    exit 1
else
    printf "${GREEN}ALL TESTS PASSED${NC}\n"
    exit 0
fi
