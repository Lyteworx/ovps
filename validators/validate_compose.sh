#!/bin/sh
# validate_compose.sh - Validates docker-compose.yaml in a vendor package
# Part of OCI Vendor Package Scaffolder (OVPS)
#
# Usage: validate_compose.sh <package-dir>
#
# Exit codes:
#   0 - Validation passed
#   1 - Invalid arguments
#   2 - Compose file not found
#   3 - Validation failed
#   4 - Docker Compose not available

set -e

# Logging functions
log_info() {
    printf '[INFO] %s\n' "$1"
}

log_error() {
    printf '[ERROR] %s\n' "$1" >&2
}

log_warn() {
    printf '[WARN] %s\n' "$1" >&2
}

log_success() {
    printf '[SUCCESS] %s\n' "$1"
}

# Validate arguments
if [ $# -lt 1 ]; then
    log_error "Usage: validate_compose.sh <package-dir>"
    exit 1
fi

PACKAGE_DIR="$1"
COMPOSE_DIR="$PACKAGE_DIR/compose"

# Find compose file
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yaml"
if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "Compose file not found in: $COMPOSE_DIR"
    log_error "Expected: docker-compose.yaml or docker-compose.yml"
    exit 2
fi

log_info "Validating compose file: $COMPOSE_FILE"

ERRORS=0
WARNINGS=0

# Basic YAML structure checks
log_info "Checking YAML structure..."

# Check for tabs (YAML should use spaces)
if grep -q '	' "$COMPOSE_FILE" 2>/dev/null; then
    log_warn "Tab characters found (YAML requires spaces for indentation)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for version field
if ! grep -q '^version:' "$COMPOSE_FILE" 2>/dev/null; then
    log_warn "Missing 'version' field (recommended for compatibility)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for services section
if ! grep -q '^services:' "$COMPOSE_FILE" 2>/dev/null; then
    log_error "Missing 'services' section"
    ERRORS=$((ERRORS + 1))
fi

# Check for remote image references (should use local images)
log_info "Checking for remote image references..."
if grep -E 'image:.*docker\.io|image:.*gcr\.io|image:.*quay\.io|image:.*ghcr\.io' "$COMPOSE_FILE" 2>/dev/null; then
    log_warn "Remote registry references detected (package should use local images)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for build contexts (should use pre-built images)
if grep -qE '^\s+build:' "$COMPOSE_FILE" 2>/dev/null; then
    log_warn "Build contexts found (packages should use pre-built images)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check volume paths use relative paths to data directory
log_info "Checking volume configurations..."
if grep -E 'volumes:' "$COMPOSE_FILE" >/dev/null 2>&1; then
    # Look for absolute paths that might not be portable
    if grep -E '\s+-\s+/[^.]' "$COMPOSE_FILE" 2>/dev/null | grep -v '/var/run' >/dev/null 2>&1; then
        log_warn "Absolute volume paths detected (consider using relative paths)"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Check for environment file
log_info "Checking environment configuration..."
if [ -f "$COMPOSE_DIR/.env.example" ]; then
    log_success "Found: .env.example"

    # Check if .env exists
    if [ -f "$COMPOSE_DIR/.env" ]; then
        log_success "Found: .env"

        # Check for placeholder values in .env
        if grep -q "CHANGE_ME\|GENERATE_ME\|changeme" "$COMPOSE_DIR/.env" 2>/dev/null; then
            log_warn ".env contains placeholder values that should be changed for production"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        log_warn "No .env file found (copy from .env.example before deployment)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    log_info "No .env.example found (environment variables may not be required)"
fi

# Check that .env is not committed (security check)
if [ -f "$COMPOSE_DIR/.env" ]; then
    # Check if there's a .gitignore that excludes .env
    PACKAGE_DIR="$(dirname "$COMPOSE_DIR")"
    if [ -f "$PACKAGE_DIR/.gitignore" ]; then
        if grep -q "\.env" "$PACKAGE_DIR/.gitignore" 2>/dev/null; then
            log_success ".env is listed in .gitignore"
        else
            log_warn ".env exists but is not in .gitignore (secrets may be exposed)"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
fi

# Validate with Docker Compose if available
log_info "Validating with Docker Compose..."

# Determine compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    log_warn "Docker Compose not available, skipping compose validation"
    COMPOSE_CMD=""
fi

if [ -n "$COMPOSE_CMD" ]; then
    cd "$COMPOSE_DIR"

    # Config validation (doesn't start anything, just validates)
    if $COMPOSE_CMD config >/dev/null 2>&1; then
        log_success "Docker Compose config validation passed"
    else
        log_error "Docker Compose config validation failed"
        $COMPOSE_CMD config 2>&1 | head -20 || true
        ERRORS=$((ERRORS + 1))
    fi

    # List services
    SERVICES=$($COMPOSE_CMD config --services 2>/dev/null || true)
    if [ -n "$SERVICES" ]; then
        SERVICE_COUNT=$(echo "$SERVICES" | wc -l | tr -d ' ')
        log_info "Services defined: $SERVICE_COUNT"
        for service in $SERVICES; do
            log_info "  - $service"
        done
    fi
fi

# Check for recommended configurations
log_info "Checking recommended configurations..."

# Check for restart policy
if ! grep -q 'restart:' "$COMPOSE_FILE" 2>/dev/null; then
    log_warn "No restart policy defined (consider 'restart: unless-stopped')"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for health checks
if ! grep -q 'healthcheck:' "$COMPOSE_FILE" 2>/dev/null; then
    log_warn "No health checks defined (recommended for production)"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
log_info "=================================================="
log_info "Errors: $ERRORS"
log_info "Warnings: $WARNINGS"

if [ $ERRORS -gt 0 ]; then
    log_error "Compose validation failed with $ERRORS error(s)"
    exit 3
fi

if [ $WARNINGS -gt 0 ]; then
    log_warn "Compose validation passed with $WARNINGS warning(s)"
else
    log_success "Compose validation passed"
fi

exit 0
