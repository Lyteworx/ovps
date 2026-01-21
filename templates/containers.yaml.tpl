# Container Images Configuration
# Vendor Package: {{VENDOR_NAME}}/{{PRODUCT_NAME}} {{VERSION}}
#
# This file documents all container images included in this package.
# Container images are stored in: containers/{{VERSION}}/
#
# Supported formats:
#   - .tar.gz: Docker save format, gzip compressed (docker save | gzip)
#   - .tar: Docker save format, uncompressed (docker save)
#   - .oci: OCI image layout format
#
# To export an image for this package:
#   docker save <image>:<tag> | gzip > containers/{{VERSION}}/<name>.tar.gz

images:
  # Example image entry:
  # - name: "{{VENDOR_NAME}}/{{PRODUCT_NAME}}-app"
  #   file: "containers/{{VERSION}}/app.tar.gz"
  #   tag: "{{VERSION}}"
  #   digest: "sha256:..."  # Optional: specific image digest
  #   platform:
  #     os: "linux"
  #     architecture: "amd64"
  #   size_mb: 150  # Approximate size in megabytes
  #   description: "Main application image"

# Loading instructions:
# Images are loaded automatically by validate_containers.sh --load
# Manual loading:
#   gunzip -c containers/{{VERSION}}/<name>.tar.gz | docker load
#   docker load < containers/{{VERSION}}/<name>.tar

# Verification:
# After loading, verify images with:
#   docker images | grep {{VENDOR_NAME}}

metadata:
  format_version: "1.0"
  generated: "{{GENERATED_DATE}}"
  total_images: 0
  total_size_mb: 0
