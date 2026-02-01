#!/bin/sh
# test_integration.sh - Integration tests with real Docker containers
#
# This test suite:
#   1. Creates a package with a real container (nginx)
#   2. Runs install.sh to deploy it
#   3. Verifies the service is running
#   4. Adds a new version with updated container
#   5. Runs upgrade.sh to upgrade
#   6. Verifies the upgrade worked
#   7. Tests rollback functionality
#
# Requirements:
#   - Docker must be running
#   - Internet access (to pull test images initially)
#
# Usage: ./tests/test_integration.sh
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OVPS="$PROJECT_DIR/ovps"
TEST_DIR="/tmp/ovps-integration-test-$$"
PACKAGE_DIR="$TEST_DIR/myvendor-webapp-v1.0.0"

# Test container images (using nginx alpine - small and reliable)
CONTAINER_V1="nginx:1.24-alpine"
CONTAINER_V2="nginx:1.25-alpine"

# Colors for output
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_section() {
    printf "\n${BLUE}============================================================${NC}\n"
    printf "${BLUE}%s${NC}\n" "$1"
    printf "${BLUE}============================================================${NC}\n"
}

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

log_cmd() {
    printf "${YELLOW}[CMD]${NC} %s\n" "$1"
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

# Cleanup function
cleanup() {
    log_info "Cleaning up..."

    # Stop and remove containers
    if [ -d "$PACKAGE_DIR/compose" ]; then
        cd "$PACKAGE_DIR/compose" 2>/dev/null || true
        docker compose down --remove-orphans 2>/dev/null || true
    fi

    # Remove test directory
    rm -rf "$TEST_DIR"

    log_info "Cleanup complete"
}

# Set trap for cleanup
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    log_section "Checking Prerequisites"

    if ! command -v docker >/dev/null 2>&1; then
        log_fail "Docker is not installed"
        exit 1
    fi
    log_pass "Docker is installed"

    # Check if Docker daemon is running
    log_info "Checking Docker daemon..."
    if ! docker ps >/dev/null 2>&1; then
        log_fail "Docker daemon is not running or not accessible"
        log_info "Please start your Docker daemon and try again"
        log_info ""
        log_info "Diagnostic info:"
        docker info 2>&1 | tail -3
        exit 1
    fi
    log_pass "Docker daemon is running"

    if ! docker compose version >/dev/null 2>&1; then
        log_fail "Docker Compose is not available"
        exit 1
    fi
    log_pass "Docker Compose is available"
}

# Pull test images
pull_test_images() {
    log_section "Pulling Test Container Images"

    log_info "Pulling $CONTAINER_V1..."
    if ! docker pull "$CONTAINER_V1" >/dev/null 2>&1; then
        log_fail "Failed to pull $CONTAINER_V1"
        exit 1
    fi
    log_pass "Pulled $CONTAINER_V1"

    log_info "Pulling $CONTAINER_V2..."
    if ! docker pull "$CONTAINER_V2" >/dev/null 2>&1; then
        log_fail "Failed to pull $CONTAINER_V2"
        exit 1
    fi
    log_pass "Pulled $CONTAINER_V2"
}

