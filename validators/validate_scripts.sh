#!/bin/sh
# validate_scripts.sh - Validates required scripts in a vendor package
# Part of OCI Vendor Package Scaffolder (OVPS)
#
# Usage: validate_scripts.sh <package-dir>
#
# Exit codes:
#   0 - Validation passed
#   1 - Invalid arguments
#   2 - Scripts directory not found
#   3 - Required scripts missing
#   4 - Scripts not executable
#   5 - POSIX compliance issues

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
    log_error "Usage: validate_scripts.sh <package-dir>"
    exit 1
fi

PACKAGE_DIR="$1"
SCRIPTS_DIR="$PACKAGE_DIR/scripts"

# Check scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
    log_error "Scripts directory not found: $SCRIPTS_DIR"
    exit 2
fi

log_info "Validating scripts in: $SCRIPTS_DIR"

# Required scripts
REQUIRED_SCRIPTS="validate_environment.sh validate_containers.sh install.sh upgrade.sh healthcheck.sh"

ERRORS=0
WARNINGS=0

# Check each required script
log_info "Checking required scripts..."
for script in $REQUIRED_SCRIPTS; do
    SCRIPT_PATH="$SCRIPTS_DIR/$script"

    # Check existence
    if [ ! -f "$SCRIPT_PATH" ]; then
        log_error "Missing required script: $script"
        ERRORS=$((ERRORS + 1))
        continue
    fi
    log_success "Found: $script"

    # Check executable permission
    if [ ! -x "$SCRIPT_PATH" ]; then
        log_error "Script not executable: $script"
        ERRORS=$((ERRORS + 1))
    fi

    # Check shebang
    FIRST_LINE=$(head -n 1 "$SCRIPT_PATH")
    case "$FIRST_LINE" in
        "#!/bin/sh"*)
            log_success "POSIX shebang: $script"
            ;;
        "#!/bin/bash"*)
            log_warn "Bash shebang detected (should be #!/bin/sh for POSIX): $script"
            WARNINGS=$((WARNINGS + 1))
            ;;
        "#!"*)
            log_warn "Non-standard shebang: $script ($FIRST_LINE)"
            WARNINGS=$((WARNINGS + 1))
            ;;
        *)
            log_error "Missing shebang: $script"
            ERRORS=$((ERRORS + 1))
            ;;
    esac

    # Check for common Bash-isms (basic POSIX compliance check)
    log_info "Checking POSIX compliance: $script"

    # Check for [[ ]] (Bash-only) - exclude Docker template syntax {{
    if grep '\[\[' "$SCRIPT_PATH" 2>/dev/null | grep -v '{{' >/dev/null 2>&1; then
        log_warn "Bash-style [[ ]] found (use [ ] for POSIX): $script"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check for function keyword (Bash-style)
    if grep -qE '^function ' "$SCRIPT_PATH" 2>/dev/null; then
        log_warn "Bash-style 'function' keyword found: $script"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check for arrays (Bash-only)
    if grep -qE '=\(' "$SCRIPT_PATH" 2>/dev/null; then
        # Exclude case patterns and subshells
        if grep -E '=\(' "$SCRIPT_PATH" | grep -vE '^\s*#|case|\$\(' >/dev/null 2>&1; then
            log_warn "Possible Bash array syntax found: $script"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi

    # Check for process substitution (Bash-only)
    if grep -qE '<\(|>\(' "$SCRIPT_PATH" 2>/dev/null; then
        log_warn "Bash process substitution found: $script"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check for set -e (recommended)
    if ! grep -q 'set -e' "$SCRIPT_PATH" 2>/dev/null; then
        log_warn "Missing 'set -e' (recommended for fail-fast): $script"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check for exit codes in comments (documentation)
    if ! grep -q 'Exit code' "$SCRIPT_PATH" 2>/dev/null && ! grep -q 'exit' "$SCRIPT_PATH" 2>/dev/null; then
        log_warn "No exit code documentation found: $script"
        WARNINGS=$((WARNINGS + 1))
    fi
done

# Run shellcheck if available
if command -v shellcheck >/dev/null 2>&1; then
    log_info "Running shellcheck analysis..."
    for script in $REQUIRED_SCRIPTS; do
        SCRIPT_PATH="$SCRIPTS_DIR/$script"
        if [ -f "$SCRIPT_PATH" ]; then
            if shellcheck -s sh "$SCRIPT_PATH" 2>/dev/null; then
                log_success "shellcheck passed: $script"
            else
                log_warn "shellcheck found issues: $script"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    done
else
    log_info "shellcheck not available, skipping detailed analysis"
fi

# Summary
log_info "=================================================="
log_info "Scripts validated: $(echo $REQUIRED_SCRIPTS | wc -w | tr -d ' ')"
log_info "Errors: $ERRORS"
log_info "Warnings: $WARNINGS"

if [ $ERRORS -gt 0 ]; then
    log_error "Script validation failed with $ERRORS error(s)"
    exit 3
fi

if [ $WARNINGS -gt 0 ]; then
    log_warn "Script validation passed with $WARNINGS warning(s)"
else
    log_success "Script validation passed"
fi

exit 0
