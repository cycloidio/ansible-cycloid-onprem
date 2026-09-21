#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/vagrant/guest/lib.sh
source /usr/local/lib/cycloid-acceptance/lib.sh
[[ $# == 2 ]] || fail 'usage: upgrade.sh <archive|checkout> <run_id>'
[[ -s $STATE/machine ]] || fail 'primary install must complete before upgrade'
case "$1" in archive | checkout) ;; *) fail 'invalid source mode' ;; esac
valid_id "$2"
[[ -f /tmp/cycloid-onprem-upgrade.tar ]] || fail 'upgrade bundle archive missing'
UPGRADE_BUNDLE=$BASE/bundle-upgrade
[[ ! -e $UPGRADE_BUNDLE ]] || fail 'upgrade bundle already exists; use a fresh VM'
install -d -m 0700 "$UPGRADE_BUNDLE"
tar --no-same-owner --strip-components=1 -xf /tmp/cycloid-onprem-upgrade.tar -C "$UPGRADE_BUNDLE" >"$RAW/extract-upgrade.log" 2>&1
[[ -f $UPGRADE_BUNDLE/helper.sh ]] || fail 'upgrade archive must contain cycloid-onprem/helper.sh'
if [[ $1 == checkout ]]; then
  [[ -f /tmp/ansible-cycloid-onprem-upgrade.tar.gz ]] || fail 'upgrade candidate archive missing'
  [[ -d $UPGRADE_BUNDLE/roles/ansible-cycloid-onprem && ! -L $UPGRADE_BUNDLE/roles/ansible-cycloid-onprem ]] || fail 'bundled role missing or symlinked'
  mv "$UPGRADE_BUNDLE/roles/ansible-cycloid-onprem" "$BASE/bundled-role-upgrade"
  install -d -m 0700 "$UPGRADE_BUNDLE/roles/ansible-cycloid-onprem"
  tar --no-same-owner --strip-components=1 -xzf /tmp/ansible-cycloid-onprem-upgrade.tar.gz -C "$UPGRADE_BUNDLE/roles/ansible-cycloid-onprem" >>"$RAW/extract-upgrade.log" 2>&1
  [[ -f $UPGRADE_BUNDLE/roles/ansible-cycloid-onprem/tasks/main.yml ]] || fail 'candidate role archive has unexpected layout'
  # Bundle generation copies these playbooks to the archive root. Mirror that
  # layout so checkout mode exercises candidate playbook changes as well.
  cp -a "$UPGRADE_BUNDLE/roles/ansible-cycloid-onprem/playbooks/." "$UPGRADE_BUNDLE/"
fi
printf '%s\n' "$1" >"$STATE/upgrade-source-mode"
printf '%s\n' "$2" >"$STATE/upgrade-run-id"
run_helper install upgrade-install "$UPGRADE_BUNDLE"
