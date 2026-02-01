#!/bin/sh
# install.sh - Full deployment via Docker Compose
# Vendor Package: {{VENDOR_NAME}}/{{PRODUCT_NAME}} {{VERSION}}
#
# This script performs a complete installation of the vendor package.
# It is idempotent and safe to run multiple times.
#
# Exit codes:
#   0 - Installation successful
#   1 - Environment validation failed
#   2 - Container validation failed
#   3 - Failed to load containers
#   4 - Failed to start services
#   5 - Health check failed

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_DIR="$PACKAGE_DIR/compose"

# Configurable wait times (can be overridden via environment variables)
INIT_WAIT="${OVPS_INIT_WAIT:-5}"
HEALTH_WAIT="${OVPS_HEALTH_WAIT:-10}"

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

log_info "Installing {{VENDOR_NAME}}/{{PRODUCT_NAME}} {{VERSION}}"
log_info "=================================================="
log_info "Package directory: $PACKAGE_DIR"

# Step 1: Validate environment
log_step "Validating environment"
if ! "$SCRIPT_DIR/validate_environment.sh"; then
    log_error "Environment validation failed"
    exit 1
fi

# Step 2: Validate and load containers
log_step "Validating and loading containers"
if ! "$SCRIPT_DIR/validate_containers.sh" --load; then
    log_error "Container validation/loading failed"
    exit 2
fi

# Step 3: Initialize data directories
log_step "Initializing data directories"
DATA_DIR="$PACKAGE_DIR/data"

# Ensure persistent directory exists with proper permissions
if [ -d "$DATA_DIR/persistent" ]; then
    log_info "Persistent data directory exists"
else
    log_warn "Persistent data directory missing, creating..."
    mkdir -p "$DATA_DIR/persistent"
fi

# Copy sample data if persistent directory is empty and sample data exists
if [ -d "$DATA_DIR/sample_data" ] && [ "$(ls -A "$DATA_DIR/sample_data" 2>/dev/null)" ]; then
    if [ ! "$(ls -A "$DATA_DIR/persistent" 2>/dev/null)" ]; then
        log_info "Copying sample data to persistent directory..."
        cp -r "$DATA_DIR/sample_data/"* "$DATA_DIR/persistent/" 2>/dev/null || true
        log_success "Sample data copied"
    else
        log_info "Persistent directory not empty, skipping sample data copy"
    fi
fi

# Step 4: Check environment configuration
log_step "Checking environment configuration"

ENV_FILE="$COMPOSE_DIR/.env"
ENV_EXAMPLE="$COMPOSE_DIR/.env.example"

if [ -f "$ENV_FILE" ]; then
    log_success "Environment file found: .env"

    # Check for default/placeholder values that should be changed
    if grep -q "CHANGE_ME\|GENERATE_ME\|changeme" "$ENV_FILE" 2>/dev/null; then
        log_warn "=================================================="
        log_warn "WARNING: .env contains default placeholder values!"
        log_warn "Please edit $ENV_FILE and update:"
        grep -n "CHANGE_ME\|GENERATE_ME\|changeme" "$ENV_FILE" 2>/dev/null | while read -r line; do
            log_warn "  $line"
        done
        log_warn "=================================================="
        log_warn "Continuing with default values (NOT recommended for production)"
    fi
elif [ -f "$ENV_EXAMPLE" ]; then
    log_warn "No .env file found!"
    log_warn "Creating .env from .env.example..."
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    log_warn "=================================================="
    log_warn "IMPORTANT: Edit $ENV_FILE before production use!"
    log_warn "At minimum, change these values:"
    log_warn "  - DB_PASSWORD"
    log_warn "  - APP_SECRET_KEY"
    log_warn "=================================================="
else
    log_info "No .env.example found, proceeding without environment file"
fi

# Step 5: Start services with Docker Compose
log_step "Starting services"

COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yaml"
if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "docker-compose.yaml not found in $COMPOSE_DIR"
    exit 4
fi

log_info "Using compose file: $COMPOSE_FILE"

# Determine compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# Change to compose directory and start
cd "$COMPOSE_DIR"

log_info "Using pre-loaded local images (offline mode)"

log_info "Starting services..."
if ! $COMPOSE_CMD up -d; then
    log_error "Failed to start services"
    exit 4
fi

log_success "Services started"

# Step 6: Wait for services and run health check
log_step "Running health checks"
log_info "Waiting for services to initialize (${INIT_WAIT}s)..."
sleep "$INIT_WAIT"

if ! "$SCRIPT_DIR/healthcheck.sh"; then
    log_warn "Initial health check failed, waiting longer (${HEALTH_WAIT}s)..."
    sleep "$HEALTH_WAIT"
    if ! "$SCRIPT_DIR/healthcheck.sh"; then
        log_error "Health check failed after extended wait"
        log_error "Check logs with: $COMPOSE_CMD logs"
        exit 5
    fi
fi

# Track deployed version
DEPLOYED_VERSION_FILE="$PACKAGE_DIR/data/.deployed-version"
echo "{{VERSION}}" > "$DEPLOYED_VERSION_FILE"
log_info "Recorded deployed version: {{VERSION}}"

# Installation complete
log_info "=================================================="
log_success "Installation completed successfully!"
log_info ""
log_info "Useful commands:"
log_info "  View logs:     cd $COMPOSE_DIR && $COMPOSE_CMD logs -f"
log_info "  Stop:          cd $COMPOSE_DIR && $COMPOSE_CMD down"
log_info "  Health check:  $SCRIPT_DIR/healthcheck.sh"
log_info ""

exit 0
