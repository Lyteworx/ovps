#!/bin/sh
# generate_version.sh - Adds a new version to an existing vendor package
# Part of OCI Vendor Package Scaffolder (OVPS)
#
# Usage: generate_version.sh <package-dir> <new-version>
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Package directory does not exist
#   3 - Version already exists
#   4 - Failed to create version

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# Validate arguments
if [ $# -lt 2 ]; then
    log_error "Usage: generate_version.sh <package-dir> <new-version>"
    exit 1
fi

PACKAGE_DIR="$1"
NEW_VERSION="$2"

# Validate package directory exists
if [ ! -d "$PACKAGE_DIR" ]; then
    log_error "Package directory does not exist: $PACKAGE_DIR"
    exit 2
fi

# Convert to absolute path
PACKAGE_DIR="$(cd "$PACKAGE_DIR" && pwd)"

CONTAINERS_DIR="$PACKAGE_DIR/containers"
NEW_VERSION_DIR="$CONTAINERS_DIR/$NEW_VERSION"
MANIFEST_FILE="$PACKAGE_DIR/manifest.yaml"

# Check if version already exists
if [ -d "$NEW_VERSION_DIR" ]; then
    log_error "Version already exists: $NEW_VERSION_DIR"
    exit 3
fi

log_info "Adding version $NEW_VERSION to package"

# Step 1: Create new version directory
log_info "Creating version directory: $NEW_VERSION_DIR"
mkdir -p "$NEW_VERSION_DIR"

# Add .gitkeep file
touch "$NEW_VERSION_DIR/.gitkeep"

log_success "Version directory created"

# Step 2: Extract package metadata from manifest
if [ -f "$MANIFEST_FILE" ]; then
    VENDOR_NAME=$(grep -A 10 "^package:" "$MANIFEST_FILE" | grep "vendor:" | head -1 | awk '{print $2}' | tr -d '"' || echo "vendor")
    PRODUCT_NAME=$(grep -A 10 "^package:" "$MANIFEST_FILE" | grep "product:" | head -1 | awk '{print $2}' | tr -d '"' || echo "product")
    OLD_VERSION=$(grep -A 10 "^package:" "$MANIFEST_FILE" | grep "version:" | head -1 | awk '{print $2}' | tr -d '"' || echo "v1.0.0")
else
    log_error "manifest.yaml not found in package"
    exit 4
fi

log_info "Package: $VENDOR_NAME/$PRODUCT_NAME"
log_info "Previous version: $OLD_VERSION"
log_info "New version: $NEW_VERSION"

# Step 3: Update manifest.yaml version
log_info "Updating manifest.yaml version..."
if [ -f "$MANIFEST_FILE" ]; then
    # Create backup
    cp "$MANIFEST_FILE" "$MANIFEST_FILE.bak"

    # Update version in package section
    sed -i.tmp "s/version:[[:space:]]*\"*${OLD_VERSION}\"*/version: \"$NEW_VERSION\"/" "$MANIFEST_FILE"
    rm -f "$MANIFEST_FILE.tmp"

    log_success "Manifest version updated"
fi

# Step 4: Regenerate scripts with new version
log_info "Regenerating scripts with new version..."
if ! "$SCRIPT_DIR/generate_scripts.sh" "$PACKAGE_DIR" "$VENDOR_NAME" "$PRODUCT_NAME" "$NEW_VERSION"; then
    log_error "Failed to regenerate scripts"
    # Restore manifest backup
    if [ -f "$MANIFEST_FILE.bak" ]; then
        mv "$MANIFEST_FILE.bak" "$MANIFEST_FILE"
    fi
    exit 4
fi

# Remove manifest backup
rm -f "$MANIFEST_FILE.bak"

# Step 5: Update docker-compose.yaml image tags if possible
COMPOSE_FILE="$PACKAGE_DIR/compose/docker-compose.yaml"
if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="$PACKAGE_DIR/compose/docker-compose.yml"
fi

if [ -f "$COMPOSE_FILE" ]; then
    log_info "Updating docker-compose.yaml image tags..."
    # Create backup
    cp "$COMPOSE_FILE" "$COMPOSE_FILE.bak"

    # Replace old version with new version in image tags
    # Only replace version tags that look like our version format (vX.Y.Z or X.Y.Z)
    sed -i.tmp "s/:${OLD_VERSION}$/:${NEW_VERSION}/g" "$COMPOSE_FILE"
    sed -i.tmp "s/:${OLD_VERSION}\"/:${NEW_VERSION}\"/g" "$COMPOSE_FILE"
    rm -f "$COMPOSE_FILE.tmp"

    # Check if any changes were made
    if diff -q "$COMPOSE_FILE" "$COMPOSE_FILE.bak" >/dev/null 2>&1; then
        log_info "No image tags updated (may need manual update)"
    else
        log_success "Docker-compose image tags updated"
    fi
    rm -f "$COMPOSE_FILE.bak"
fi

# Step 6: Regenerate checksums
log_info "Regenerating checksums..."
if ! "$SCRIPT_DIR/generate_checksums.sh" "$PACKAGE_DIR"; then
    log_warn "Failed to regenerate checksums (non-fatal)"
fi

# Summary
log_info ""
log_info "=================================================="
log_success "Version $NEW_VERSION added successfully!"
log_info ""
log_info "Next steps:"
log_info "  1. Add container images to: $NEW_VERSION_DIR/"
log_info "  2. Update docker-compose.yaml if needed"
log_info "  3. Regenerate checksums: ovps checksums $PACKAGE_DIR"
log_info "  4. Validate: ovps validate $PACKAGE_DIR"
log_info ""

exit 0
