#!/bin/sh
# validate_environment.sh - Verify Docker, disk space, CPU architecture
# Vendor Package: {{VENDOR_NAME}}/{{PRODUCT_NAME}} {{VERSION}}
#
# This script validates that the target system meets requirements
# for deploying this vendor package.
#
# Exit codes:
#   0 - All requirements met
#   1 - Docker not installed or not running
#   2 - Docker version too old
#   3 - Insufficient disk space
#   4 - Unsupported CPU architecture
#   5 - Insufficient memory

set -e

# Configuration
REQUIRED_DOCKER_VERSION="20.10.0"
REQUIRED_DISK_SPACE_GB=10
REQUIRED_MEMORY_GB=4
SUPPORTED_ARCHITECTURES="amd64 arm64 x86_64 aarch64"

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

# Version comparison: returns 0 if $1 >= $2
version_gte() {
    # Compare versions using sort -V if available, else basic comparison
    if command -v sort >/dev/null 2>&1; then
        [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" = "$2" ]
    else
        # Basic comparison fallback
        [ "$1" = "$2" ] && return 0
        return 1
    fi
}

log_info "Validating environment for {{VENDOR_NAME}}/{{PRODUCT_NAME}} {{VERSION}}"
log_info "=================================================="

# Check Docker is installed
log_info "Checking Docker installation..."
if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is not installed"
    log_error "Please install Docker: https://docs.docker.com/engine/install/"
    exit 1
fi
log_success "Docker is installed"

# Check Docker daemon is running
log_info "Checking Docker daemon..."
if ! docker info >/dev/null 2>&1; then
    log_error "Docker daemon is not running"
    log_error "Please start Docker and try again"
    exit 1
fi
log_success "Docker daemon is running"

# Check Docker version
log_info "Checking Docker version..."
DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "0.0.0")
log_info "Detected Docker version: $DOCKER_VERSION"
if ! version_gte "$DOCKER_VERSION" "$REQUIRED_DOCKER_VERSION"; then
    log_error "Docker version $DOCKER_VERSION is below required version $REQUIRED_DOCKER_VERSION"
    exit 2
fi
log_success "Docker version $DOCKER_VERSION meets requirement (>= $REQUIRED_DOCKER_VERSION)"

# Check Docker Compose
log_info "Checking Docker Compose..."
if docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "unknown")
    log_success "Docker Compose v2 is available (version: $COMPOSE_VERSION)"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker-compose version --short 2>/dev/null || echo "unknown")
    log_warn "Using legacy docker-compose (version: $COMPOSE_VERSION)"
    log_warn "Consider upgrading to Docker Compose v2"
else
    log_error "Docker Compose is not available"
    log_error "Please install Docker Compose"
    exit 1
fi

# Check CPU architecture
log_info "Checking CPU architecture..."
ARCH=$(uname -m)
log_info "Detected architecture: $ARCH"
ARCH_SUPPORTED=0
for supported in $SUPPORTED_ARCHITECTURES; do
    if [ "$ARCH" = "$supported" ]; then
        ARCH_SUPPORTED=1
        break
    fi
done
if [ "$ARCH_SUPPORTED" -eq 0 ]; then
    log_error "Unsupported CPU architecture: $ARCH"
    log_error "Supported architectures: $SUPPORTED_ARCHITECTURES"
    exit 4
fi
log_success "CPU architecture $ARCH is supported"

# Check disk space
log_info "Checking disk space..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"

# Get available disk space in GB
if command -v df >/dev/null 2>&1; then
    # Try to get available space in 1K blocks and convert to GB
    AVAILABLE_KB=$(df -P "$PACKAGE_DIR" 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "$AVAILABLE_KB" ] && [ "$AVAILABLE_KB" -gt 0 ] 2>/dev/null; then
        AVAILABLE_GB=$((AVAILABLE_KB / 1024 / 1024))
        log_info "Available disk space: ${AVAILABLE_GB}GB"
        if [ "$AVAILABLE_GB" -lt "$REQUIRED_DISK_SPACE_GB" ]; then
            log_error "Insufficient disk space: ${AVAILABLE_GB}GB available, ${REQUIRED_DISK_SPACE_GB}GB required"
            exit 3
        fi
        log_success "Disk space ${AVAILABLE_GB}GB meets requirement (>= ${REQUIRED_DISK_SPACE_GB}GB)"
    else
        log_warn "Could not determine available disk space"
    fi
else
    log_warn "df command not available, skipping disk space check"
fi

# Check available memory
log_info "Checking available memory..."
if [ -f /proc/meminfo ]; then
    # Linux
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
elif command -v sysctl >/dev/null 2>&1; then
    # macOS/BSD
    TOTAL_MEM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
    TOTAL_MEM_GB=$((TOTAL_MEM_BYTES / 1024 / 1024 / 1024))
else
    TOTAL_MEM_GB=0
fi

if [ "$TOTAL_MEM_GB" -gt 0 ]; then
    log_info "Total system memory: ${TOTAL_MEM_GB}GB"
    if [ "$TOTAL_MEM_GB" -lt "$REQUIRED_MEMORY_GB" ]; then
        log_warn "System memory ${TOTAL_MEM_GB}GB is below recommended ${REQUIRED_MEMORY_GB}GB"
        # Don't exit, just warn
    else
        log_success "System memory ${TOTAL_MEM_GB}GB meets requirement (>= ${REQUIRED_MEMORY_GB}GB)"
    fi
else
    log_warn "Could not determine system memory"
fi

log_info "=================================================="
log_success "Environment validation completed successfully"
exit 0
