#!/bin/sh
# generate_checksums.sh - Creates sha256.txt for a vendor package
# Part of OCI Vendor Package Scaffolder (OVPS)
#
# Usage: generate_checksums.sh <package-dir>
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Package directory does not exist
#   3 - No checksum tool available
#   4 - Failed to generate checksums

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
if [ $# -lt 1 ]; then
    log_error "Usage: generate_checksums.sh <package-dir>"
    exit 1
fi

PACKAGE_DIR="$1"

# Validate package directory exists
if [ ! -d "$PACKAGE_DIR" ]; then
    log_error "Package directory does not exist: $PACKAGE_DIR"
    exit 2
fi

# Convert to absolute path
PACKAGE_DIR="$(cd "$PACKAGE_DIR" && pwd)"

# Determine checksum command
if command -v sha256sum >/dev/null 2>&1; then
    CHECKSUM_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    CHECKSUM_CMD="shasum -a 256"
else
    log_error "No SHA256 checksum tool available (need sha256sum or shasum)"
    exit 3
fi

log_info "Generating checksums for package: $PACKAGE_DIR"
log_info "Using checksum command: $CHECKSUM_CMD"

# Ensure checksums directory exists
CHECKSUMS_DIR="$PACKAGE_DIR/checksums"
mkdir -p "$CHECKSUMS_DIR"

OUTPUT_FILE="$CHECKSUMS_DIR/sha256.txt"

# Create temporary file for checksums
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

# Store original directory
ORIG_DIR="$(pwd)"

# Change to package directory for relative paths
cd "$PACKAGE_DIR"

# Generate checksums for all relevant files
log_info "Computing checksums..."

# Find files and compute checksums (POSIX-compatible approach)
find . -type f \
    ! -path "./checksums/*" \
    ! -path "./.git/*" \
    ! -name ".gitkeep" \
    ! -name ".DS_Store" 2>/dev/null > "$TEMP_FILE.list" || true

# Process each file
while IFS= read -r file; do
    # Remove leading ./
    rel_path="${file#./}"
    # Compute checksum and append to temp file
    $CHECKSUM_CMD "$file" 2>/dev/null | sed "s|$file|$rel_path|" >> "$TEMP_FILE" || true
done < "$TEMP_FILE.list"

rm -f "$TEMP_FILE.list"

# Count files
if [ -f "$TEMP_FILE" ]; then
    FILE_COUNT=$(wc -l < "$TEMP_FILE" | tr -d ' ')
else
    FILE_COUNT=0
fi

# Generate output file with header
if [ "$FILE_COUNT" -eq 0 ]; then
    log_info "No files to checksum"
    cat > "$OUTPUT_FILE" << EOF
# SHA256 Checksums
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Package: $PACKAGE_DIR
# Files: 0
#
# Verify with: sha256sum -c checksums/sha256.txt
# Or on macOS: shasum -a 256 -c checksums/sha256.txt
EOF
else
    # Sort checksums by filename and create final file
    cat > "$OUTPUT_FILE" << EOF
# SHA256 Checksums
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Package: $PACKAGE_DIR
# Files: $FILE_COUNT
#
# Verify with: sha256sum -c checksums/sha256.txt
# Or on macOS: shasum -a 256 -c checksums/sha256.txt

EOF
    sort -k2 "$TEMP_FILE" >> "$OUTPUT_FILE"
fi

cd "$ORIG_DIR"

log_info "Files checksummed: $FILE_COUNT"
log_success "Generated: $OUTPUT_FILE"

exit 0