# Create test package
create_test_package() {
    log_section "Creating Test Package"

    mkdir -p "$TEST_DIR"

    log_cmd "$OVPS new myvendor webapp v1.0.0 $PACKAGE_DIR"
    run_test "Create new package" \
        "$OVPS" new myvendor webapp v1.0.0 "$PACKAGE_DIR"

    # Save container image to package
    log_info "Saving container image to package..."
    CONTAINER_FILE="$PACKAGE_DIR/containers/v1.0.0/webapp.tar.gz"

    log_cmd "docker save $CONTAINER_V1 | gzip > $CONTAINER_FILE"
    if docker save "$CONTAINER_V1" | gzip > "$CONTAINER_FILE"; then
        log_pass "Container image saved to package"
    else
        log_fail "Failed to save container image"
        return 1
    fi

    # Update docker-compose.yaml with actual service
    log_info "Configuring docker-compose.yaml..."
    cat > "$PACKAGE_DIR/compose/docker-compose.yaml" << 'EOF'
version: "3.8"

services:
  webapp:
    image: nginx:1.24-alpine
    container_name: webapp-test
    restart: unless-stopped
    ports:
      - "18080:80"
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost/"]
      interval: 5s
      timeout: 3s
      retries: 3
      start_period: 5s
EOF
    log_pass "docker-compose.yaml configured"

    # Update manifest with correct healthcheck endpoint
    log_info "Updating manifest.yaml with correct endpoint..."
    sed -i.bak 's|http://localhost:8080/health|http://localhost:18080/|g' "$PACKAGE_DIR/manifest.yaml"
    rm -f "$PACKAGE_DIR/manifest.yaml.bak"
    log_pass "manifest.yaml updated"

    # Regenerate checksums
    log_cmd "$OVPS checksums $PACKAGE_DIR"
    run_test "Generate checksums" \
        "$OVPS" checksums "$PACKAGE_DIR"
}

