# OVPS - OCI Vendor Package Scaffolder

A framework for creating standardized vendor delivery packages for Docker/OCI-based deployments. OVPS generates consistent, validated, offline-capable deployment packages that work across any vendor.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              OVPS Workflow                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   PACKAGE CREATOR                           VENDOR/DEPLOYER                 │
│   ───────────────                           ────────────────                │
│                                                                             │
│   ┌─────────────┐                           ┌─────────────┐                 │
│   │ ovps new    │ ──── creates ────────────>│ Package     │                 │
│   └─────────────┘                           │ .tar.gz     │                 │
│         │                                   └──────┬──────┘                 │
│         ▼                                          │                        │
│   ┌─────────────┐                                  │                        │
│   │ Add images  │                                  │                        │
│   │ Configure   │                                  ▼                        │
│   │ Document    │                           ┌─────────────┐                 │
│   └─────────────┘                           │ Extract     │                 │
│         │                                   └──────┬──────┘                 │
│         ▼                                          │                        │
│   ┌─────────────┐                                  ▼                        │
│   │ ovps        │                           ┌─────────────┐                 │
│   │ validate    │                           │ Configure   │                 │
│   └─────────────┘                           │ .env        │                 │
│         │                                   └──────┬──────┘                 │
│         ▼                                          │                        │
│   ┌─────────────┐                                  ▼                        │
│   │ ovps        │                           ┌─────────────┐                 │
│   │ checksums   │                           │ install.sh  │                 │
│   └─────────────┘                           └──────┬──────┘                 │
│         │                                          │                        │
│         ▼                                          ▼                        │
│   ┌─────────────┐                           ┌─────────────┐                 │
│   │ Distribute  │                           │ Running     │                 │
│   │ Package     │                           │ Application │                 │
│   └─────────────┘                           └─────────────┘                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Table of Contents

