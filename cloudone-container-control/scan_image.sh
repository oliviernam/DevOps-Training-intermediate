#/bin/bash
# ##############################################################################
# Pulls an image, initiates a scan with Smart Check and creates a PDF report
# ##############################################################################
# TARGET_IMAGE=alpine
# TARGET_IMAGE_TAG=latest
# DSSC_REGISTRY="<smart check preregistry url:port>"
# DSSC_SERVICE="<smart check url:port>"
# DSSC_USERNAME="<smart check username>"
# DSSC_PASSWORD="<smart check password>"
# DSSC_REGISTRY_USERNAME="<smart check preregistry username>"
# DSSC_REGISTRY_PASSWORD="<smart check preregistry password>"

docker pull ${TARGET_IMAGE}:${TARGET_IMAGE_TAG}

docker run -v /var/run/docker.sock:/var/run/docker.sock \
  deepsecurity/smartcheck-scan-action \
  --image-name "${TARGET_IMAGE}:${TARGET_IMAGE_TAG}" \
  --preregistry-host="$DSSC_REGISTRY" \
  --smartcheck-host="$DSSC_SERVICE" \
  --smartcheck-user="$DSSC_USERNAME" \
  --smartcheck-password="$DSSC_PASSWORD" \
  --insecure-skip-tls-verify \
  --preregistry-scan \
  --preregistry-user "$DSSC_REGISTRY_USERNAME" \
  --preregistry-password "$DSSC_REGISTRY_PASSWORD"

docker run mawinkler/scan-report:dev -O \
  --name "${TARGET_IMAGE}" \
  --image_tag "${TARGET_IMAGE_TAG}" \
  --service "${DSSC_SERVICE}" \
  --username "${DSSC_USERNAME}" \
  --password "${DSSC_PASSWORD}" > report_${TARGET_IMAGE}.pdf
