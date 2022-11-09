# use base image from Docker Hub and upgrade existing packages
FROM nextcloud-client-base:latest AS base

# Set container label
LABEL org.opencontainers.image.title="Nextcloud Client Sync Image" \
      org.opencontainers.image.authors="Scott Shambarger <devel@shambarger.net>" \
      org.opencontainers.image.url="https://github.com/sshambar/nextcloud-client-sync"

# Runtime variables
ENV NC_URL="" \
    NC_PATH="" \
    NC_NETRC="/netrc" \
    NC_EXCLUDE="/sync-exclude.lst" \
    NC_DATADIR="/data" \
    NC_OPTIONS="" \
    NC_VERBOSE="" \
    NC_RESYNC_SECS="" \
    NC_FAIL_RETRY_SECS=300

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
