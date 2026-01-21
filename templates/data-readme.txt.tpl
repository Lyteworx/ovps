Data Directory Structure
========================
Vendor Package: {{VENDOR_NAME}}/{{PRODUCT_NAME}} {{VERSION}}

This directory contains all data-related files for the vendor package.

Directory Layout:
-----------------

data/
├── persistent/     # Persistent storage (survives upgrades)
├── sample_data/    # Initial/seed data (copied on first install)
└── schemas/        # Database and configuration schemas


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


Backup Recommendations:
-----------------------
1. Stop services before backup: ./scripts/upgrade.sh creates automatic backups
2. Manual backup: tar -czvf backup.tar.gz data/persistent/
3. Restore: Extract backup to data/persistent/


Generated: {{GENERATED_DATE}}