- [Why OVPS?](#why-ovps)
- [Use Cases](#use-cases)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [CLI Reference](#cli-reference)
- [Generated Package Structure](#generated-package-structure)
- [Complete Walkthrough](#complete-walkthrough)
- [For Package Creators](#for-package-creators)
- [For Vendors](#for-vendors)
- [Secrets and Environment Configuration](#secrets-and-environment-configuration)
- [Validation](#validation)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

---

## Why OVPS?

### The Problem

When delivering containerized applications to customers, vendors face challenges:

- **Inconsistent packaging**: Every vendor delivers packages differently
- **Missing documentation**: Unclear installation and upgrade procedures
- **No offline support**: Packages assume internet connectivity
- **No validation**: Broken packages discovered only during deployment
- **Secret management**: No standard approach for handling credentials

### The Solution

OVPS provides a **standardized framework** that ensures:

| Feature | Benefit |
|---------|---------|
| **Consistent Structure** | Every package looks identical, reducing learning curve |
| **Offline Operation** | Works in air-gapped environments without internet |
| **Built-in Validation** | Catch errors before deployment |
| **POSIX Compliance** | Scripts work on any Unix-like system |
| **Integrity Verification** | SHA256 checksums for all files |
| **Secret Management** | Template-based environment configuration |

### Design Principles

- Docker/OCI container runtime only (no Kubernetes dependency)
- Offline operation required (no internet access assumed)
- POSIX-compliant shell scripts only (no bash-specific features)
- Docker Compose as the orchestration baseline
- Immutable versioning (no in-place modification of delivered artifacts)

---

## Use Cases

### 1. Software Vendors Delivering to Enterprises

```
Scenario: Your company sells a web application to enterprise customers
who deploy in their own data centers.

Solution: Use OVPS to create standardized packages that work in
air-gapped environments with consistent deployment procedures.
```

### 2. Internal Platform Teams

```
Scenario: Your platform team needs to distribute internal tools
to development teams across the organization.

Solution: Create OVPS packages for each tool, ensuring consistent
installation and upgrade experiences.
```

### 3. Managed Service Providers

```
Scenario: You deploy the same application for multiple clients
with different configurations.

Solution: Use OVPS packages with environment-specific .env files
for each client deployment.
```

### 4. Compliance-Heavy Industries

```
Scenario: Healthcare/Finance/Government deployments require
offline installation and audit trails.

Solution: OVPS packages include checksums for integrity verification
and work completely offline.
```

---

## Installation

### Requirements

| Requirement | Minimum Version | Check Command |
|-------------|-----------------|---------------|
| POSIX Shell | `/bin/sh` | `echo $SHELL` |
| Docker | 20.10.0 | `docker --version` |
| Docker Compose | v2.0.0 | `docker compose version` |

### Install OVPS

```bash
# Clone the repository
git clone https://github.com/your-org/ovps.git
cd ovps

# Verify installation
./ovps --version
# Output: ovps version 1.0.0

# View help
./ovps help
```

No build steps or dependencies required - OVPS is pure shell scripts.

### Add to PATH (Recommended)

```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
export PATH="$PATH:/path/to/ovps"

# Reload your shell
source ~/.bashrc  # or ~/.zshrc

# Now run from anywhere
ovps help
```

### Verify Installation

```bash
# Create a test package
ovps new test-vendor test-app v1.0.0

# Validate it
ovps validate test-vendor-test-app-v1.0.0

# Clean up
rm -rf test-vendor-test-app-v1.0.0
```

---

## Quick Start

### 5-Minute Quick Start

```bash
# 1. Create a new package
./ovps new acme webapp v1.0.0

# 2. Enter the package directory
cd acme-webapp-v1.0.0

# 3. Add a container image (example with nginx)
docker pull nginx:alpine
docker save nginx:alpine | gzip > containers/v1.0.0/nginx.tar.gz

# 4. Update docker-compose.yaml
cat > compose/docker-compose.yaml << 'EOF'
version: "3.8"
services:
  web:
    image: nginx:alpine
    container_name: acme-webapp
    restart: unless-stopped
    ports:
      - "${APP_PORT:-8080}:80"
    volumes:
      - ../data/persistent/html:/usr/share/nginx/html:ro
EOF

# 5. Add sample content
echo "<h1>Hello from OVPS!</h1>" > data/sample_data/index.html
mkdir -p data/persistent/html

# 6. Configure environment
cp compose/.env.example compose/.env
sed -i 's/CHANGE_ME_BEFORE_DEPLOYMENT/mysecretpassword/' compose/.env

# 7. Regenerate checksums
cd .. && ./ovps checksums acme-webapp-v1.0.0

# 8. Validate
./ovps validate acme-webapp-v1.0.0

# 9. Test deployment
cd acme-webapp-v1.0.0
./scripts/install.sh

# 10. Verify it's running
curl http://localhost:8080
```

---

## CLI Reference

### Commands Overview

```
OVPS - OCI Vendor Package Scaffolder v1.0.0

Usage:
  ovps new <vendor> <product> <version> [output-dir]
  ovps validate <package-dir>
  ovps checksums <package-dir>
  ovps help
  ovps --version
```

### Command Details

#### `ovps new` - Create a New Package

Creates a complete vendor package scaffold with all required directories, scripts, and templates.

```bash
# Syntax
ovps new <vendor-name> <product-name> <version> [output-directory]

# Examples
ovps new acme webapp v1.0.0
# Creates: ./acme-webapp-v1.0.0/

ovps new acme webapp v1.0.0 /opt/packages/acme
# Creates: /opt/packages/acme/

ovps new "my-company" "my-app" v2.1.0
# Creates: ./my-company-my-app-v2.1.0/
```

**Version format**: Must be `vX.Y.Z` (e.g., `v1.0.0`, `v2.3.1`)

**What gets created**:
- Directory structure with all required folders
- `manifest.yaml` with package metadata
- `docker-compose.yaml` template
- `.env.example` for environment configuration
- All 5 required scripts (validate_environment, validate_containers, install, upgrade, healthcheck)
- `.gitignore` for security
- Initial checksums

#### `ovps validate` - Validate a Package

Runs comprehensive validation on an existing package.

```bash
# Syntax
ovps validate <package-directory>

# Examples
ovps validate ./acme-webapp-v1.0.0
ovps validate /opt/packages/acme
```

**What gets validated**:
- Directory structure completeness
- Manifest.yaml syntax and required fields
- Script presence, permissions, and POSIX compliance
- Docker Compose configuration
- Environment file setup
- Checksum file presence

#### `ovps checksums` - Generate Checksums

Generates or regenerates SHA256 checksums for all package files.

```bash
# Syntax
ovps checksums <package-directory>

# Examples
ovps checksums ./acme-webapp-v1.0.0

# Always run after making changes
ovps checksums ./acme-webapp-v1.0.0
ovps validate ./acme-webapp-v1.0.0
```

**Output**: Creates/updates `checksums/sha256.txt` with hashes of all files.

---

## Generated Package Structure

Every package follows this exact structure:

```
vendor-package/
├── manifest.yaml              # Package metadata (single source of truth)
├── .gitignore                 # Excludes .env and sensitive files
│
├── docs/                      # Plain text documentation
│   ├── overview.txt           # Product overview and features
│   ├── install.txt            # Installation instructions
│   └── upgrade.txt            # Upgrade procedures
│
├── containers/                # Container images
│   └── vX.Y.Z/                # Version-specific directory
│       ├── app.tar.gz         # Application image (docker save | gzip)
│       └── db.tar.gz          # Database image
│
├── compose/                   # Docker Compose configuration
│   ├── docker-compose.yaml    # Service definitions
│   ├── .env.example           # Environment template
│   └── .env                   # Actual config (created by deployer)
│
├── scripts/                   # POSIX shell scripts
│   ├── validate_environment.sh
│   ├── validate_containers.sh
│   ├── install.sh
│   ├── upgrade.sh
│   └── healthcheck.sh
│
├── data/                      # Data directories
│   ├── persistent/            # Runtime data (mounted as volumes)
│   ├── sample_data/           # Seed data for initial deployment
│   └── schemas/               # Database/config schemas
│
└── checksums/
    └── sha256.txt             # Integrity verification
```

### Required Scripts

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `validate_environment.sh` | Check Docker, disk, CPU, memory | Before install |
| `validate_containers.sh` | Verify container images | Before install |
| `install.sh` | Full deployment | Initial setup |
| `upgrade.sh` | Version upgrade with backup | When updating |
| `healthcheck.sh` | Verify services running | After install/upgrade |

### Exit Codes

All scripts use consistent exit codes:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid arguments / Docker not found |
| 2 | Validation failed / Version issue |
| 3 | Backup/checksum failed |
| 4 | Service start failed |
| 5 | Health check failed |

---

## Complete Walkthrough

This section walks through creating a complete, production-ready package.

### Scenario

You're packaging a web application with:
- Node.js API server
- PostgreSQL database
- Redis cache

### Step 1: Generate the Scaffold

```bash
./ovps new acme analytics-platform v1.0.0
cd acme-analytics-platform-v1.0.0
```

### Step 2: Export Container Images

```bash
# Pull images (or use your own)
docker pull node:18-alpine
docker pull postgres:15-alpine
docker pull redis:7-alpine

# Export to package
docker save node:18-alpine | gzip > containers/v1.0.0/api.tar.gz
docker save postgres:15-alpine | gzip > containers/v1.0.0/postgres.tar.gz
docker save redis:7-alpine | gzip > containers/v1.0.0/redis.tar.gz

# Verify exports
ls -lh containers/v1.0.0/
```

### Step 3: Configure Docker Compose

Edit `compose/docker-compose.yaml`:

```yaml
version: "3.8"

services:
  api:
    image: node:18-alpine
    container_name: analytics-api
    restart: unless-stopped
    ports:
      - "${API_PORT:-3000}:3000"
    environment:
      - NODE_ENV=${APP_ENV:-production}
      - DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}
      - REDIS_URL=redis://redis:6379
      - SECRET_KEY=${APP_SECRET_KEY}
    volumes:
      - ../data/persistent/uploads:/app/uploads
    depends_on:
      - db
      - redis
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  db:
    image: postgres:15-alpine
    container_name: analytics-db
    restart: unless-stopped
    environment:
      - POSTGRES_DB=${DB_NAME:-analytics}
      - POSTGRES_USER=${DB_USER:-analytics}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - ../data/persistent/postgres:/var/lib/postgresql/data
      - ../data/schemas/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-analytics}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: analytics-redis
    restart: unless-stopped
    volumes:
      - ../data/persistent/redis:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### Step 4: Configure Environment Template

Edit `compose/.env.example`:

```bash
# Analytics Platform Configuration
# Copy to .env and update values before deployment

# =============================================================================
# APPLICATION
# =============================================================================
APP_ENV=production
API_PORT=3000
APP_SECRET_KEY=GENERATE_ME_WITH_openssl_rand_hex_32

# =============================================================================
# DATABASE
# =============================================================================
DB_NAME=analytics
DB_USER=analytics
DB_PASSWORD=CHANGE_ME_BEFORE_DEPLOYMENT

# =============================================================================
# LOGGING
# =============================================================================
LOG_LEVEL=info
```

### Step 5: Update Manifest

Edit `manifest.yaml`:

```yaml
package:
  vendor: "acme"
  product: "analytics-platform"
  version: "v1.0.0"
  description: "Acme Analytics Platform - Real-time data analytics solution"

requirements:
  docker_version: "20.10.0"
  disk_space_gb: 50
  memory_gb: 8
  architectures:
    - amd64
    - arm64

containers:
  - name: "node"
    file: "containers/v1.0.0/api.tar.gz"
    tag: "18-alpine"
    description: "API server"
  - name: "postgres"
    file: "containers/v1.0.0/postgres.tar.gz"
    tag: "15-alpine"
    description: "PostgreSQL database"
  - name: "redis"
    file: "containers/v1.0.0/redis.tar.gz"
    tag: "7-alpine"
    description: "Redis cache"

services:
  - name: "api"
    container: "node:18-alpine"
    ports:
      - "3000:3000"
  - name: "db"
    container: "postgres:15-alpine"
  - name: "redis"
    container: "redis:7-alpine"

healthchecks:
  - service: "api"
    type: "http"
    endpoint: "http://localhost:3000/health"
    timeout_seconds: 30

metadata:
  created: "2024-01-15T10:00:00Z"
  generator: "ovps"
  generator_version: "1.0.0"
```

### Step 6: Add Documentation

Create `docs/overview.txt`:

```
Acme Analytics Platform v1.0.0
==============================

Overview
--------
Real-time data analytics solution for enterprise deployments.

Features
--------
- Real-time data processing
- Interactive dashboards
- REST API for integrations
- PostgreSQL data storage
- Redis caching layer

Requirements
------------
- Docker 20.10.0+
- 8GB RAM minimum
- 50GB disk space
- amd64 or arm64 architecture

Components
----------
- API Server (Node.js)
- PostgreSQL Database
- Redis Cache

Default Ports
-------------
- API: 3000

Support
-------
Email: support@acme.com
Docs: https://docs.acme.com/analytics
```

Create `docs/install.txt`:

```
Installation Guide
==================

Prerequisites
-------------
1. Docker 20.10.0 or later
2. Docker Compose v2
3. 8GB RAM, 50GB disk space

Installation Steps
------------------

1. Extract the package:
   tar -xzvf acme-analytics-platform-v1.0.0.tar.gz
   cd acme-analytics-platform-v1.0.0

2. Verify integrity:
   cd checksums && shasum -a 256 -c sha256.txt && cd ..

3. Validate environment:
   ./scripts/validate_environment.sh

4. Configure environment:
   cp compose/.env.example compose/.env
   # Edit compose/.env with your values:
   # - Set DB_PASSWORD to a secure value
   # - Generate APP_SECRET_KEY: openssl rand -hex 32

5. Run installation:
   ./scripts/install.sh

6. Verify deployment:
   ./scripts/healthcheck.sh

7. Access the application:
   http://localhost:3000

Post-Installation
-----------------
- Default API port: 3000
- Logs: cd compose && docker compose logs -f
- Stop: cd compose && docker compose down
```

### Step 7: Add Database Schema

Create `data/schemas/init.sql`:

```sql
-- Initial database schema
CREATE TABLE IF NOT EXISTS events (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_created ON events(created_at);
```

### Step 8: Finalize Package

```bash
# Return to ovps directory
cd ..

# Regenerate checksums
./ovps checksums acme-analytics-platform-v1.0.0

# Validate everything
./ovps validate acme-analytics-platform-v1.0.0

# Create distribution archive
tar -czvf acme-analytics-platform-v1.0.0.tar.gz acme-analytics-platform-v1.0.0/
```

---

## For Package Creators

### Checklist Before Distribution

- [ ] All container images exported to `containers/vX.Y.Z/`
- [ ] `docker-compose.yaml` uses only local images
- [ ] `manifest.yaml` documents all containers and services
- [ ] `.env.example` has all required variables with placeholders
- [ ] Documentation complete (`overview.txt`, `install.txt`, `upgrade.txt`)
- [ ] Sample data added if applicable
- [ ] Database schemas included if applicable
- [ ] `ovps checksums` run after all changes
- [ ] `ovps validate` passes with no errors
- [ ] Test deployment on clean system

### Image Export Best Practices

```bash
# Export with specific tag (recommended)
docker save myapp:v1.0.0 | gzip > containers/v1.0.0/myapp.tar.gz

# Export multiple images to single file (if related)
docker save myapp:v1.0.0 myapp-worker:v1.0.0 | gzip > containers/v1.0.0/myapp-bundle.tar.gz

# Check image size before export
docker images myapp:v1.0.0 --format "{{.Size}}"

# Verify export integrity
gunzip -t containers/v1.0.0/myapp.tar.gz
```

### Version Management

```bash
# Create new version
./ovps new acme myapp v2.0.0

# Copy relevant files from previous version
cp -r acme-myapp-v1.0.0/docs/* acme-myapp-v2.0.0/docs/
cp acme-myapp-v1.0.0/data/schemas/* acme-myapp-v2.0.0/data/schemas/

# Update compose and manifest for new version
# Export new container images
# Regenerate checksums
```

---

## For Vendors

### Deployment Checklist

- [ ] Extract package and verify checksums
- [ ] Run `validate_environment.sh` - fix any issues
- [ ] Copy `.env.example` to `.env`
- [ ] Edit `.env` with production values
- [ ] Generate secure secrets (`openssl rand -hex 32`)
- [ ] Run `install.sh`
- [ ] Verify with `healthcheck.sh`
- [ ] Test application functionality
- [ ] Document any custom configurations

### Quick Deployment Commands

```bash
# Extract
tar -xzvf vendor-package-v1.0.0.tar.gz
cd vendor-package-v1.0.0

# Verify integrity
shasum -a 256 -c checksums/sha256.txt

# Validate environment
./scripts/validate_environment.sh

# Configure (REQUIRED)
cp compose/.env.example compose/.env
vi compose/.env  # Set real values!

# Install
./scripts/install.sh

# Verify
./scripts/healthcheck.sh
```

### Day-to-Day Operations

```bash
# View logs
cd compose && docker compose logs -f

# View specific service logs
cd compose && docker compose logs -f api

# Restart services
cd compose && docker compose restart

# Stop services
cd compose && docker compose down

# Start services
cd compose && docker compose up -d

# Check status
cd compose && docker compose ps

# Execute command in container
cd compose && docker compose exec api sh
```

### Upgrading

```bash
# Extract new version
tar -xzvf vendor-package-v2.0.0.tar.gz
cd vendor-package-v2.0.0

# Copy your .env from previous version
cp ../vendor-package-v1.0.0/compose/.env compose/.env

# Review .env.example for new variables
diff compose/.env compose/.env.example

# Run upgrade
./scripts/upgrade.sh

# Verify
./scripts/healthcheck.sh
```

### Backup and Restore

```bash
# Manual backup
tar -czvf backup-$(date +%Y%m%d).tar.gz data/persistent/

# Restore from backup
cd compose && docker compose down
rm -rf data/persistent/*
tar -xzvf backup-20240115.tar.gz
cd compose && docker compose up -d
```

---

## Secrets and Environment Configuration

### How It Works

```
┌─────────────────┐    copy    ┌─────────────────┐
│ .env.example    │ ────────> │ .env            │
│ (template)      │           │ (actual config) │
│ IN VERSION CTRL │           │ NOT IN VCS      │
└─────────────────┘           └─────────────────┘
```

1. **`.env.example`** - Template with placeholder values (committed to git)
2. **`.env`** - Actual configuration (excluded from git via `.gitignore`)

### For Package Creators

Customize `compose/.env.example` for your application:

```bash
# Application Configuration
APP_ENV=production
APP_PORT=8080
APP_SECRET_KEY=GENERATE_ME_WITH_openssl_rand_hex_32

# Database
DB_HOST=db
DB_PORT=5432
DB_NAME=myapp
DB_USER=myapp
DB_PASSWORD=CHANGE_ME_BEFORE_DEPLOYMENT

# External Services (if applicable)
# SMTP_HOST=smtp.example.com
# SMTP_USER=
# SMTP_PASSWORD=CHANGE_ME
```

Reference in `docker-compose.yaml`:

```yaml
services:
  app:
    environment:
      - DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
      - SECRET_KEY=${APP_SECRET_KEY}
    ports:
      - "${APP_PORT:-8080}:8080"
```

### For Vendors

```bash
# 1. Copy template
cp compose/.env.example compose/.env

# 2. Generate secrets
openssl rand -hex 32  # Use output for APP_SECRET_KEY

# 3. Edit configuration
vi compose/.env

# 4. Verify no placeholders remain
grep -n "CHANGE_ME\|GENERATE_ME" compose/.env
# Should return nothing if properly configured
```

### Security Best Practices

| Do | Don't |
|----|-------|
| Generate unique secrets per environment | Reuse secrets across environments |
| Use `openssl rand -hex 32` for keys | Use simple passwords |
| Keep `.env` out of version control | Commit `.env` files |
| Rotate secrets periodically | Share secrets via email/chat |
| Use different credentials for dev/prod | Use production secrets in development |

### Placeholder Detection

The install script warns about unsafe placeholder values:

```
[WARN] ==================================================
[WARN] WARNING: .env contains default placeholder values!
[WARN] Please edit compose/.env and update:
[WARN]   15:DB_PASSWORD=CHANGE_ME_BEFORE_DEPLOYMENT
[WARN]   18:APP_SECRET_KEY=GENERATE_ME_WITH_openssl_rand_hex_32
[WARN] ==================================================
```

---

## Validation

### What Gets Validated

```bash
./ovps validate <package-dir>
```

| Check | What It Validates |
|-------|-------------------|
| **Structure** | Required directories and files exist |
| **Manifest** | YAML syntax, required fields present |
| **Scripts** | Exist, executable, POSIX-compliant |
| **Compose** | Valid YAML, no remote images, services defined |
| **Environment** | `.env.example` exists, `.env` warnings |

### Validation Output

```
[INFO] Validating vendor package: ./my-package
[INFO] ==================================================
[INFO] Validating directory structure...
[SUCCESS] Found: docs/
[SUCCESS] Found: containers/
[SUCCESS] Found: compose/
[SUCCESS] Found: scripts/
[SUCCESS] Found: manifest.yaml
...
[INFO] Validating scripts...
[SUCCESS] Found: validate_environment.sh (executable)
[SUCCESS] POSIX shebang: validate_environment.sh
...
[INFO] ==================================================
[SUCCESS] All validations passed
```

### Common Validation Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Missing directory | Required folder not created | Run `ovps new` or create manually |
| Script not executable | Permission issue | `chmod +x scripts/*.sh` |
| Bash shebang | Using `#!/bin/bash` | Change to `#!/bin/sh` |
| No services defined | Empty docker-compose.yaml | Add service definitions |

---

## Best Practices

### Package Creation

1. **Use semantic versioning**: `v1.0.0`, `v1.1.0`, `v2.0.0`
2. **Test on clean system**: Verify package works from scratch
3. **Document everything**: Assume deployer has never seen your product
4. **Include sample data**: Help users get started quickly
5. **Validate before distribution**: Always run `ovps validate`

### Container Images

1. **Pin versions**: Use `myapp:v1.0.0` not `myapp:latest`
2. **Use alpine bases**: Smaller images, faster transfers
3. **Multi-arch support**: Build for amd64 and arm64 when possible
4. **Test offline**: Verify images load without network

### Security

1. **No secrets in images**: Use environment variables
2. **Placeholder values**: Make it obvious what needs changing
3. **Minimal permissions**: Don't run containers as root if possible
4. **Network isolation**: Use Docker networks to limit exposure

### Documentation

1. **Plain text only**: No markdown in docs/ folder for offline compatibility
2. **Step-by-step**: Number each step in procedures
3. **Include troubleshooting**: Common issues and solutions
4. **Version history**: Document changes between versions

---

## Troubleshooting

### Common Issues

#### Docker Not Found

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

#### Docker Daemon Not Running

```bash
# Linux
sudo systemctl start docker

# macOS
open -a Docker

# Check status
docker info
```

#### Permission Denied

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Fix ownership if needed
sudo chown -R $USER:$USER .
```

#### Container Images Won't Load

```bash
# Check file integrity
gunzip -t containers/v1.0.0/image.tar.gz

# Manual load with verbose output
gunzip -c containers/v1.0.0/image.tar.gz | docker load

# Check available disk space
df -h
```

#### Services Won't Start

```bash
# Check logs
cd compose && docker compose logs

# Check container status
docker ps -a

# Verify images loaded
docker images

# Check port conflicts
lsof -i :8080
```

#### Health Checks Fail

```bash
# Wait longer for startup
sleep 60 && ./scripts/healthcheck.sh

# Check specific service
cd compose && docker compose logs api

# Verify network connectivity
docker network ls
cd compose && docker compose exec api ping db
```

### Debug Mode

Add verbose output to troubleshoot scripts:

```bash
# Run with debug output
sh -x ./scripts/install.sh

# Or add to script temporarily
set -x  # Enable debug
# ... commands ...
set +x  # Disable debug
```

---

## FAQ

### General

**Q: Can I use OVPS with Kubernetes?**
A: OVPS is designed for Docker Compose deployments. For Kubernetes, consider Helm charts or Kustomize.

**Q: Does OVPS work on Windows?**
A: OVPS requires a POSIX shell. Use WSL2 on Windows.

**Q: Can I customize the generated scripts?**
A: Yes, the generated scripts are starting points. Customize as needed for your application.

### Package Creation

**Q: How do I handle multiple architectures?**
A: Export images for each architecture:
```bash
docker save myapp:v1.0.0-amd64 | gzip > containers/v1.0.0/myapp-amd64.tar.gz
docker save myapp:v1.0.0-arm64 | gzip > containers/v1.0.0/myapp-arm64.tar.gz
```

**Q: Can I include configuration files?**
A: Yes, place them in `data/sample_data/` for initial deployment or mount via volumes.

**Q: How large can packages be?**
A: No technical limit, but consider distribution. Split very large packages if needed.

### Deployment

**Q: Can I deploy to multiple servers?**
A: Each server gets its own package copy with its own `.env` configuration.

**Q: How do I handle database migrations?**
A: Include migration scripts in `data/schemas/` and document the process in `docs/upgrade.txt`.

**Q: What if I need to customize the compose file?**
A: You can edit `docker-compose.yaml` after extraction. Consider using Docker Compose override files for environment-specific changes.

### Security

**Q: Is it safe to commit `.env.example`?**
A: Yes, `.env.example` should only contain placeholder values, never real secrets.

**Q: How do I rotate secrets?**
A: Update `.env`, then restart services: `cd compose && docker compose up -d`

---

## License

[Your License Here]

## Contributing

[Contributing Guidelines Here]

## Support

- Documentation: [Link]
- Issues: [GitHub Issues Link]
- Email: [Support Email]
