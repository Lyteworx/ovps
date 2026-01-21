#!/bin/sh
# validate_containers.sh - Load and verify container images
# Vendor Package: sample-vendor/demo-app v1.0.0
#
# This script validates container images in the package and optionally
# loads them into the local Docker daemon.
#
# Usage: validate_containers.sh [--load]
#   --load    Load container images into Docker (default: validate only)
#
# Exit codes:
#   0 - All containers valid
#   1 - Container file not found
#   2 - Container file corrupted
#   3 - Failed to load container

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
CONTAINERS_DIR="$PACKAGE_DIR/containers/v1.0.0"
CHECKSUMS_FILE="$PACKAGE_DIR/checksums/sha256.txt"

LOAD_IMAGES=0

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --load)
            LOAD_IMAGES=1
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

log_info "Validating containers for sample-vendor/demo-app v1.0.0"
log_info "=================================================="
log_info "Container directory: $CONTAINERS_DIR"

# Check container directory exists
if [ ! -d "$CONTAINERS_DIR" ]; then
    log_error "Container directory not found: $CONTAINERS_DIR"
    exit 1
fi

# Find container image files
CONTAINER_FILES=$(find "$CONTAINERS_DIR" -type f \( -name "*.tar.gz" -o -name "*.tar" -o -name "*.oci" \) 2>/dev/null || true)

if [ -z "$CONTAINER_FILES" ]; then
    log_warn "No container image files found in $CONTAINERS_DIR"
    log_warn "Expected formats: .tar.gz, .tar, or .oci"
    exit 0
fi

# Count and list containers
CONTAINER_COUNT=$(echo "$CONTAINER_FILES" | wc -l | tr -d ' ')
log_info "Found $CONTAINER_COUNT container image(s)"

ERRORS=0

# Validate each container file
for container_file in $CONTAINER_FILES; do
    filename=$(basename "$container_file")
    log_info "Validating: $filename"

    # Check file exists and is readable
    if [ ! -r "$container_file" ]; then
        log_error "Cannot read container file: $container_file"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Check file size
    file_size=$(wc -c < "$container_file" | tr -d ' ')
    if [ "$file_size" -lt 1000 ]; then
        log_error "Container file appears too small: $container_file ($file_size bytes)"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Verify checksum if checksums file exists
    if [ -f "$CHECKSUMS_FILE" ]; then
        # Get relative path for checksum lookup
        rel_path="containers/v1.0.0/$filename"
        expected_checksum=$(grep "$rel_path" "$CHECKSUMS_FILE" 2>/dev/null | awk '{print $1}' || true)

        if [ -n "$expected_checksum" ]; then
            log_info "Verifying checksum for $filename..."
            if command -v sha256sum >/dev/null 2>&1; then
                actual_checksum=$(sha256sum "$container_file" | awk '{print $1}')
            elif command -v shasum >/dev/null 2>&1; then
                actual_checksum=$(shasum -a 256 "$container_file" | awk '{print $1}')
            else
                log_warn "No sha256sum or shasum available, skipping checksum verification"
                actual_checksum=""
            fi

            if [ -n "$actual_checksum" ]; then
                if [ "$actual_checksum" = "$expected_checksum" ]; then
                    log_success "Checksum verified: $filename"
                else
                    log_error "Checksum mismatch for $filename"
                    log_error "Expected: $expected_checksum"
                    log_error "Actual:   $actual_checksum"
                    ERRORS=$((ERRORS + 1))
                    continue
                fi
            fi
        else
            log_warn "No checksum found for $filename"
        fi
    fi

    # Validate container format
    case "$filename" in
        *.tar.gz)
            # Verify gzip format
            if ! gzip -t "$container_file" 2>/dev/null; then
                log_error "Invalid gzip format: $filename"
                ERRORS=$((ERRORS + 1))
                continue
            fi
            log_success "Valid gzip archive: $filename"
            ;;
        *.tar)
            # Verify tar format
            if ! tar -tf "$container_file" >/dev/null 2>&1; then
                log_error "Invalid tar format: $filename"
                ERRORS=$((ERRORS + 1))
                continue
            fi
            log_success "Valid tar archive: $filename"
            ;;
        *.oci)
            # OCI format validation
            log_info "OCI format detected: $filename"
            ;;
    esac

    # Load image if requested
    if [ "$LOAD_IMAGES" -eq 1 ]; then
        log_info "Loading image: $filename"
        case "$filename" in
            *.tar.gz)
                if ! docker load < "$container_file" 2>&1; then
                    log_error "Failed to load container: $filename"
                    ERRORS=$((ERRORS + 1))
                    continue
                fi
                ;;
            *.tar)
                if ! docker load < "$container_file" 2>&1; then
                    log_error "Failed to load container: $filename"
                    ERRORS=$((ERRORS + 1))
                    continue
                fi
                ;;
            *.oci)
                log_warn "OCI format loading not yet implemented"
                ;;
        esac
        log_success "Loaded: $filename"
    fi
done

log_info "=================================================="
if [ $ERRORS -gt 0 ]; then
    log_error "Container validation completed with $ERRORS error(s)"
    exit 2
fi

log_success "Container validation completed successfully"
exit 0
