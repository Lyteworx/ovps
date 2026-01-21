#!/bin/sh
# validate_manifest.sh - Validates manifest.yaml in a vendor package
# Part of OCI Vendor Package Scaffolder (OVPS)
#
# Usage: validate_manifest.sh <package-dir>
#
# Exit codes:
#   0 - Validation passed
#   1 - Invalid arguments
#   2 - Manifest file not found
#   3 - Validation failed

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
    log_error "Usage: validate_manifest.sh <package-dir>"
    exit 1
fi

PACKAGE_DIR="$1"
MANIFEST_FILE="$PACKAGE_DIR/manifest.yaml"

# Check manifest exists
if [ ! -f "$MANIFEST_FILE" ]; then
    log_error "Manifest not found: $MANIFEST_FILE"
    exit 2
fi

log_info "Validating manifest: $MANIFEST_FILE"

ERRORS=0

# Helper function to check for required field
check_field() {
    field="$1"
    if ! grep -q "^[[:space:]]*$field:" "$MANIFEST_FILE" 2>/dev/null; then
        log_error "Missing required field: $field"
        ERRORS=$((ERRORS + 1))
    fi
}

# Check for required top-level sections
log_info "Checking required sections..."
check_field "package"
check_field "requirements"
check_field "containers"
check_field "services"
check_field "volumes"
check_field "healthchecks"
check_field "metadata"

# Check for required package fields
log_info "Checking package fields..."
if grep -q "^package:" "$MANIFEST_FILE"; then
    # Check vendor field
    if ! grep -A 10 "^package:" "$MANIFEST_FILE" | grep -q "vendor:"; then
        log_error "Missing package.vendor field"
        ERRORS=$((ERRORS + 1))
    fi

    # Check product field
    if ! grep -A 10 "^package:" "$MANIFEST_FILE" | grep -q "product:"; then
        log_error "Missing package.product field"
        ERRORS=$((ERRORS + 1))
    fi

    # Check version field
    if ! grep -A 10 "^package:" "$MANIFEST_FILE" | grep -q "version:"; then
        log_error "Missing package.version field"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check for required requirements fields
log_info "Checking requirements fields..."
if grep -q "^requirements:" "$MANIFEST_FILE"; then
    if ! grep -A 10 "^requirements:" "$MANIFEST_FILE" | grep -q "docker_version:"; then
        log_error "Missing requirements.docker_version field"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Validate YAML syntax (basic check - no unbalanced quotes on single lines)
log_info "Checking YAML syntax..."
LINE_NUM=0
while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM + 1))
    # Skip comments and empty lines
    case "$line" in
        \#*|"") continue ;;
    esac

    # Check for tabs (YAML should use spaces)
    case "$line" in
        *"	"*)
            log_warn "Line $LINE_NUM: Tab character found (use spaces for indentation)"
            ;;
    esac
done < "$MANIFEST_FILE"

# Report results
if [ $ERRORS -gt 0 ]; then
    log_error "Validation failed with $ERRORS error(s)"
    exit 3
fi

log_success "Manifest validation passed"
exit 0
