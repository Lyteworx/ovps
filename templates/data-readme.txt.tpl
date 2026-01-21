Data Directory Structure
========================
Vendor Package: {{VENDOR_NAME}}/{{PRODUCT_NAME}} {{VERSION}}

This directory contains all data-related files for the vendor package.

Directory Layout:
-----------------

data/
├── persistent/     # Persistent storage (survives upgrades)
├── sample_data/    # Initial/seed data (copied on first install)
├── schemas/        # Database and configuration schemas
└── ingest/         # Data ingestion pipeline
    ├── incoming/   # Files waiting to be processed
    ├── processing/ # Files currently being processed
    ├── completed/  # Successfully processed files
    └── failed/     # Files that failed processing


persistent/
-----------
This directory is mounted as a Docker volume for persistent storage.
- Data here survives container restarts and upgrades
- Back up this directory before upgrades
- Never delete while services are running

Volume mapping in docker-compose.yaml:
  volumes:
    - ../data/persistent:/app/data


sample_data/
------------
Initial data to seed the application on first install.
- Automatically copied to persistent/ on first install only
- Not copied if persistent/ already contains data
- Safe to modify for custom initial state

Files might include:
- Initial database dumps
- Default configuration files
- Demo/example data


schemas/
--------
Structural definitions for validation and documentation.
- Database schema files (SQL, migrations)
- Configuration schema (JSON Schema, YAML Schema)
- API specifications (OpenAPI, etc.)

These files are for reference and validation, not runtime use.


ingest/
-------
Data ingestion pipeline for ETL/ELT workflows. External systems can drop
files here for processing by the application.

Workflow:
  1. External system drops files into incoming/
  2. Application picks up files and moves them to processing/
  3. After processing completes:
     - Success: File moves to completed/
     - Failure: File moves to failed/

Directory Details:

  incoming/
    - Drop zone for new data files
    - Files here are waiting to be picked up
    - Application should poll or watch this directory

  processing/
    - Files currently being processed
    - Acts as a lock to prevent double-processing
    - Files should only be here temporarily

  completed/
    - Successfully processed files
    - Can be archived or deleted based on retention policy
    - Consider automatic cleanup of old files

  failed/
    - Files that failed processing
    - Check application logs for failure reasons
    - May need manual review, correction, or retry

Volume mapping in docker-compose.yaml:
  volumes:
    - ../data/ingest:/app/ingest

Implementation Notes:
- Use atomic move operations (mv) to transition files between directories
- Include timestamp or unique ID in filenames to avoid collisions
- Consider file locking for multi-process scenarios
- Log all file transitions for audit trail


Backup Recommendations:
-----------------------
1. Stop services before backup: ./scripts/upgrade.sh creates automatic backups
2. Manual backup: tar -czvf backup.tar.gz data/persistent/
3. Restore: Extract backup to data/persistent/


Generated: {{GENERATED_DATE}}
