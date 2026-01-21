#!/bin/sh
# generate_scripts.sh - Creates required shell scripts for a vendor package
# Part of OCI Vendor Package Scaffolder (OVPS)
#
# Usage: generate_scripts.sh <package-dir> <vendor-name> <product-name> <version>
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Package directory does not exist
#   3 - Templates not found
#   4 - Failed to generate scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$(dirname "$SCRIPT_DIR")/templates/scripts"

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
    log_error "Usage: generate_scripts.sh <package-dir> <vendor-name> <product-name> <version>"
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

# Validate templates directory exists
if [ ! -d "$TEMPLATE_DIR" ]; then
    log_error "Templates directory not found: $TEMPLATE_DIR"
    exit 3
fi

# Ensure scripts directory exists
SCRIPTS_DIR="$PACKAGE_DIR/scripts"
mkdir -p "$SCRIPTS_DIR"

log_info "Generating scripts for $VENDOR_NAME/$PRODUCT_NAME $VERSION"

# List of required scripts
SCRIPTS="validate_environment validate_containers install upgrade healthcheck"

for script_name in $SCRIPTS; do
    TEMPLATE_FILE="$TEMPLATE_DIR/${script_name}.sh.tpl"
    OUTPUT_FILE="$SCRIPTS_DIR/${script_name}.sh"

    if [ ! -f "$TEMPLATE_FILE" ]; then
        log_error "Template not found: $TEMPLATE_FILE"
        exit 3
    fi

    log_info "Generating: ${script_name}.sh"

    # Substitute template variables
    sed -e "s|{{VENDOR_NAME}}|$VENDOR_NAME|g" \
        -e "s|{{PRODUCT_NAME}}|$PRODUCT_NAME|g" \
        -e "s|{{VERSION}}|$VERSION|g" \
        "$TEMPLATE_FILE" > "$OUTPUT_FILE" || {
        log_error "Failed to generate $script_name.sh"
        exit 4
    }

    # Make executable
    chmod +x "$OUTPUT_FILE"

    log_success "Generated: $OUTPUT_FILE"
done

log_success "All scripts generated successfully"
exit 0