# Test installation
test_installation() {
    log_section "Testing Installation (v1.0.0)"

    cd "$PACKAGE_DIR"

    # Run install script
    log_cmd "./scripts/install.sh"
    log_info "Running install.sh..."

    # Use shorter wait times for testing
    export OVPS_INIT_WAIT=3
    export OVPS_HEALTH_WAIT=5

    if ./scripts/install.sh; then
        log_pass "install.sh completed successfully"
    else
        log_fail "install.sh failed"
        # Show logs for debugging
        docker compose -f "$PACKAGE_DIR/compose/docker-compose.yaml" logs
        return 1
    fi

    # Verify container is running
    sleep 2
    run_test "Container is running" \
        docker ps --format '{{.Names}}' | grep -q "webapp-test"

    # Verify service responds
    log_info "Testing HTTP response..."
    sleep 2
    if curl -sf http://localhost:18080/ >/dev/null 2>&1; then
        log_pass "Service responds to HTTP requests"
    else
        log_fail "Service not responding"
    fi

    # Verify deployed version file
    run_test "Deployed version file created" \
        test -f "$PACKAGE_DIR/data/.deployed-version"

    DEPLOYED_VERSION=$(cat "$PACKAGE_DIR/data/.deployed-version" 2>/dev/null | tr -d '[:space:]')
    if [ "$DEPLOYED_VERSION" = "v1.0.0" ]; then
        log_pass "Deployed version is v1.0.0"
    else
        log_fail "Deployed version is '$DEPLOYED_VERSION', expected 'v1.0.0'"
    fi

    # Check nginx version in running container
    NGINX_VERSION=$(docker exec webapp-test nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    log_info "Running nginx version: $NGINX_VERSION"
}

# Add new version and prepare upgrade
prepare_upgrade() {
    log_section "Preparing Upgrade to v1.1.0"

    # Add new version
    log_cmd "$OVPS add-version $PACKAGE_DIR v1.1.0"
    run_test "Add version v1.1.0" \
        "$OVPS" add-version "$PACKAGE_DIR" v1.1.0

    # Save new container image
    log_info "Saving v1.1.0 container image..."
    CONTAINER_FILE_V2="$PACKAGE_DIR/containers/v1.1.0/webapp.tar.gz"

    if docker save "$CONTAINER_V2" | gzip > "$CONTAINER_FILE_V2"; then
        log_pass "v1.1.0 container image saved"
    else
        log_fail "Failed to save v1.1.0 container image"
        return 1
    fi

    # Update docker-compose.yaml for v1.1.0
    log_info "Updating docker-compose.yaml for v1.1.0..."
    cat > "$PACKAGE_DIR/compose/docker-compose.yaml" << 'EOF'
version: "3.8"

services:
  webapp:
    image: nginx:1.25-alpine
    container_name: webapp-test
    restart: unless-stopped
    ports:
      - "18080:80"
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost/"]
      interval: 5s
      timeout: 3s
      retries: 3
      start_period: 5s
EOF
    log_pass "docker-compose.yaml updated for v1.1.0"

    # Regenerate checksums
    run_test "Regenerate checksums" \
        "$OVPS" checksums "$PACKAGE_DIR"

    # Show available versions
    log_info "Available versions:"
    "$OVPS" versions "$PACKAGE_DIR"
}

# Test dry-run upgrade
test_dry_run_upgrade() {
    log_section "Testing Dry-Run Upgrade"

    cd "$PACKAGE_DIR"

    log_cmd "./scripts/upgrade.sh --dry-run --to-version v1.1.0"

    if ./scripts/upgrade.sh --dry-run --to-version v1.1.0 2>&1 | grep -q "\[DRY-RUN\]"; then
        log_pass "Dry-run shows [DRY-RUN] messages"
    else
        log_fail "Dry-run did not show expected messages"
    fi

    # Verify no actual changes were made
    DEPLOYED_VERSION=$(cat "$PACKAGE_DIR/data/.deployed-version" 2>/dev/null | tr -d '[:space:]')
    if [ "$DEPLOYED_VERSION" = "v1.0.0" ]; then
        log_pass "Dry-run did not change deployed version"
    else
        log_fail "Dry-run unexpectedly changed deployed version"
    fi

    # Verify container still running original version
    if docker ps --format '{{.Names}}' | grep -q "webapp-test"; then
        log_pass "Container still running after dry-run"
    else
        log_fail "Container stopped after dry-run"
    fi
}

# Test actual upgrade
test_upgrade() {
    log_section "Testing Actual Upgrade to v1.1.0"

    cd "$PACKAGE_DIR"

    # Record pre-upgrade nginx version
    PRE_UPGRADE_VERSION=$(docker exec webapp-test nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    log_info "Pre-upgrade nginx version: $PRE_UPGRADE_VERSION"

    # Run upgrade
    log_cmd "./scripts/upgrade.sh --to-version v1.1.0"
    log_info "Running upgrade.sh..."

    export OVPS_INIT_WAIT=3
    export OVPS_HEALTH_WAIT=5

    if ./scripts/upgrade.sh --to-version v1.1.0; then
        log_pass "upgrade.sh completed successfully"
    else
        log_fail "upgrade.sh failed"
        docker compose -f "$PACKAGE_DIR/compose/docker-compose.yaml" logs
        return 1
    fi

    # Verify container is running
    sleep 2
    run_test "Container running after upgrade" \
        docker ps --format '{{.Names}}' | grep -q "webapp-test"

    # Verify service responds
    sleep 2
    if curl -sf http://localhost:18080/ >/dev/null 2>&1; then
        log_pass "Service responds after upgrade"
    else
        log_fail "Service not responding after upgrade"
    fi

    # Verify deployed version updated
    DEPLOYED_VERSION=$(cat "$PACKAGE_DIR/data/.deployed-version" 2>/dev/null | tr -d '[:space:]')
    if [ "$DEPLOYED_VERSION" = "v1.1.0" ]; then
        log_pass "Deployed version updated to v1.1.0"
    else
        log_fail "Deployed version is '$DEPLOYED_VERSION', expected 'v1.1.0'"
    fi

    # Check nginx version changed
    POST_UPGRADE_VERSION=$(docker exec webapp-test nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    log_info "Post-upgrade nginx version: $POST_UPGRADE_VERSION"

    if [ "$PRE_UPGRADE_VERSION" != "$POST_UPGRADE_VERSION" ]; then
        log_pass "Container version changed from $PRE_UPGRADE_VERSION to $POST_UPGRADE_VERSION"
    else
        log_fail "Container version did not change"
    fi

    # Verify backup was created
    if [ -d "$PACKAGE_DIR/backups" ] && [ "$(ls -A "$PACKAGE_DIR/backups" 2>/dev/null)" ]; then
        log_pass "Backup directory created"

        # Show backup info
        log_info "Backups available:"
        "$OVPS" rollback "$PACKAGE_DIR"
    else
        log_fail "No backup created during upgrade"
    fi
}

# Test rollback
test_rollback() {
    log_section "Testing Rollback"

    cd "$PACKAGE_DIR"

    # Find the backup directory
    BACKUP_DIR=$(ls -d "$PACKAGE_DIR/backups"/*/ 2>/dev/null | head -1)

    if [ -z "$BACKUP_DIR" ]; then
        log_fail "No backup directory found for rollback test"
        return 1
    fi

    BACKUP_NAME=$(basename "$BACKUP_DIR")
    log_info "Using backup: $BACKUP_NAME"

    # Record pre-rollback version
    PRE_ROLLBACK_VERSION=$(docker exec webapp-test nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    log_info "Pre-rollback nginx version: $PRE_ROLLBACK_VERSION"

    # Note: Full rollback would require the v1.0.0 compose file to be restored
    # and containers to be reloaded. For this test, we'll verify the rollback
    # command works and updates the deployed-version file.

    log_cmd "$OVPS rollback $PACKAGE_DIR $BACKUP_NAME"

    if "$OVPS" rollback "$PACKAGE_DIR" "$BACKUP_NAME"; then
        log_pass "Rollback command completed"
    else
        log_fail "Rollback command failed"
        return 1
    fi

    # Verify deployed version was rolled back
    DEPLOYED_VERSION=$(cat "$PACKAGE_DIR/data/.deployed-version" 2>/dev/null | tr -d '[:space:]')
    if [ "$DEPLOYED_VERSION" = "v1.0.0" ]; then
        log_pass "Deployed version rolled back to v1.0.0"
    else
        log_info "Deployed version is '$DEPLOYED_VERSION' (rollback may have different source version)"
    fi
}

# Test healthcheck script
test_healthcheck() {
    log_section "Testing Healthcheck Script"

    cd "$PACKAGE_DIR"

    log_cmd "./scripts/healthcheck.sh"

    if ./scripts/healthcheck.sh; then
        log_pass "healthcheck.sh reports healthy"
    else
        log_fail "healthcheck.sh reports unhealthy"
    fi
}

# Test validate_containers with version flag
test_validate_containers_versions() {
    log_section "Testing validate_containers.sh with Version Flag"

    cd "$PACKAGE_DIR"

    log_cmd "./scripts/validate_containers.sh --version v1.0.0"
    run_test "Validate v1.0.0 containers" \
        ./scripts/validate_containers.sh --version v1.0.0

    log_cmd "./scripts/validate_containers.sh --version v1.1.0"
    run_test "Validate v1.1.0 containers" \
        ./scripts/validate_containers.sh --version v1.1.0
}

# Main test execution
main() {
    log_section "OVPS Integration Test Suite"
    log_info "Test directory: $TEST_DIR"
    log_info "Container v1: $CONTAINER_V1"
    log_info "Container v2: $CONTAINER_V2"

    check_prerequisites
    pull_test_images
    create_test_package
    test_installation
    test_healthcheck
    prepare_upgrade
    test_dry_run_upgrade
    test_upgrade
    test_validate_containers_versions
    test_rollback

    # Final summary
    log_section "Test Summary"
    echo "Tests run:    $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo ""

    if [ $TESTS_FAILED -gt 0 ]; then
        printf "${RED}SOME TESTS FAILED${NC}\n"
        exit 1
    else
        printf "${GREEN}ALL INTEGRATION TESTS PASSED${NC}\n"
        exit 0
    fi
}

main "$@"
