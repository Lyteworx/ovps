#!/bin/sh
# generate_scaffold.sh - Creates the base directory structure for a vendor package
# Part of OCI Vendor Package Scaffolder (OVPS)
#
# Usage: generate_scaffold.sh <output-dir> <vendor-name> <product-name> <version>
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Directory already exists
#   3 - Failed to create directory structure

set -e

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
    log_error "Usage: generate_scaffold.sh <output-dir> <vendor-name> <product-name> <version>"
    exit 1
fi

OUTPUT_DIR="$1"
VENDOR_NAME="$2"
PRODUCT_NAME="$3"
VERSION="$4"

# Validate version format (vX.Y.Z)
case "$VERSION" in
    v[0-9]*.[0-9]*.[0-9]*)
        ;;
    *)
        log_error "Version must be in format vX.Y.Z (e.g., v1.0.0)"
        exit 1
        ;;
esac

# Check if output directory already exists
if [ -d "$OUTPUT_DIR" ]; then
    log_error "Directory already exists: $OUTPUT_DIR"
    exit 2
fi

log_info "Creating vendor package scaffold for $VENDOR_NAME/$PRODUCT_NAME $VERSION"
log_info "Output directory: $OUTPUT_DIR"

# Create base directory structure
log_info "Creating directory structure..."

mkdir -p "$OUTPUT_DIR" || {
    log_error "Failed to create output directory"
    exit 3
}

# Create required directories
mkdir -p "$OUTPUT_DIR/docs"
mkdir -p "$OUTPUT_DIR/containers/$VERSION"
mkdir -p "$OUTPUT_DIR/compose"
mkdir -p "$OUTPUT_DIR/scripts"
mkdir -p "$OUTPUT_DIR/data/persistent"
mkdir -p "$OUTPUT_DIR/data/sample_data"
mkdir -p "$OUTPUT_DIR/data/schemas"
mkdir -p "$OUTPUT_DIR/checksums"

# Create placeholder files with explanatory comments
cat > "$OUTPUT_DIR/docs/.gitkeep" << 'EOF'
# Documentation directory
# Place plain text documentation files here:
# - overview.txt: Product overview and purpose
# - install.txt: Installation instructions
# - upgrade.txt: Upgrade procedures
EOF

cat > "$OUTPUT_DIR/containers/$VERSION/.gitkeep" << 'EOF'
# Container images directory
# Place container images here in one of these formats:
# - .tar.gz (Docker save format, gzip compressed)
# - .oci (OCI image layout format)
#
# Images must be loadable offline using:
#   docker load < image.tar.gz
EOF

cat > "$OUTPUT_DIR/compose/.gitkeep" << 'EOF'
# Docker Compose directory
# Place docker-compose.yaml here
# Requirements:
# - Must reference local images only (no remote pulls)
# - Must run standalone without internet access
# - Must define all required services
EOF

cat > "$OUTPUT_DIR/scripts/.gitkeep" << 'EOF'
# Scripts directory
# Required POSIX shell scripts:
# - validate_environment.sh: Verify Docker, disk space, CPU architecture
# - validate_containers.sh: Load and verify container images
# - install.sh: Full deployment via Docker Compose
# - upgrade.sh: Version transitions preserving persistent data
# - healthcheck.sh: Verify containers running and services responding
#
# All scripts must:
# - Be POSIX-compliant (#!/bin/sh)
# - Be idempotent (safe to run multiple times)
# - Use explicit exit codes
# - Provide verbose logging
EOF

cat > "$OUTPUT_DIR/data/persistent/.gitkeep" << 'EOF'
# Persistent data directory
# This directory maps to container volumes for persistent storage
# Data here survives container restarts and upgrades
EOF

cat > "$OUTPUT_DIR/data/sample_data/.gitkeep" << 'EOF'
# Sample data directory
# Place sample/seed data for initial deployment
# This data is copied during first install only
EOF

cat > "$OUTPUT_DIR/data/schemas/.gitkeep" << 'EOF'
# Schema directory
# Place database schemas, configuration schemas, or
# other structural definitions here
EOF

cat > "$OUTPUT_DIR/checksums/.gitkeep" << 'EOF'
# Checksums directory
# sha256.txt will be generated here containing SHA256 hashes
# of all package files for integrity verification
EOF

# Create .gitignore for security
cat > "$OUTPUT_DIR/.gitignore" << 'EOF'
# Environment files (contain secrets)
.env
compose/.env

# Runtime data
data/persistent/*
!data/persistent/.gitkeep

# OS files
.DS_Store
Thumbs.db

# Editor files
*.swp
*.swo
*~

# Backup files from upgrades
backups/
EOF

log_success "Scaffold created successfully at $OUTPUT_DIR"
log_info "Directory structure:"
log_info "  $OUTPUT_DIR/"
log_info "  ├── manifest.yaml (to be generated)"
log_info "  ├── docs/"
log_info "  ├── containers/$VERSION/"
log_info "  ├── compose/"
log_info "  ├── scripts/"
log_info "  ├── data/"
log_info "  │   ├── persistent/"
log_info "  │   ├── sample_data/"
log_info "  │   └── schemas/"
log_info "  └── checksums/"

exit 0
