# Docker Compose Configuration
# Vendor Package: {{VENDOR_NAME}}/{{PRODUCT_NAME}} {{VERSION}}
#
# IMPORTANT: This compose file must work OFFLINE
# - All images must be pre-loaded from containers/{{VERSION}}/
# - No remote image pulls should be required
# - Use local image references only

version: "3.8"

# ============================================================
# TODO: Define your services below
# ============================================================
#
# Example service configuration:
#
# services:
#   app:
#     image: {{VENDOR_NAME}}/{{PRODUCT_NAME}}-app:{{VERSION}}
#     container_name: {{PRODUCT_NAME}}-app
#     restart: unless-stopped
#     ports:
#       - "8080:80"
#     volumes:
#       - ../data/persistent:/app/data
#     environment:
#       - APP_ENV=production
#     healthcheck:
#       test: ["CMD", "curl", "-f", "http://localhost/health"]
#       interval: 30s
#       timeout: 10s
#       retries: 3
#       start_period: 40s
#
#   db:
#     image: {{VENDOR_NAME}}/{{PRODUCT_NAME}}-db:{{VERSION}}
#     container_name: {{PRODUCT_NAME}}-db
#     restart: unless-stopped
#     volumes:
#       - ../data/persistent/db:/var/lib/postgresql/data
#     environment:
#       - POSTGRES_DB={{PRODUCT_NAME}}
#       - POSTGRES_USER={{PRODUCT_NAME}}
#       - POSTGRES_PASSWORD=changeme

services: {}

# Networks (optional - Docker creates default network)
# networks:
#   {{PRODUCT_NAME}}-network:
#     driver: bridge

# Named volumes (optional - prefer bind mounts to ../data/persistent)
# volumes:
#   {{PRODUCT_NAME}}-data:
