#!/bin/sh
# validate_structure.sh - Validates directory structure of a vendor package
# Part of OCI Vendor Package Scaffolder (OVPS)
#
# Usage: validate_structure.sh <package-dir>
#
# Exit codes:
#   0 - Validation passed
#   1 - Invalid arguments
#   2 - Package directory not found
#   3 - Required directories missing
#   4 - Required files missing

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
    log_error "Usage: validate_structure.sh <package-dir>"
    exit 1
fi

PACKAGE_DIR="$1"

# Check package directory exists
if [ ! -d "$PACKAGE_DIR" ]; then
    log_error "Package directory not found: $PACKAGE_DIR"
    exit 2
fi

log_info "Validating structure: $PACKAGE_DIR"

ERRORS=0
WARNINGS=0

# Required directories
REQUIRED_DIRS="docs containers compose scripts data data/persistent checksums"

log_info "Checking required directories..."
for dir in $REQUIRED_DIRS; do
    DIR_PATH="$PACKAGE_DIR/$dir"
    if [ -d "$DIR_PATH" ]; then
        log_success "Found: $dir/"
    else
        log_error "Missing directory: $dir/"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check for at least one version directory in containers
log_info "Checking container version directories..."
if [ -d "$PACKAGE_DIR/containers" ]; then
    VERSION_DIRS=$(find "$PACKAGE_DIR/containers" -mindepth 1 -maxdepth 1 -type d -name "v*" 2>/dev/null || true)
    if [ -z "$VERSION_DIRS" ]; then
        log_warn "No version directories found in containers/ (expected v*.*.* format)"
        WARNINGS=$((WARNINGS + 1))
    else
        for vdir in $VERSION_DIRS; do
            log_success "Found version directory: containers/$(basename "$vdir")/"
        done
    fi
fi

# Required files
REQUIRED_FILES="manifest.yaml"

log_info "Checking required files..."
for file in $REQUIRED_FILES; do
    FILE_PATH="$PACKAGE_DIR/$file"
    if [ -f "$FILE_PATH" ]; then
        log_success "Found: $file"
    else
        log_error "Missing file: $file"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check compose file
log_info "Checking compose file..."
if [ -f "$PACKAGE_DIR/compose/docker-compose.yaml" ]; then
    log_success "Found: compose/docker-compose.yaml"
elif [ -f "$PACKAGE_DIR/compose/docker-compose.yml" ]; then
    log_success "Found: compose/docker-compose.yml"
else
    log_error "Missing: compose/docker-compose.yaml or compose/docker-compose.yml"
    ERRORS=$((ERRORS + 1))
fi

# Check scripts
REQUIRED_SCRIPTS="validate_environment.sh validate_containers.sh install.sh upgrade.sh healthcheck.sh"
log_info "Checking required scripts..."
for script in $REQUIRED_SCRIPTS; do
    SCRIPT_PATH="$PACKAGE_DIR/scripts/$script"
    if [ -f "$SCRIPT_PATH" ]; then
        if [ -x "$SCRIPT_PATH" ]; then
            log_success "Found: scripts/$script (executable)"
        else
            log_warn "Found: scripts/$script (NOT executable)"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        log_error "Missing: scripts/$script"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check checksums file
log_info "Checking checksums..."
if [ -f "$PACKAGE_DIR/checksums/sha256.txt" ]; then
    log_success "Found: checksums/sha256.txt"
else
    log_warn "Missing: checksums/sha256.txt (run 'ovps checksums' to generate)"
    WARNINGS=$((WARNINGS + 1))
fi

# Optional checks
log_info "Checking optional directories..."
OPTIONAL_DIRS="data/sample_data data/schemas"
for dir in $OPTIONAL_DIRS; do
    DIR_PATH="$PACKAGE_DIR/$dir"
    if [ -d "$DIR_PATH" ]; then
        log_info "Found optional: $dir/"
    fi
done

# Documentation check
log_info "Checking documentation..."
DOC_FILES="overview.txt install.txt upgrade.txt"
DOCS_FOUND=0
for doc in $DOC_FILES; do
    if [ -f "$PACKAGE_DIR/docs/$doc" ]; then
        log_success "Found: docs/$doc"
        DOCS_FOUND=$((DOCS_FOUND + 1))
    fi
done
if [ $DOCS_FOUND -eq 0 ]; then
    log_warn "No documentation files found in docs/ (recommended: overview.txt, install.txt, upgrade.txt)"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
log_info "=================================================="
log_info "Errors: $ERRORS"
log_info "Warnings: $WARNINGS"

if [ $ERRORS -gt 0 ]; then
    log_error "Structure validation failed with $ERRORS error(s)"
    exit 3
fi

if [ $WARNINGS -gt 0 ]; then
    log_warn "Structure validation passed with $WARNINGS warning(s)"
else
    log_success "Structure validation passed"
fi

exit 0
