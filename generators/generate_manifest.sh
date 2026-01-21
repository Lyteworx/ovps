#!/bin/sh
# generate_manifest.sh - Creates manifest.yaml for a vendor package
# Part of OCI Vendor Package Scaffolder (OVPS)
#
# Usage: generate_manifest.sh <package-dir> <vendor-name> <product-name> <version> [description]
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Package directory does not exist
#   3 - Template not found
#   4 - Failed to generate manifest

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$(dirname "$SCRIPT_DIR")/templates"

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

# Validate arguments
if [ $# -lt 4 ]; then
    log_error "Usage: generate_manifest.sh <package-dir> <vendor-name> <product-name> <version> [description]"
    exit 1
fi

PACKAGE_DIR="$1"
VENDOR_NAME="$2"
PRODUCT_NAME="$3"
VERSION="$4"
DESCRIPTION="${5:-$PRODUCT_NAME by $VENDOR_NAME}"

# Validate package directory exists
if [ ! -d "$PACKAGE_DIR" ]; then
    log_error "Package directory does not exist: $PACKAGE_DIR"
    exit 2
fi

# Validate template exists
TEMPLATE_FILE="$TEMPLATE_DIR/manifest.yaml.tpl"
if [ ! -f "$TEMPLATE_FILE" ]; then
    log_error "Template not found: $TEMPLATE_FILE"
    exit 3
fi

# Get current date in ISO format
GENERATED_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

log_info "Generating manifest.yaml for $VENDOR_NAME/$PRODUCT_NAME $VERSION"

# Read template and substitute variables
OUTPUT_FILE="$PACKAGE_DIR/manifest.yaml"

# Use sed to substitute template variables
sed -e "s|{{VENDOR_NAME}}|$VENDOR_NAME|g" \
    -e "s|{{PRODUCT_NAME}}|$PRODUCT_NAME|g" \
    -e "s|{{VERSION}}|$VERSION|g" \
    -e "s|{{DESCRIPTION}}|$DESCRIPTION|g" \
    -e "s|{{GENERATED_DATE}}|$GENERATED_DATE|g" \
    "$TEMPLATE_FILE" > "$OUTPUT_FILE" || {
    log_error "Failed to generate manifest"
    exit 4
}

log_success "Generated: $OUTPUT_FILE"

exit 0
