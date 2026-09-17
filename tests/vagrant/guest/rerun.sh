#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/vagrant/guest/lib.sh
source /usr/local/lib/cycloid-acceptance/lib.sh
[[ $# == 0 ]] || fail 'usage: rerun.sh'
[[ -s $STATE/cert-fingerprint && -s $STATE/boot-id ]] || fail 'initial verification must pass before rerun'
run_helper install-cycloid rerun
