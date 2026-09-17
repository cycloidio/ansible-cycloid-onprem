#!/usr/bin/env bash
# Shared by root-only guest entry points. Never enable shell tracing here.
set -euo pipefail
umask 077
BASE=/opt/cycloid-acceptance
BUNDLE=$BASE/bundle
STATE=$BASE/state
RAW=/var/tmp/cycloid-acceptance
# Used by the sourced verification and collection entry points.
# shellcheck disable=SC2034
SERVICES=(cycloid-db cycloid-api cycloid-api-task-manager cycloid-cache cycloid-frontend concourse-db concourse-web vault nginx)
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ $EUID == 0 ]] || fail 'run as root'
install -d -m 0700 "$BASE" "$STATE" "$RAW"
valid_id() { [[ $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || fail 'invalid identifier'; }
phase_arg() {
    [[ $# == 1 ]] || fail 'expected one phase argument'
    # shellcheck disable=SC2034
    case "$1" in initial|post-install|install) PHASE=initial;; post-rerun|rerun) PHASE=post-rerun;; post-reboot|reboot) PHASE=post-reboot;; *) fail 'invalid phase';; esac
}
run_helper() {
    local action=$1 log=$RAW/$2.log status
    [[ -f $BUNDLE/helper.sh ]] || fail 'bundle helper.sh missing'
    # helper.sh also writes a hardcoded log. Keep that destination root-only.
    [[ ! -e /tmp/cycloid-install.log && ! -L /tmp/cycloid-install.log ]] || {
        [[ -L /tmp/cycloid-install.log && $(readlink /tmp/cycloid-install.log) == "$RAW/helper.log" ]] || fail 'unexpected existing helper log'
    }
    touch "$RAW/helper.log"
    chmod 0600 "$RAW/helper.log"
    ln -sfn "$RAW/helper.log" /tmp/cycloid-install.log
    if (cd "$BUNDLE" && CYCLOID_CONSOLE_DNS=cycloid-acceptance.test bash ./helper.sh "$action") >"$log" 2>&1; then
        printf '%s completed\n' "$action"
    else
        status=$?
        printf 'FAIL: %s exited %s; restricted guest log: %s\n' "$action" "$status" "$log" >&2
        return "$status"
    fi
}
# Return exactly one nonempty value, without dumping the container environment.
container_env() {
    docker inspect "$1" | python3 -c 'import json,sys
items=json.load(sys.stdin)[0]["Config"]["Env"]
key=sys.argv[1]+"="
values=[x[len(key):] for x in items if x.startswith(key)]
if len(values)!=1 or not values[0] or "\n" in values[0] or "\r" in values[0]: sys.exit(1)
sys.stdout.write(values[0])' "$2"
}
