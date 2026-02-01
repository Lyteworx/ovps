#!/bin/sh
# upgrade.sh - Version transitions preserving persistent data
# Vendor Package: {{VENDOR_NAME}}/{{PRODUCT_NAME}} {{VERSION}}
#
# This script upgrades from a previous version while preserving
# persistent data and configurations.
#
# Usage: upgrade.sh [--from-version <version>] [--to-version <version>] [--backup-dir <dir>] [--dry-run]
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
TO_VERSION="{{VERSION}}"
BACKUP_DIR=""
DRY_RUN=0

# Configurable wait times (can be overridden via environment variables)
INIT_WAIT="${OVPS_INIT_WAIT:-5}"
HEALTH_WAIT="${OVPS_HEALTH_WAIT:-10}"

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --from-version)
            FROM_VERSION="$2"
            shift 2
            ;;
        --to-version)
            TO_VERSION="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Dry-run helper function
run_cmd() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[DRY-RUN] Would execute: $*"
        return 0
    else
        "$@"
    fi
}

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

if [ "$DRY_RUN" -eq 1 ]; then
    log_info "[DRY-RUN MODE] No changes will be made"
fi

log_info "Upgrading {{VENDOR_NAME}}/{{PRODUCT_NAME}} to $TO_VERSION"
log_info "=================================================="

# Step 1: Detect current running version
log_step "Detecting current version"
DEPLOYED_VERSION_FILE="$DATA_DIR/.deployed-version"

if [ -z "$FROM_VERSION" ]; then
    # Try to detect from deployed-version file first (most accurate)
    if [ -f "$DEPLOYED_VERSION_FILE" ]; then
        FROM_VERSION=$(cat "$DEPLOYED_VERSION_FILE" | tr -d '[:space:]')
        log_info "Detected version from deployed-version file: $FROM_VERSION"
    # Fall back to manifest (less accurate - shows package version, not deployed version)
    elif [ -f "$PACKAGE_DIR/manifest.yaml" ]; then
        FROM_VERSION=$(grep "version:" "$PACKAGE_DIR/manifest.yaml" | head -1 | awk '{print $2}' | tr -d '"')
        log_info "Detected version from manifest: $FROM_VERSION"
        log_warn "No .deployed-version file found - using manifest version"
    fi
fi

if [ -z "$FROM_VERSION" ]; then
    log_warn "Could not detect previous version"
    log_warn "Proceeding with fresh installation approach"
fi

if [ "$FROM_VERSION" = "$TO_VERSION" ]; then
    log_info "Already at version $TO_VERSION"
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
run_cmd mkdir -p "$BACKUP_DIR"

# Backup persistent data
if [ -d "$DATA_DIR/persistent" ] && [ "$(ls -A "$DATA_DIR/persistent" 2>/dev/null)" ]; then
    log_info "Backing up persistent data..."
    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[DRY-RUN] Would backup $DATA_DIR/persistent to $BACKUP_DIR/persistent"
    else
        cp -r "$DATA_DIR/persistent" "$BACKUP_DIR/persistent" || {
            log_error "Failed to backup persistent data"
            exit 3
        }
        log_success "Persistent data backed up"
    fi
else
    log_info "No persistent data to backup"
fi

# Backup compose configuration
if [ -d "$COMPOSE_DIR" ]; then
    log_info "Backing up compose configuration..."
    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[DRY-RUN] Would backup $COMPOSE_DIR to $BACKUP_DIR/compose"
    else
        cp -r "$COMPOSE_DIR" "$BACKUP_DIR/compose" || {
            log_error "Failed to backup compose configuration"
            exit 3
        }
        log_success "Compose configuration backed up"
    fi
fi

# Record upgrade metadata
if [ "$DRY_RUN" -eq 1 ]; then
    log_info "[DRY-RUN] Would record upgrade metadata"
else
    cat > "$BACKUP_DIR/upgrade_info.txt" << EOF
Upgrade performed: $(date -u +%Y-%m-%dT%H:%M:%SZ)
From version: ${FROM_VERSION:-unknown}
To version: $TO_VERSION
Backup directory: $BACKUP_DIR
EOF
    log_success "Backup completed: $BACKUP_DIR"
fi

# Step 4: Stop current services
log_step "Stopping current services"
cd "$COMPOSE_DIR"
if $COMPOSE_CMD ps -q 2>/dev/null | grep -q .; then
    log_info "Stopping running services..."
    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[DRY-RUN] Would stop services with: $COMPOSE_CMD down"
    else
        $COMPOSE_CMD down || {
            log_warn "Failed to stop services gracefully, forcing..."
            $COMPOSE_CMD down --remove-orphans 2>/dev/null || true
        }
        log_success "Services stopped"
    fi
else
    log_info "No running services detected"
fi

# Step 5: Load new container images
log_step "Loading new container images"
if [ "$DRY_RUN" -eq 1 ]; then
    log_info "[DRY-RUN] Would load containers for version: $TO_VERSION"
    log_info "[DRY-RUN] Command: $SCRIPT_DIR/validate_containers.sh --load --version $TO_VERSION"
else
    if ! "$SCRIPT_DIR/validate_containers.sh" --load --version "$TO_VERSION"; then
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
fi

# Step 6: Start services with new version
log_step "Starting upgraded services"
cd "$COMPOSE_DIR"
if [ "$DRY_RUN" -eq 1 ]; then
    log_info "[DRY-RUN] Would start services with: $COMPOSE_CMD up -d"
else
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
fi

# Step 7: Post-upgrade health check
log_step "Running post-upgrade health check"
if [ "$DRY_RUN" -eq 1 ]; then
    log_info "[DRY-RUN] Would wait ${HEALTH_WAIT}s for services to stabilize"
    log_info "[DRY-RUN] Would run: $SCRIPT_DIR/healthcheck.sh"
else
    log_info "Waiting for services to stabilize (${HEALTH_WAIT}s)..."
    sleep "$HEALTH_WAIT"

    if ! "$SCRIPT_DIR/healthcheck.sh"; then
        log_error "Post-upgrade health check failed"
        log_error "Services may need manual intervention"
        log_error "Backup available at: $BACKUP_DIR"
        exit 6
    fi

    # Update deployed version file
    echo "$TO_VERSION" > "$DEPLOYED_VERSION_FILE"
    log_info "Updated deployed version to: $TO_VERSION"
fi

# Upgrade complete
log_info "=================================================="
if [ "$DRY_RUN" -eq 1 ]; then
    log_success "[DRY-RUN] Upgrade simulation to $TO_VERSION completed"
    log_info ""
    log_info "Run without --dry-run to perform actual upgrade"
else
    log_success "Upgrade to $TO_VERSION completed successfully!"
    log_info ""
    log_info "Backup preserved at: $BACKUP_DIR"
    log_info "To rollback, use: ovps rollback <package-dir> $BACKUP_DIR"
fi
log_info ""

exit 0
