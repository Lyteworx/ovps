{{PRODUCT_NAME}} Installation Guide
================================================================================
Version: {{VERSION}}

Prerequisites
-------------
Before installing, ensure your system meets the following requirements:

1. Docker 20.10.0 or later installed and running
   - Verify with: docker --version
   - Start daemon: systemctl start docker (Linux) or start Docker Desktop

2. Docker Compose v2 available
   - Verify with: docker compose version

3. Sufficient disk space (minimum 10GB)
   - Check with: df -h

4. Sufficient memory (minimum 4GB)

5. Supported CPU architecture (amd64 or arm64)
   - Check with: uname -m


Installation Steps
------------------

Step 1: Validate Environment
   Run the environment validation script to ensure all prerequisites are met:

   $ ./scripts/validate_environment.sh

   This checks Docker installation, version, disk space, and architecture.
   Fix any reported errors before proceeding.


Step 2: Validate Container Images
   Verify the integrity of container images included in the package:

   $ ./scripts/validate_containers.sh

   This verifies checksums and file integrity without loading images.


Step 3: Run Installation
   Execute the main installation script:

   $ ./scripts/install.sh

   This script will:
   - Load container images into Docker
   - Initialize data directories
   - Start all services using Docker Compose
   - Run health checks to verify deployment


Step 4: Verify Installation
   Run the health check script to confirm all services are running:

   $ ./scripts/healthcheck.sh

   All services should report as healthy.


Post-Installation
-----------------

Accessing the Application:
   [Provide access URLs and default credentials]

   Default URL: http://localhost:8080
   Default user: admin
   Default password: [change on first login]


Viewing Logs:
   $ cd compose && docker compose logs -f


Stopping Services:
   $ cd compose && docker compose down


Starting Services:
   $ cd compose && docker compose up -d


Troubleshooting
---------------

Problem: Container images fail to load
Solution: Verify checksums with: shasum -a 256 -c checksums/sha256.txt

Problem: Services fail to start
Solution: Check Docker daemon: docker info
          Check logs: cd compose && docker compose logs

Problem: Health checks fail
Solution: Wait for services to initialize (may take 1-2 minutes)
          Check container status: cd compose && docker compose ps


================================================================================
Generated: {{GENERATED_DATE}}
