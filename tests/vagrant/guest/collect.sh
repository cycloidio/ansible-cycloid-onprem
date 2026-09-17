#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/vagrant/guest/lib.sh
source /usr/local/lib/cycloid-acceptance/lib.sh
[[ $# == 1 ]] || fail 'usage: collect.sh <phase>'
valid_id "$1"
# Deliberate allowlist: journal MESSAGE, ExecStart, environment, mounts, and
# application logs can contain credentials and must never enter exported output.
printf 'phase=%s\n' "$1"
uname -srmo
cat /etc/os-release
for command in 'docker --version' 'python3 --version' 'openssl version' 'systemctl --version'; do
    $command 2>/dev/null || true
done
printf '\nservice=concourse-worker\n'
systemctl show concourse-worker.service --property=Id,LoadState,ActiveState,SubState,Result,ExecMainCode,ExecMainStatus,NRestarts 2>/dev/null || true
if [[ -x $BUNDLE/venv/bin/ansible-playbook ]]; then
    "$BUNDLE/venv/bin/ansible-playbook" --version 2>/dev/null | head -1
fi
for name in "${SERVICES[@]}"; do
    printf '\nservice=%s\n' "$name"
    systemctl show "${name}_container.service" --property=Id,LoadState,ActiveState,SubState,Result,ExecMainCode,ExecMainStatus,NRestarts 2>/dev/null || true
    docker inspect --format 'name={{.Name}} image={{.Image}} running={{.State.Running}} status={{.State.Status}} exit={{.State.ExitCode}} restarts={{.RestartCount}}' "$name" 2>/dev/null || true
    docker top "$name" 2>/dev/null | awk 'NR > 1 { count++ } END { printf "processes=%d\n", count+0 }' || true
    journalctl --no-pager -b -n 50 -u "${name}_container.service" -o json 2>/dev/null | python3 -c 'import json,sys
fields=("__REALTIME_TIMESTAMP", "_SYSTEMD_UNIT", "PRIORITY", "SYSLOG_IDENTIFIER", "_PID")
for line in sys.stdin:
 try: item=json.loads(line)
 except ValueError: continue
 print(json.dumps({k:item[k] for k in fields if k in item}, sort_keys=True))' || true
done
printf '\nroutes\n'
ip -brief address 2>/dev/null || true
ip route show 2>/dev/null || true
printf '\nfirewall (comments omitted)\n'
iptables -S 2>/dev/null | sed -E 's/--comment "[^"]*"/--comment [redacted]/g; s/--comment [^ ]+/--comment [redacted]/g' || true
printf '\nlistening TCP ports\n'
ss -lnt 2>/dev/null || true
