#!/bin/bash
#
# nextcloud-client-sync container entrypoint.sh v1.1
# Author: Scott Shambarger <devel@shambarger.net>
#
# Copyright (C) Scott Shambarger. All rights reserved.
# SPDX-License-Identifier: GPL-2.0-or-later
#
# shellcheck disable=SC2086

log() { echo "$(date -D "%m-%d %H:%M:%S"): $*"; }
err() { log >&2 "$*"; }
fatal() { err "$*"; exit 1; }

to_int() { # <var>
  printf 2>/dev/null -v "$1" "%d" "${!1-}" || printf -v "$1" 0
}

# sanity check
to_int NC_LOG_MAX_BYTES
(( NC_LOG_MAX_BYTES < 20000 )) && NC_LOG_MAX_BYTES=20000
to_int NC_LOG_ARCHIVES
(( NC_LOG_ARCHIVES < 1 )) && NC_LOG_ARCHIVES=1
to_int NC_ERROR_COUNT
(( NC_ERROR_COUNT < 1 )) && NC_ERROR_COUNT=''
to_int NC_ERROR_REMIND_COUNT
(( NC_ERROR_REMIND_COUNT < 1 )) && NC_ERROR_REMIND_COUNT=''

log_rotate() {
  local i d=$NC_LOG_FILE
  [[ $d ]] || return
  if [[ $(find "$d" -size "+${NC_LOG_MAX_BYTES}c") ]]; then
    for ((i==NC_LOG_ARCHIVES-1; i>0; i--)); do
      [[ -f "$d.$i" ]] && mv "$d."{$i,$((i+1))}
    done
    mv "$d" "$d.1"
    exec > "$d"
  fi
}

if [[ $NC_LOG_FILE ]] && touch "$NC_LOG_FILE" && [[ -w $NC_LOG_FILE ]]; then
  exec >> "$NC_LOG_FILE"
  exec 2> >(while read -r
            do echo >&2 "$REPLY"
               echo "$REPLY" >> "$NC_LOG_FILE"
            done)
else
  log "Unable to access log file '$NC_LOG_FILE'"
  NC_LOG_FILE=
fi

error_log=/tmp/cmd.log
NC_ERROR_FROM=${NC_ERROR_FROM:-nextcloud-client-sync}
NC_ERROR_SUBJECT=${NC_ERROR_SUBJECT:-nextcloud-client-sync failed}

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

[[ -z $NC_VERBOSE && -z $NC_ERROR_TO ]] && NC_ARGS+=(-s)
[[ $NC_PATH ]] && NC_ARGS+=(--path "$NC_PATH")

fail_count=0

while :; do

  log_rotate
  log "Running nextcloudcmd"
  if [[ $NC_ERROR_TO ]]; then
    nextcloudcmd &>"$error_log" ${NC_OPTIONS} "${NC_ARGS[@]}" "$NC_DATADIR" "$NC_URL"
  else
    nextcloudcmd ${NC_OPTIONS} "${NC_ARGS[@]}" "$NC_DATADIR" "$NC_URL"
  fi
  rc=$?

  delay=$NC_RESTART_SECS

  if [[ $rc -ne 0 ]]; then
    if (( fail_count++ == 0 )); then
      # log details
      err nextcloudcmd ${NC_OPTIONS} "${NC_ARGS[@]}" "$NC_DATADIR" "$NC_URL"
      err " failed: err $rc"
      err "$(<"$error_log")"
    else
      err "nextcloudcmd failure $fail_count: err $rc"
    fi
    [[ $delay && $NC_FAIL_RETRY_SECS ]] && delay=$NC_FAIL_RETRY_SECS

    if [[ $NC_ERROR_TO ]]; then
      if [[ $fail_count == "${NC_ERROR_COUNT:-1}" ]]; then
        err "Sending error email to $NC_ERROR_TO"
        sendmail $NC_SENDMAIL_OPTIONS -f "$NC_ERROR_FROM" $NC_ERROR_TO <<-EOF
	From: $NC_ERROR_FROM
	To: $NC_ERROR_TO
	Subject: $NC_ERROR_SUBJECT
	Date: $(date -R)

	Command failed $fail_count times (error $rc):
	nextcloudcmd ${NC_OPTIONS} "${NC_ARGS[@]}" "$NC_DATADIR" "$NC_URL"

	Error log:
	$(<"$error_log")

	EOF
      elif [[ $NC_ERROR_REMIND_COUNT &&
                $((fail_count % NC_ERROR_REMIND_COUNT)) == 0 ]]; then
        err "Sending reminder email to $NC_ERROR_TO"
        sendmail $NC_SENDMAIL_OPTIONS -f "$NC_ERROR_FROM" $NC_ERROR_TO <<-EOF
	From: $NC_ERROR_FROM
	To: $NC_ERROR_TO
	Subject: Reminder: $NC_ERROR_SUBJECT
	Date: $(date -R)

	Command still failing (now $fail_count times, error $rc):
	nextcloudcmd ${NC_OPTIONS} "${NC_ARGS[@]}" "$NC_DATADIR" "$NC_URL"

	Error log:
	$(<"$error_log")

	EOF
      fi
    fi
  else
    fail_count=0
  fi
  # if not looping, exit
  [[ $delay && $delay -gt 0 ]] || exit $rc

  # sleep before resync
  log "Sleeping $delay secs"
  sleep "$delay"
done

exit 0
