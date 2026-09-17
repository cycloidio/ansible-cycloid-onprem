#!/usr/bin/env bash
set -euo pipefail
umask 077
[[ $EUID == 0 ]] || { echo 'run as root' >&2; exit 1; }
install -d -m 0700 /usr/local/lib/cycloid-acceptance
for script in lib.sh install.sh rerun.sh verify.sh collect.sh; do
    install -m 0700 "/tmp/cycloid-acceptance-guest/$script" "/usr/local/lib/cycloid-acceptance/$script"
done
# shellcheck source=tests/vagrant/guest/lib.sh
source /usr/local/lib/cycloid-acceptance/lib.sh
[[ $# == 3 ]] || fail 'usage: install.sh <machine> <archive|checkout> <run_id>'
root_kb=$(df --output=size / | awk 'NR == 2 { print $1 }')
[[ $root_kb =~ ^[0-9]+$ && $root_kb -ge 52428800 ]] || fail 'guest root filesystem must be at least 50 GiB'
valid_id "$1"
valid_id "$3"
case "$2" in archive|checkout) ;; *) fail 'invalid source mode';; esac
[[ -f /tmp/cycloid-onprem.tar ]] || fail 'bundle archive missing'
[[ ! -e $BUNDLE ]] || fail 'bundle already exists; use rerun.sh or a fresh VM'
install -d -m 0700 "$BUNDLE"
tar --no-same-owner --strip-components=1 -xf /tmp/cycloid-onprem.tar -C "$BUNDLE" >"$RAW/extract.log" 2>&1
[[ -f $BUNDLE/helper.sh ]] || fail 'archive must contain cycloid-onprem/helper.sh'
if [[ $2 == checkout ]]; then
    [[ -f /tmp/ansible-cycloid-onprem.tar.gz ]] || fail 'candidate archive missing'
    [[ -d $BUNDLE/roles/ansible-cycloid-onprem && ! -L $BUNDLE/roles/ansible-cycloid-onprem ]] || fail 'bundled role missing or symlinked'
    mv "$BUNDLE/roles/ansible-cycloid-onprem" "$BASE/bundled-role"
    install -d -m 0700 "$BUNDLE/roles/ansible-cycloid-onprem"
    tar --no-same-owner --strip-components=1 -xzf /tmp/ansible-cycloid-onprem.tar.gz -C "$BUNDLE/roles/ansible-cycloid-onprem" >>"$RAW/extract.log" 2>&1
    [[ -f $BUNDLE/roles/ansible-cycloid-onprem/tasks/main.yml ]] || fail 'candidate role archive has unexpected layout'
    # Bundle generation copies these playbooks to the archive root. Mirror that
    # layout so checkout mode exercises candidate playbook changes as well.
    cp -a "$BUNDLE/roles/ansible-cycloid-onprem/playbooks/." "$BUNDLE/"
fi
printf '%s\n' "$1" >"$STATE/machine"
printf '%s\n' "$2" >"$STATE/source-mode"
printf '%s\n' "$3" >"$STATE/run-id"
run_helper install install
