# OVPS Issues & Technical Debt

This document tracks issues discovered during technical review of the OCI Vendor Package Scaffolder.

> **Status Update (2026-02-01):** All 13 issues have been implemented and verified with automated tests (136 total tests across unit and integration suites).

---

## Critical Issues (✅ All Resolved)

### 1. ✅ No Command to Update/Add Container Versions

**Location:** `ovps` CLI
**Severity:** Critical
**Status:** **RESOLVED** - Implemented `ovps add-version` command

**Implementation:**
- Added `ovps add-version <package-dir> <new-version>` command
- Creates new container version directory
- Updates manifest.yaml version field
- Regenerates scripts with new version references
- Created `generators/generate_version.sh` for version creation logic

---

### 2. ✅ Upgrade Script Version Detection is Broken

**Location:** `templates/scripts/upgrade.sh.tpl`
**Severity:** Critical
**Status:** **RESOLVED** - Version tracking via `.deployed-version` file

**Implementation:**
- `install.sh` writes version to `data/.deployed-version` after successful install
- `upgrade.sh` reads FROM_VERSION from `data/.deployed-version`
- `upgrade.sh` updates `.deployed-version` after successful upgrade
- Graceful fallback to manifest version if file doesn't exist

---

### 3. ✅ Multi-Version Container Loading Missing

**Location:** `templates/scripts/upgrade.sh.tpl`, `templates/scripts/validate_containers.sh.tpl`
**Severity:** Critical
**Status:** **RESOLVED** - Added `--version` parameter support

**Implementation:**
- `validate_containers.sh` accepts `--version <version>` parameter
- `upgrade.sh` accepts `--to-version <version>` parameter
- Containers loaded from `containers/<version>/` directory
- Default to package version if not specified

---

### 4. ✅ OCI Format Loading Not Implemented

**Location:** `templates/scripts/validate_containers.sh.tpl`
**Severity:** High
**Status:** **RESOLVED** - OCI format now supported

**Implementation:**
- OCI tar archives load via `docker load`
- OCI directory format uses `skopeo copy` if available
- Graceful fallback with clear error messages

---

## Design Constraint Violations (✅ All Resolved)

### 5. ✅ install.sh Attempts Network Pull (Violates Offline Constraint)

**Location:** `templates/scripts/install.sh.tpl`
**Severity:** High
**Status:** **RESOLVED** - Network pull removed

**Implementation:**
- Removed `docker-compose pull` command entirely
- Added "Using pre-loaded local images (offline mode)" log message
- Full offline compliance achieved

---

### 6. ✅ docker-compose.yaml Template Uses Remote Image

**Location:** `templates/docker-compose.yaml.tpl`
**Severity:** Medium
**Status:** **RESOLVED** - Placeholder removed

**Implementation:**
- Replaced placeholder service with empty `services: {}` mapping
- Added TODO comments guiding users to define their own services
- No network-dependent images in generated templates

---

## Validation Gaps (✅ All Resolved)

### 7. ✅ containers.yaml is Never Validated or Used

**Location:** `templates/scripts/validate_containers.sh.tpl`
**Severity:** Medium
**Status:** **RESOLVED** - containers.yaml validation added

**Implementation:**
- `validate_containers.sh` now parses containers.yaml if present
- Verifies each listed file exists in container directory
- Cross-checks with discovered .tar.gz/.oci files
- Warns on mismatches between manifest and actual files

---

### 8. ✅ No Validation of Manifest Container/Service Consistency

**Location:** `validators/validate_manifest.sh`
**Severity:** Medium
**Status:** **RESOLVED** - Cross-file validation added

**Implementation:**
- Validates containers listed in manifest exist in containers/ directory
- Validates services listed match docker-compose.yaml services
- Warns (not errors) on mismatches for flexibility

---

## Missing Features (✅ All Resolved)

### 9. ✅ No Rollback Command

**Location:** `ovps` CLI
**Severity:** Medium
**Status:** **RESOLVED** - `ovps rollback` command added

**Implementation:**
- Added `ovps rollback <package-dir> [backup-dir]` command
- Lists available backups if backup-dir not specified
- Stops running services before restore
- Restores compose config and persistent data from backup
- Restarts services after restore
- Updates `.deployed-version` file

---

### 10. ✅ No Package Version Listing Command

**Location:** `ovps` CLI
**Severity:** Low
**Status:** **RESOLVED** - `ovps versions` command added

**Implementation:**
- Added `ovps versions <package-dir>` command
- Lists all version directories in containers/
- Shows current deployed version from `.deployed-version`
- Shows manifest version

---

### 11. ✅ No Dry-Run Mode for Upgrade

**Location:** `templates/scripts/upgrade.sh.tpl`
**Severity:** Low
**Status:** **RESOLVED** - `--dry-run` flag added

**Implementation:**
- Added `--dry-run` flag to upgrade.sh
- Shows planned actions prefixed with `[DRY-RUN]`
- No changes made when flag is set
- Verified with integration tests

---

## Code Quality Issues (✅ All Resolved)

### 12. ✅ Inconsistent Error Handling in cmd_package

**Location:** `ovps`
**Severity:** Low
**Status:** **RESOLVED** - Error handling fixed

**Implementation:**
- Replaced pipe-to-grep pattern with proper exit code checking
- Uses consistent `if ! validator; then ERRORS=$((ERRORS+1)); fi` pattern
- Properly captures and reports validation errors

---

### 13. ✅ Hardcoded Sleep Values in Scripts

**Location:** `templates/scripts/upgrade.sh.tpl`, `templates/scripts/install.sh.tpl`, `templates/scripts/healthcheck.sh.tpl`
**Severity:** Low
**Status:** **RESOLVED** - Configurable via environment variables

**Implementation:**
- `OVPS_INIT_WAIT` - seconds to wait after starting services (default: 5)
- `OVPS_HEALTH_WAIT` - seconds to wait for health checks (default: 10)
- `OVPS_HEALTH_CHECK_TIMEOUT` - health check timeout (default: 5)
- `OVPS_HEALTH_CHECK_RETRIES` - health check retry count (default: 3)

---

## Summary

| Severity | Count | Status |
|----------|-------|--------|
| Critical | 3 | ✅ All Resolved |
| High | 2 | ✅ All Resolved |
| Medium | 4 | ✅ All Resolved |
| Low | 4 | ✅ All Resolved |

**Total: 13/13 issues resolved**

### Verification

All fixes verified with automated tests:
- **Unit tests:** 61 tests (`tests/test_ovps.sh`)
- **Single container integration:** 31 tests (`tests/test_integration_single_container.sh`)
- **Multi-container integration:** 44 tests (`tests/test_integration_multi_container.sh`)

Run the full test suite:
```sh
./tests/run-all-tests.sh
```

---

## Future Enhancements

_Add new issues/enhancements below as they are identified._
