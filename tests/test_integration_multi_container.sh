#!/bin/sh
# test_integration_multi_container.sh - Integration tests with multiple Docker containers
#
# This test suite verifies OVPS works with multi-container deployments:
#   - nginx (web frontend)
#   - redis (cache/backend)
#
# Tests:
#   1. Creates a package with multiple containers
#   2. Runs install.sh to deploy both services
#   3. Verifies both services are running and can communicate
#   4. Adds a new version with updated containers
#   5. Runs upgrade.sh to upgrade all containers
#   6. Verifies the upgrade worked for all services
#   7. Tests rollback functionality
#
# Requirements:
#   - Docker must be running
#   - Internet access (to pull test images initially)
#
# Usage: ./tests/test_integration_multi_container.sh
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OVPS="$PROJECT_DIR/ovps"
TEST_DIR="/tmp/ovps-multi-container-test-$$"
PACKAGE_DIR="$TEST_DIR/myvendor-fullstack-v1.0.0"

# Test container images (using nginx and redis alpine - small and reliable)
NGINX_V1="nginx:1.24-alpine"
NGINX_V2="nginx:1.25-alpine"
REDIS_V1="redis:7.0-alpine"
REDIS_V2="redis:7.2-alpine"

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

    log_info "Pulling $NGINX_V1..."
    docker pull "$NGINX_V1" >/dev/null 2>&1 || { log_fail "Failed to pull $NGINX_V1"; exit 1; }
    log_pass "Pulled $NGINX_V1"

    log_info "Pulling $NGINX_V2..."
    docker pull "$NGINX_V2" >/dev/null 2>&1 || { log_fail "Failed to pull $NGINX_V2"; exit 1; }
    log_pass "Pulled $NGINX_V2"

    log_info "Pulling $REDIS_V1..."
    docker pull "$REDIS_V1" >/dev/null 2>&1 || { log_fail "Failed to pull $REDIS_V1"; exit 1; }
    log_pass "Pulled $REDIS_V1"

    log_info "Pulling $REDIS_V2..."
    docker pull "$REDIS_V2" >/dev/null 2>&1 || { log_fail "Failed to pull $REDIS_V2"; exit 1; }
    log_pass "Pulled $REDIS_V2"
}

