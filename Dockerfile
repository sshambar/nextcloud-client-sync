# use base image from Docker Hub and upgrade existing packages
FROM nextcloud-client-base:latest

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
    NC_LOG_FILE="" \
    NC_LOG_MAX_BYTES=1048576 \
    NC_LOG_ARCHIVES=4 \
    NC_OPTIONS="" \
    NC_VERBOSE="" \
    NC_RESTART_SECS="" \
    NC_FAIL_RETRY_SECS=300 \
    NC_ERROR_TO="" \
    NC_SENDMAIL_OPTIONS="" \
    NC_ERROR_FROM="" \
    NC_ERROR_SUBJECT="" \
    NC_ERROR_COUNT=""

COPY entrypoint.sh /entrypoint.sh
RUN chmod a+rx /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
