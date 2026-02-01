#!/bin/sh
# healthcheck.sh - Verify containers running and services responding
# Vendor Package: {{VENDOR_NAME}}/{{PRODUCT_NAME}} {{VERSION}}
#
# This script checks the health of all deployed services.
#
# Exit codes:
#   0 - All services healthy
#   1 - One or more containers not running
#   2 - One or more services not responding
#   3 - Configuration error

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_DIR="$PACKAGE_DIR/compose"
MANIFEST_FILE="$PACKAGE_DIR/manifest.yaml"

# Configuration (can be overridden via environment variables)
HEALTH_CHECK_TIMEOUT="${OVPS_HEALTH_CHECK_TIMEOUT:-30}"
HEALTH_CHECK_RETRIES="${OVPS_HEALTH_CHECK_RETRIES:-3}"

# Logging functions
log_info() {
    printf '[INFO] %s\n' "$1"
}

log_error() {
    printf '[ERROR] %s\n' "$1" >&2
}

log_success() {
    printf '[SUCCESS] %s\n' "$1"
}

log_warn() {
    printf '[WARN] %s\n' "$1" >&2
}

# Determine compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

log_info "Health check for {{VENDOR_NAME}}/{{PRODUCT_NAME}} {{VERSION}}"
log_info "=================================================="

ERRORS=0

# Check 1: Verify Docker is accessible
log_info "Checking Docker daemon..."
if ! docker info >/dev/null 2>&1; then
    log_error "Docker daemon is not accessible"
    exit 3
fi
log_success "Docker daemon is accessible"

# Check 2: Verify compose file exists
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yaml"
if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "docker-compose.yaml not found in $COMPOSE_DIR"
    exit 3
fi

# Check 3: Verify containers are running
log_info "Checking container status..."
cd "$COMPOSE_DIR"

RUNNING_CONTAINERS=$($COMPOSE_CMD ps -q 2>/dev/null | wc -l | tr -d ' ')
if [ "$RUNNING_CONTAINERS" -eq 0 ]; then
    log_error "No containers are running"
    log_error "Start services with: install.sh"
    exit 1
fi

log_info "Running containers: $RUNNING_CONTAINERS"

# Check each container status
$COMPOSE_CMD ps --format "table {{.Service}}\t{{.State}}\t{{.Status}}" 2>/dev/null || $COMPOSE_CMD ps

# Get list of services that should be running
EXPECTED_SERVICES=$($COMPOSE_CMD config --services 2>/dev/null || true)

for service in $EXPECTED_SERVICES; do
    # Check if service container is running
    container_status=$($COMPOSE_CMD ps "$service" --format "{{.State}}" 2>/dev/null || echo "unknown")

    case "$container_status" in
        running|Running)
            log_success "Service '$service' is running"
            ;;
        exited|Exited)
            log_error "Service '$service' has exited"
            ERRORS=$((ERRORS + 1))
            ;;
        *)
            log_warn "Service '$service' status: $container_status"
            ;;
    esac

    # Check Docker health status if available
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "${service}" 2>/dev/null || echo "none")
    case "$health_status" in
        healthy)
            log_success "Service '$service' Docker health: healthy"
            ;;
        unhealthy)
            log_error "Service '$service' Docker health: unhealthy"
            ERRORS=$((ERRORS + 1))
            ;;
        starting)
            log_warn "Service '$service' Docker health: starting"
            ;;
        none|"")
            # No health check configured, that's okay
            ;;
    esac
done

# Check 4: Verify services are responding (if endpoints defined in manifest)
log_info "Checking service endpoints..."

if [ -f "$MANIFEST_FILE" ]; then
    # Extract health check endpoints from manifest (basic parsing)
    ENDPOINTS=$(grep -A 5 "healthchecks:" "$MANIFEST_FILE" 2>/dev/null | grep "endpoint:" | sed 's/.*endpoint:[[:space:]]*//' | tr -d '"' || true)

    for endpoint in $ENDPOINTS; do
        if [ -n "$endpoint" ]; then
            log_info "Checking endpoint: $endpoint"

            # Try to reach the endpoint
            retries=$HEALTH_CHECK_RETRIES
            while [ $retries -gt 0 ]; do
                if command -v curl >/dev/null 2>&1; then
                    if curl -sf --max-time "$HEALTH_CHECK_TIMEOUT" "$endpoint" >/dev/null 2>&1; then
                        log_success "Endpoint responding: $endpoint"
                        break
                    fi
                elif command -v wget >/dev/null 2>&1; then
                    if wget -q --timeout="$HEALTH_CHECK_TIMEOUT" -O /dev/null "$endpoint" 2>/dev/null; then
                        log_success "Endpoint responding: $endpoint"
                        break
                    fi
                else
                    log_warn "No curl or wget available for HTTP health checks"
                    break
                fi

                retries=$((retries - 1))
                if [ $retries -gt 0 ]; then
                    log_warn "Endpoint not responding, retrying in 2 seconds..."
                    sleep 2
                else
                    log_error "Endpoint not responding after $HEALTH_CHECK_RETRIES attempts: $endpoint"
                    ERRORS=$((ERRORS + 1))
                fi
            done
        fi
    done
else
    log_info "No manifest found, skipping endpoint checks"
fi

# Check 5: Verify data directories are accessible
log_info "Checking data directories..."
if [ -d "$PACKAGE_DIR/data/persistent" ]; then
    if [ -w "$PACKAGE_DIR/data/persistent" ]; then
        log_success "Persistent data directory is writable"
    else
        log_warn "Persistent data directory may not be writable"
    fi
fi

# Summary
log_info "=================================================="
if [ $ERRORS -gt 0 ]; then
    log_error "Health check completed with $ERRORS error(s)"
    log_error "Review logs with: cd $COMPOSE_DIR && $COMPOSE_CMD logs"
    exit 1
fi

log_success "All health checks passed"
exit 0
