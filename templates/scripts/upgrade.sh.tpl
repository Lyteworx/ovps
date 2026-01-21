#!/bin/sh
# upgrade.sh - Version transitions preserving persistent data
# Vendor Package: {{VENDOR_NAME}}/{{PRODUCT_NAME}} {{VERSION}}
#
# This script upgrades from a previous version while preserving
# persistent data and configurations.
#
# Usage: upgrade.sh [--from-version <version>] [--backup-dir <dir>]
#
# Exit codes:
#   0 - Upgrade successful
#   1 - Invalid arguments
#   2 - Previous version not detected
#   3 - Backup failed
#   4 - Container update failed
#   5 - Service restart failed
#   6 - Health check failed
#   7 - Rollback required (automatic rollback attempted)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_DIR="$PACKAGE_DIR/compose"
DATA_DIR="$PACKAGE_DIR/data"

CURRENT_VERSION="{{VERSION}}"
FROM_VERSION=""
BACKUP_DIR=""

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --from-version)
            FROM_VERSION="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

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

log_step() {
    printf '\n[STEP] %s\n' "$1"
    printf '       %s\n' "$(echo "$1" | sed 's/./-/g')"
}

# Set default backup directory
if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR="$PACKAGE_DIR/backups/$(date +%Y%m%d_%H%M%S)"
fi

# Determine compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

log_info "Upgrading {{VENDOR_NAME}}/{{PRODUCT_NAME}} to $CURRENT_VERSION"
log_info "=================================================="

# Step 1: Detect current running version
log_step "Detecting current version"
if [ -z "$FROM_VERSION" ]; then
    # Try to detect from running containers or manifest
    if [ -f "$PACKAGE_DIR/manifest.yaml" ]; then
        FROM_VERSION=$(grep "version:" "$PACKAGE_DIR/manifest.yaml" | head -1 | awk '{print $2}' | tr -d '"')
        log_info "Detected version from manifest: $FROM_VERSION"
    fi
fi

if [ -z "$FROM_VERSION" ]; then
    log_warn "Could not detect previous version"
    log_warn "Proceeding with fresh installation approach"
fi

if [ "$FROM_VERSION" = "$CURRENT_VERSION" ]; then
    log_info "Already at version $CURRENT_VERSION"
    log_info "Running reinstallation..."
fi

# Step 2: Pre-upgrade health check
log_step "Running pre-upgrade health check"
if "$SCRIPT_DIR/healthcheck.sh" 2>/dev/null; then
    log_success "Current deployment is healthy"
else
    log_warn "Current deployment may not be healthy"
    log_warn "Proceeding with upgrade anyway"
fi

# Step 3: Create backup
log_step "Creating backup"
log_info "Backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup persistent data
if [ -d "$DATA_DIR/persistent" ] && [ "$(ls -A "$DATA_DIR/persistent" 2>/dev/null)" ]; then
    log_info "Backing up persistent data..."
    cp -r "$DATA_DIR/persistent" "$BACKUP_DIR/persistent" || {
        log_error "Failed to backup persistent data"
        exit 3
    }
    log_success "Persistent data backed up"
else
    log_info "No persistent data to backup"
fi

# Backup compose configuration
if [ -d "$COMPOSE_DIR" ]; then
    log_info "Backing up compose configuration..."
    cp -r "$COMPOSE_DIR" "$BACKUP_DIR/compose" || {
        log_error "Failed to backup compose configuration"
        exit 3
    }
    log_success "Compose configuration backed up"
fi

# Record upgrade metadata
cat > "$BACKUP_DIR/upgrade_info.txt" << EOF
Upgrade performed: $(date -u +%Y-%m-%dT%H:%M:%SZ)
From version: ${FROM_VERSION:-unknown}
To version: $CURRENT_VERSION
Backup directory: $BACKUP_DIR
EOF

log_success "Backup completed: $BACKUP_DIR"

# Step 4: Stop current services
log_step "Stopping current services"
cd "$COMPOSE_DIR"
if $COMPOSE_CMD ps -q 2>/dev/null | grep -q .; then
    log_info "Stopping running services..."
    $COMPOSE_CMD down || {
        log_warn "Failed to stop services gracefully, forcing..."
        $COMPOSE_CMD down --remove-orphans 2>/dev/null || true
    }
    log_success "Services stopped"
else
    log_info "No running services detected"
fi

# Step 5: Load new container images
log_step "Loading new container images"
if ! "$SCRIPT_DIR/validate_containers.sh" --load; then
    log_error "Failed to load new container images"
    log_error "Attempting rollback..."
    # Attempt to restore from backup
    if [ -d "$BACKUP_DIR/compose" ]; then
        cp -r "$BACKUP_DIR/compose/"* "$COMPOSE_DIR/"
    fi
    cd "$COMPOSE_DIR"
    $COMPOSE_CMD up -d 2>/dev/null || true
    exit 4
fi

# Step 6: Start services with new version
log_step "Starting upgraded services"
cd "$COMPOSE_DIR"
if ! $COMPOSE_CMD up -d; then
    log_error "Failed to start upgraded services"
    log_error "Attempting rollback..."
    # Attempt to restore persistent data
    if [ -d "$BACKUP_DIR/persistent" ]; then
        rm -rf "$DATA_DIR/persistent"
        cp -r "$BACKUP_DIR/persistent" "$DATA_DIR/persistent"
    fi
    $COMPOSE_CMD up -d 2>/dev/null || true
    exit 5
fi

log_success "Services started"

# Step 7: Post-upgrade health check
log_step "Running post-upgrade health check"
log_info "Waiting for services to stabilize..."
sleep 10

if ! "$SCRIPT_DIR/healthcheck.sh"; then
    log_error "Post-upgrade health check failed"
    log_error "Services may need manual intervention"
    log_error "Backup available at: $BACKUP_DIR"
    exit 6
fi

# Upgrade complete
log_info "=================================================="
log_success "Upgrade to $CURRENT_VERSION completed successfully!"
log_info ""
log_info "Backup preserved at: $BACKUP_DIR"
log_info "To rollback, restore from backup and restart services"
log_info ""

exit 0
