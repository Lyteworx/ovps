#!/bin/sh
# generate_compose.sh - Creates docker-compose.yaml for a vendor package
# Part of OCI Vendor Package Scaffolder (OVPS)
#
# Usage: generate_compose.sh <package-dir> <vendor-name> <product-name> <version>
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Package directory does not exist
#   3 - Template not found
#   4 - Failed to generate compose file

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
    log_error "Usage: generate_compose.sh <package-dir> <vendor-name> <product-name> <version>"
    exit 1
fi

PACKAGE_DIR="$1"
VENDOR_NAME="$2"
PRODUCT_NAME="$3"
VERSION="$4"

# Validate package directory exists
if [ ! -d "$PACKAGE_DIR" ]; then
    log_error "Package directory does not exist: $PACKAGE_DIR"
    exit 2
fi

# Validate template exists
TEMPLATE_FILE="$TEMPLATE_DIR/docker-compose.yaml.tpl"
if [ ! -f "$TEMPLATE_FILE" ]; then
    log_error "Template not found: $TEMPLATE_FILE"
    exit 3
fi

# Ensure compose directory exists
COMPOSE_DIR="$PACKAGE_DIR/compose"
mkdir -p "$COMPOSE_DIR"

log_info "Generating docker-compose.yaml for $VENDOR_NAME/$PRODUCT_NAME $VERSION"

# Get current date in ISO format
GENERATED_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Output file
OUTPUT_FILE="$COMPOSE_DIR/docker-compose.yaml"

# Substitute template variables
sed -e "s|{{VENDOR_NAME}}|$VENDOR_NAME|g" \
    -e "s|{{PRODUCT_NAME}}|$PRODUCT_NAME|g" \
    -e "s|{{VERSION}}|$VERSION|g" \
    "$TEMPLATE_FILE" > "$OUTPUT_FILE" || {
    log_error "Failed to generate docker-compose.yaml"
    exit 4
}

log_success "Generated: $OUTPUT_FILE"

# Generate .env.example
ENV_TEMPLATE="$TEMPLATE_DIR/env.example.tpl"
if [ -f "$ENV_TEMPLATE" ]; then
    log_info "Generating .env.example"
    ENV_OUTPUT="$COMPOSE_DIR/.env.example"

    sed -e "s|{{VENDOR_NAME}}|$VENDOR_NAME|g" \
        -e "s|{{PRODUCT_NAME}}|$PRODUCT_NAME|g" \
        -e "s|{{VERSION}}|$VERSION|g" \
        -e "s|{{GENERATED_DATE}}|$GENERATED_DATE|g" \
        "$ENV_TEMPLATE" > "$ENV_OUTPUT" || {
        log_error "Failed to generate .env.example"
        exit 4
    }

    log_success "Generated: $ENV_OUTPUT"
fi

exit 0
