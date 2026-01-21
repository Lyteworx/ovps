# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**OCI Vendor Package Scaffolder (OVPS)** - A framework that scaffolds, validates, and maintains vendor delivery packages for Docker/OCI-based deployments. The project generates standardized vendor packages, it is NOT a vendor package itself.

## Authoritative Specification

All implementation decisions MUST come from `project-plan.md`. This document is the single source of truth. Do not invent structure beyond what is specified there.

## Design Constraints (Non-Negotiable)

- Docker/OCI container runtime only (no Kubernetes)
- Offline operation required (no internet access assumed)
- POSIX-compliant shell scripts only
- Docker Compose is the orchestration baseline
- All vendors must use identical structure
- Immutable versioning (no in-place modification of delivered artifacts)

## Target Repository Structure

```
oci-vendor-scaffolder/
├── scaffolds/base/     # Base scaffold templates
├── templates/          # File templates
├── generators/         # Package generation logic
├── validators/         # Validation scripts
├── prompts/            # AI agent prompts
└── examples/           # Example vendor packages
```

## Generated Vendor Package Structure

Every generated package must match this exact structure:

```
vendor-package/
├── manifest.yaml           # Single source of truth for package
├── docs/                   # Plain text only (overview.txt, install.txt, upgrade.txt)
├── containers/vX.Y.Z/      # Versioned container images (.tar.gz or .oci)
├── compose/                # docker-compose.yaml (must run standalone, local images only)
├── scripts/                # POSIX shell scripts (see below)
├── data/                   # persistent/, sample_data/, schemas/
└── checksums/sha256.txt    # Integrity verification
```

## Required Scripts Contract

All scripts must be POSIX shell, idempotent, with explicit exit codes and verbose logging:

- `validate_environment.sh` - Verify Docker, disk space, CPU architecture
- `validate_containers.sh` - Load and verify container images
- `install.sh` - Full deployment via Docker Compose
- `upgrade.sh` - Version transitions preserving persistent data
- `healthcheck.sh` - Verify containers running and services responding

## Implementation Phases

1. Base Scaffold Generation - Directory hierarchy and placeholders
2. Manifest Automation - Schema definition and validation
3. Universal Script Contract - All required scripts
4. Container Handling - .tar.gz and .oci formats, offline loading
5. Data and Persistence - Volume mapping, sample data, schema hooks
6. Compose Orchestration - Generate compose templates
7. Integrity Verification - SHA256 checksums

## Code Style

- Prefer clarity over cleverness
- Add comments explaining intent
- Fail fast on validation errors
- Follow directory and file names exactly as specified
