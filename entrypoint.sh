#!/bin/bash

log() {
  echo "$(date -D "%m-%d %H:%M:%S"): $*"
}

fatal() {
  log "$*"
  exit 1
}

log "Starting up..."

[[ $NC_URL ]] || fatal "NC_URL empty"

# make sure we have a bind mounted directory to sync to
[[ -d $NC_DATADIR ]] || fatal "NC_DATADIR '$NC_DATADIR' missing (map it in)"

NC_ARGS=(--non-interactive)

if [[ -f $NC_NETRC ]]; then
  [[ -r $NC_NETRC ]] || fatal "NC_NETRC '$NET_RC' not readable by uid $EUID"
  [[ -s $NC_NETRC ]] || fatal "NC_NETRC '$NET_RC' empty"

  # put .netrc in /tmp, set HOME
  export HOME=/tmp
  ln -f -s "$NC_NETRC" /tmp/.netrc || fatal "Unable to symlink /tmp/.netrc"

  NC_ARGS+=(-n)
fi

if [[ -f $NC_EXCLUDE ]]; then
  [[ -r $NC_EXCLUDE ]] || \
    fatal "NC_EXCLUDE '$NET_EXCLUDE' not readable by uid $EUID"
  NC_ARGS+=(--exclude "$NC_EXCLUDE")
fi

[[ $NC_VERBOSE ]] || NC_ARGS+=(-s)
[[ $NC_PATH ]] && NC_ARGS+=(--path "$NC_PATH")

while :; do

  log "Running nextcloudcmd"
  nextcloudcmd ${NC_OPTIONS} "${NC_ARGS[@]}" "$NC_DATADIR" "$NC_URL"
  rc=$?

  delay=$NC_RESYNC_SECS
  if [[ $rc -ne 0 ]]; then
    log nextcloudcmd ${NC_OPTIONS} "${NC_ARGS[@]}" "$NC_DATADIR" "$NC_URL"
    log " command failed ($rc)"
    [[ $delay && $NC_FAIL_RETRY_SECS ]] && delay=$NC_FAIL_RETRY_SECS
  fi
  # if not looping, exit
  [[ $delay && $delay -gt 0 ]] || exit $rc

  # sleep before resync
  log "Sleeping $delay secs"
  sleep $delay
done

exit 0
