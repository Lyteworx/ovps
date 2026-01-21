{{PRODUCT_NAME}} Upgrade Guide
================================================================================
Version: {{VERSION}}

Before You Begin
----------------

IMPORTANT: Always back up your data before upgrading!

The upgrade script creates automatic backups, but we recommend:
1. Creating a manual backup of data/persistent/
2. Documenting any custom configurations
3. Planning for potential downtime


Upgrade Prerequisites
---------------------
1. Current installation is healthy
   - Verify with: ./scripts/healthcheck.sh

2. New package is extracted and accessible

3. Sufficient disk space for backup (2x current data size recommended)


Upgrade Process
---------------

Step 1: Pre-Upgrade Health Check
   Ensure the current installation is working correctly:

   $ ./scripts/healthcheck.sh

   Do not proceed if health checks fail. Fix issues first.


Step 2: Review Release Notes
   [Check release notes for version-specific upgrade considerations]

   Breaking changes in this version:
   - [List any breaking changes]

   New requirements:
   - [List any new system requirements]


Step 3: Run Upgrade Script
   From the NEW package directory, run:

   $ ./scripts/upgrade.sh

   The script will automatically:
   - Detect the current running version
   - Create a backup of persistent data
   - Stop current services gracefully
   - Load new container images
   - Start services with new version
   - Run post-upgrade health checks


Step 4: Verify Upgrade
   After the upgrade completes:

   $ ./scripts/healthcheck.sh

   Verify application functionality manually.


Manual Upgrade Options
----------------------

Specify the previous version explicitly:
   $ ./scripts/upgrade.sh --from-version v1.0.0

Specify a custom backup directory:
   $ ./scripts/upgrade.sh --backup-dir /opt/backups/{{PRODUCT_NAME}}


Rollback Procedure
------------------

If the upgrade fails, automatic rollback is attempted.

For manual rollback:

1. Stop new services:
   $ cd compose && docker compose down

2. Restore data from backup:
   $ rm -rf data/persistent/*
   $ cp -r <backup-dir>/persistent/* data/persistent/

3. Load previous container images (from old package)

4. Start services:
   $ cd compose && docker compose up -d

5. Verify with health check:
   $ ./scripts/healthcheck.sh


Post-Upgrade Tasks
------------------
1. Verify all functionality
2. Update any external integrations
3. Review new configuration options
4. Update documentation/runbooks
5. Clean up old backups after confirming stability


Troubleshooting
---------------

Problem: Upgrade script fails to detect version
Solution: Use --from-version flag to specify explicitly

Problem: Backup fails (disk space)
Solution: Free disk space or use --backup-dir to specify alternate location

Problem: Services fail to start after upgrade
Solution: Check logs and consider rollback procedure above


================================================================================
Generated: {{GENERATED_DATE}}