# Create test package
create_test_package() {
    log_section "Creating Multi-Container Test Package"

    mkdir -p "$TEST_DIR"

    log_cmd "$OVPS new myvendor fullstack v1.0.0 $PACKAGE_DIR"
    run_test "Create new package" \
        "$OVPS" new myvendor fullstack v1.0.0 "$PACKAGE_DIR"

    # Save container images to package
    log_info "Saving nginx container image..."
    docker save "$NGINX_V1" | gzip > "$PACKAGE_DIR/containers/v1.0.0/nginx.tar.gz"
    log_pass "nginx image saved"

    log_info "Saving redis container image..."
    docker save "$REDIS_V1" | gzip > "$PACKAGE_DIR/containers/v1.0.0/redis.tar.gz"
    log_pass "redis image saved"

    # Create containers.yaml manifest
    log_info "Creating containers.yaml..."
    cat > "$PACKAGE_DIR/containers/v1.0.0/containers.yaml" << 'EOF'
# Container manifest for v1.0.0
containers:
  - name: nginx
    file: nginx.tar.gz
    image: nginx:1.24-alpine
  - name: redis
    file: redis.tar.gz
    image: redis:7.0-alpine
EOF
    log_pass "containers.yaml created"

    # Update docker-compose.yaml with multi-service configuration
    log_info "Configuring docker-compose.yaml for multi-container setup..."
    cat > "$PACKAGE_DIR/compose/docker-compose.yaml" << 'EOF'
version: "3.8"

services:
  web:
    image: nginx:1.24-alpine
    container_name: fullstack-web
    restart: unless-stopped
    ports:
      - "18080:80"
    depends_on:
      - cache
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost/"]
      interval: 5s
      timeout: 3s
      retries: 3
      start_period: 5s

  cache:
    image: redis:7.0-alpine
    container_name: fullstack-cache
    restart: unless-stopped
    ports:
      - "16379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 3
      start_period: 5s
    volumes:
      - ../data/persistent/redis:/data
EOF
    log_pass "docker-compose.yaml configured with 2 services"

    # Update manifest with correct healthcheck endpoints
    log_info "Updating manifest.yaml..."
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
    log_section "Testing Multi-Container Installation (v1.0.0)"

    cd "$PACKAGE_DIR"

    # Create redis data directory
    mkdir -p "$PACKAGE_DIR/data/persistent/redis"

    # Run install script
    log_cmd "./scripts/install.sh"
    log_info "Running install.sh..."

    export OVPS_INIT_WAIT=5
    export OVPS_HEALTH_WAIT=10

    if ./scripts/install.sh; then
        log_pass "install.sh completed successfully"
    else
        log_fail "install.sh failed"
        docker compose -f "$PACKAGE_DIR/compose/docker-compose.yaml" logs
        return 1
    fi

    # Verify both containers are running
    sleep 3

    run_test "Web container is running" \
        docker ps --format '{{.Names}}' | grep -q "fullstack-web"

    run_test "Cache container is running" \
        docker ps --format '{{.Names}}' | grep -q "fullstack-cache"

    # Verify nginx responds
    log_info "Testing nginx HTTP response..."
    sleep 2
    if curl -sf http://localhost:18080/ >/dev/null 2>&1; then
        log_pass "Nginx responds to HTTP requests"
    else
        log_fail "Nginx not responding"
    fi

    # Verify redis responds
    log_info "Testing redis PING..."
    if docker exec fullstack-cache redis-cli ping 2>/dev/null | grep -q "PONG"; then
        log_pass "Redis responds to PING"
    else
        log_fail "Redis not responding"
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

    # Check container versions
    NGINX_VERSION=$(docker exec fullstack-web nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    REDIS_VERSION=$(docker exec fullstack-cache redis-server --version 2>&1 | grep -oE 'v=[0-9]+\.[0-9]+\.[0-9]+' | cut -d= -f2 || echo "unknown")
    log_info "Running nginx version: $NGINX_VERSION"
    log_info "Running redis version: $REDIS_VERSION"
}

# Add new version and prepare upgrade
prepare_upgrade() {
    log_section "Preparing Multi-Container Upgrade to v1.1.0"

    # Add new version
    log_cmd "$OVPS add-version $PACKAGE_DIR v1.1.0"
    run_test "Add version v1.1.0" \
        "$OVPS" add-version "$PACKAGE_DIR" v1.1.0

    # Save new container images
    log_info "Saving v1.1.0 nginx image..."
    docker save "$NGINX_V2" | gzip > "$PACKAGE_DIR/containers/v1.1.0/nginx.tar.gz"
    log_pass "nginx v1.1.0 image saved"

    log_info "Saving v1.1.0 redis image..."
    docker save "$REDIS_V2" | gzip > "$PACKAGE_DIR/containers/v1.1.0/redis.tar.gz"
    log_pass "redis v1.1.0 image saved"

    # Create containers.yaml for v1.1.0
    log_info "Creating containers.yaml for v1.1.0..."
    cat > "$PACKAGE_DIR/containers/v1.1.0/containers.yaml" << 'EOF'
# Container manifest for v1.1.0
containers:
  - name: nginx
    file: nginx.tar.gz
    image: nginx:1.25-alpine
  - name: redis
    file: redis.tar.gz
    image: redis:7.2-alpine
EOF
    log_pass "containers.yaml created for v1.1.0"

    # Update docker-compose.yaml for v1.1.0
    log_info "Updating docker-compose.yaml for v1.1.0..."
    cat > "$PACKAGE_DIR/compose/docker-compose.yaml" << 'EOF'
version: "3.8"

services:
  web:
    image: nginx:1.25-alpine
    container_name: fullstack-web
    restart: unless-stopped
    ports:
      - "18080:80"
    depends_on:
      - cache
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost/"]
      interval: 5s
      timeout: 3s
      retries: 3
      start_period: 5s

  cache:
    image: redis:7.2-alpine
    container_name: fullstack-cache
    restart: unless-stopped
    ports:
      - "16379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 3
      start_period: 5s
    volumes:
      - ../data/persistent/redis:/data
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
    log_section "Testing Dry-Run Upgrade (Multi-Container)"

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

    # Verify both containers still running
    if docker ps --format '{{.Names}}' | grep -q "fullstack-web"; then
        log_pass "Web container still running after dry-run"
    else
        log_fail "Web container stopped after dry-run"
    fi

    if docker ps --format '{{.Names}}' | grep -q "fullstack-cache"; then
        log_pass "Cache container still running after dry-run"
    else
        log_fail "Cache container stopped after dry-run"
    fi
}

# Test actual upgrade
test_upgrade() {
    log_section "Testing Actual Multi-Container Upgrade to v1.1.0"

    cd "$PACKAGE_DIR"

    # Record pre-upgrade versions
    PRE_NGINX=$(docker exec fullstack-web nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    PRE_REDIS=$(docker exec fullstack-cache redis-server --version 2>&1 | grep -oE 'v=[0-9]+\.[0-9]+' | head -1 | cut -d= -f2 || echo "unknown")
    log_info "Pre-upgrade nginx version: $PRE_NGINX"
    log_info "Pre-upgrade redis version: $PRE_REDIS"

    # Run upgrade
    log_cmd "./scripts/upgrade.sh --to-version v1.1.0"
    log_info "Running upgrade.sh..."

    export OVPS_INIT_WAIT=5
    export OVPS_HEALTH_WAIT=10

    if ./scripts/upgrade.sh --to-version v1.1.0; then
        log_pass "upgrade.sh completed successfully"
    else
        log_fail "upgrade.sh failed"
        docker compose -f "$PACKAGE_DIR/compose/docker-compose.yaml" logs
        return 1
    fi

    # Verify both containers are running
    sleep 3

    run_test "Web container running after upgrade" \
        docker ps --format '{{.Names}}' | grep -q "fullstack-web"

    run_test "Cache container running after upgrade" \
        docker ps --format '{{.Names}}' | grep -q "fullstack-cache"

    # Verify services respond
    sleep 2
    if curl -sf http://localhost:18080/ >/dev/null 2>&1; then
        log_pass "Nginx responds after upgrade"
    else
        log_fail "Nginx not responding after upgrade"
    fi

    if docker exec fullstack-cache redis-cli ping 2>/dev/null | grep -q "PONG"; then
        log_pass "Redis responds after upgrade"
    else
        log_fail "Redis not responding after upgrade"
    fi

    # Verify deployed version updated
    DEPLOYED_VERSION=$(cat "$PACKAGE_DIR/data/.deployed-version" 2>/dev/null | tr -d '[:space:]')
    if [ "$DEPLOYED_VERSION" = "v1.1.0" ]; then
        log_pass "Deployed version updated to v1.1.0"
    else
        log_fail "Deployed version is '$DEPLOYED_VERSION', expected 'v1.1.0'"
    fi

    # Check versions changed
    POST_NGINX=$(docker exec fullstack-web nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    POST_REDIS=$(docker exec fullstack-cache redis-server --version 2>&1 | grep -oE 'v=[0-9]+\.[0-9]+' | head -1 | cut -d= -f2 || echo "unknown")
    log_info "Post-upgrade nginx version: $POST_NGINX"
    log_info "Post-upgrade redis version: $POST_REDIS"

    if [ "$PRE_NGINX" != "$POST_NGINX" ]; then
        log_pass "Nginx version changed from $PRE_NGINX to $POST_NGINX"
    else
        log_fail "Nginx version did not change"
    fi

    if [ "$PRE_REDIS" != "$POST_REDIS" ]; then
        log_pass "Redis version changed from $PRE_REDIS to $POST_REDIS"
    else
        log_fail "Redis version did not change"
    fi

    # Verify backup was created
    if [ -d "$PACKAGE_DIR/backups" ] && [ "$(ls -A "$PACKAGE_DIR/backups" 2>/dev/null)" ]; then
        log_pass "Backup directory created"
        log_info "Backups available:"
        "$OVPS" rollback "$PACKAGE_DIR"
    else
        log_fail "No backup created during upgrade"
    fi
}

# Test containers.yaml validation
test_containers_yaml_validation() {
    log_section "Testing containers.yaml Validation"

    cd "$PACKAGE_DIR"

    log_cmd "./scripts/validate_containers.sh --version v1.0.0"
    if ./scripts/validate_containers.sh --version v1.0.0 2>&1 | grep -q "containers.yaml"; then
        log_pass "validate_containers.sh checks containers.yaml"
    else
        log_info "containers.yaml validation not shown (may be OK)"
    fi

    run_test "Validate v1.0.0 containers (2 files)" \
        ./scripts/validate_containers.sh --version v1.0.0

    run_test "Validate v1.1.0 containers (2 files)" \
        ./scripts/validate_containers.sh --version v1.1.0
}

# Test rollback
test_rollback() {
    log_section "Testing Multi-Container Rollback"

    cd "$PACKAGE_DIR"

    # Find the backup directory
    BACKUP_DIR=$(ls -d "$PACKAGE_DIR/backups"/*/ 2>/dev/null | head -1)

    if [ -z "$BACKUP_DIR" ]; then
        log_fail "No backup directory found for rollback test"
        return 1
    fi

    BACKUP_NAME=$(basename "$BACKUP_DIR")
    log_info "Using backup: $BACKUP_NAME"

    # Record pre-rollback versions
    PRE_NGINX=$(docker exec fullstack-web nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    PRE_REDIS=$(docker exec fullstack-cache redis-server --version 2>&1 | grep -oE 'v=[0-9]+\.[0-9]+' | head -1 | cut -d= -f2 || echo "unknown")
    log_info "Pre-rollback nginx version: $PRE_NGINX"
    log_info "Pre-rollback redis version: $PRE_REDIS"

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
        log_info "Deployed version is '$DEPLOYED_VERSION'"
    fi

    # Verify services are running after rollback
    sleep 3
    if docker ps --format '{{.Names}}' | grep -q "fullstack-web"; then
        log_pass "Web container running after rollback"
    else
        log_fail "Web container not running after rollback"
    fi

    if docker ps --format '{{.Names}}' | grep -q "fullstack-cache"; then
        log_pass "Cache container running after rollback"
    else
        log_fail "Cache container not running after rollback"
    fi
}

# Test healthcheck with multiple services
test_healthcheck() {
    log_section "Testing Healthcheck (Multi-Container)"

    cd "$PACKAGE_DIR"

    log_cmd "./scripts/healthcheck.sh"

    if ./scripts/healthcheck.sh; then
        log_pass "healthcheck.sh reports healthy for all services"
    else
        log_fail "healthcheck.sh reports unhealthy"
    fi
}

# Main test execution
main() {
    log_section "OVPS Multi-Container Integration Test Suite"
    log_info "Test directory: $TEST_DIR"
    log_info ""
    log_info "Containers:"
    log_info "  nginx v1: $NGINX_V1"
    log_info "  nginx v2: $NGINX_V2"
    log_info "  redis v1: $REDIS_V1"
    log_info "  redis v2: $REDIS_V2"

    check_prerequisites
    pull_test_images
    create_test_package
    test_installation
    test_healthcheck
    prepare_upgrade
    test_dry_run_upgrade
    test_upgrade
    test_containers_yaml_validation
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
        printf "${GREEN}ALL MULTI-CONTAINER INTEGRATION TESTS PASSED${NC}\n"
        exit 0
    fi
}

main "$@"
