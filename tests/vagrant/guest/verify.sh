#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/vagrant/guest/lib.sh
source /usr/local/lib/cycloid-acceptance/lib.sh
phase_arg "$@"
# All diagnostic output from probes stays on the guest; only named results escape.
exec 3>&1 4>&2
exec >"$RAW/verify-$PHASE.log" 2>&1
trap 'status=$?; if (( status != 0 )); then printf "FAIL: verification %s (restricted guest log: %s)\n" "$PHASE" "$RAW/verify-$PHASE.log" >&4; fi' EXIT
pass() { printf 'PASS: %s\n' "$1" >&3; }
wait_for() {
    local description=$1 attempt
    shift
    for ((attempt=1; attempt<=60; attempt++)); do
        if "$@"; then return 0; fi
        sleep 2
    done
    fail "timed out waiting for $description"
}
service_ready() {
    systemctl is-active --quiet "$1_container.service" &&
        [[ $(docker inspect --format '{{.State.Running}}' "$1" 2>/dev/null) == true ]] &&
        docker top "$1" 2>/dev/null | awk 'NR > 1 { found=1 } END { exit !found }'
}
for name in "${SERVICES[@]}"; do
    wait_for "$name" service_ready "$name"
done
wait_for concourse-worker systemctl is-active --quiet concourse-worker.service
declare -A restart_counts
for name in "${SERVICES[@]}"; do
    restart_counts[$name]=$(docker inspect --format '{{.RestartCount}}' "$name")
done
sleep 5
for name in "${SERVICES[@]}"; do
    [[ $(docker inspect --format '{{.RestartCount}}' "$name") == "${restart_counts[$name]}" ]]
done
pass 'required systemd units and exact container names'

cert=/opt/cycloid/cycloid.crt
key=/opt/cycloid/cycloid.key
openssl x509 -in "$cert" -noout -checkend 0
san=$(openssl x509 -in "$cert" -noout -ext subjectAltName)
[[ $san == *DNS:cycloid-acceptance.test* && $san != *None* && $san != *DNS:,* ]]
cert_key=$(openssl x509 -in "$cert" -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum)
private_key=$(openssl pkey -in "$key" -pubout -outform DER | sha256sum)
[[ $cert_key == "$private_key" ]]
fingerprint=$(openssl x509 -in "$cert" -noout -fingerprint -sha256)
boot_id=$(</proc/sys/kernel/random/boot_id)
[[ -s $STATE/run-id ]]
run_id=$(<"$STATE/run-id")
valid_id "$run_id"
if [[ $PHASE != initial ]]; then
    [[ -s $STATE/cert-fingerprint && -s $STATE/boot-id ]]
    [[ $fingerprint == "$(<"$STATE/cert-fingerprint")" ]]
    if [[ $PHASE == post-reboot ]]; then [[ $boot_id != "$(<"$STATE/boot-id")" ]]; fi
else
    [[ ! -e $STATE/cert-fingerprint ]] || fail 'baseline already exists'
fi
pass 'certificate validity, SANs, key match and persistence'

mysql_image=$(docker inspect --format '{{.Image}}' cycloid-db)
pg_image=$(docker inspect --format '{{.Image}}' concourse-db)
[[ -n $mysql_image && -n $pg_image ]]
DB_HOST=$(container_env cycloid-api DB_HOST)
DB_PORT=$(container_env cycloid-api DB_PORT)
DB_USER=$(container_env cycloid-api DB_USER)
DB_NAME=$(container_env cycloid-api DB_NAME)
MYSQL_PWD=$(container_env cycloid-api DB_PWD)
export DB_HOST DB_PORT DB_USER DB_NAME MYSQL_PWD
mysql_query() {
    docker run --rm -i --network container:cycloid-api --entrypoint sh \
        -e DB_HOST -e DB_PORT -e DB_USER -e DB_NAME -e MYSQL_PWD "$mysql_image" \
        -c 'exec mysql --protocol=TCP --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" --database="$DB_NAME" --batch --skip-column-names' <<<"$1"
}
PGHOST=$(container_env concourse-web CONCOURSE_POSTGRES_HOST)
PGPORT=$(container_env concourse-web CONCOURSE_POSTGRES_PORT)
PGUSER=$(container_env concourse-web CONCOURSE_POSTGRES_USER)
PGDATABASE=$(container_env concourse-web CONCOURSE_POSTGRES_DATABASE)
PGPASSWORD=$(container_env concourse-web CONCOURSE_POSTGRES_PASSWORD)
PGSSLMODE=$(container_env concourse-web CONCOURSE_POSTGRES_SSLMODE)
export PGHOST PGPORT PGUSER PGDATABASE PGPASSWORD PGSSLMODE
pg_query() {
    docker run --rm -i --network container:concourse-web --entrypoint psql \
        -e PGHOST -e PGPORT -e PGUSER -e PGDATABASE -e PGPASSWORD -e PGSSLMODE \
        "$pg_image" -X -A -t -v ON_ERROR_STOP=1 <<<"$1"
}
mysql_ready() { [[ $(mysql_query 'SELECT 1;') == 1 ]]; }
pg_ready() { [[ $(pg_query 'SELECT 1;') == 1 ]]; }
wait_for MySQL mysql_ready
wait_for PostgreSQL pg_ready
if [[ $PHASE == initial ]]; then
    mysql_query "CREATE TABLE cycloid_acceptance_sentinel (id INTEGER PRIMARY KEY, run_id VARCHAR(128) NOT NULL); INSERT INTO cycloid_acceptance_sentinel VALUES (1, '$run_id');"
    pg_query "CREATE TABLE cycloid_acceptance_sentinel (id INTEGER PRIMARY KEY, run_id VARCHAR(128) NOT NULL); INSERT INTO cycloid_acceptance_sentinel VALUES (1, '$run_id');"
fi
[[ $(mysql_query 'SELECT run_id FROM cycloid_acceptance_sentinel WHERE id=1;') == "$run_id" ]]
[[ $(pg_query 'SELECT run_id FROM cycloid_acceptance_sentinel WHERE id=1;') == "$run_id" ]]
unset MYSQL_PWD PGPASSWORD
pass 'authenticated MySQL and PostgreSQL from application namespaces; persistent sentinels'

http_probe() {
    local label=$1 expected=$2 pattern=$3 url=$4 code attempt body="$RAW/http-$1.body"
    shift 4
    for ((attempt=1; attempt<=30; attempt++)); do
        code=$(curl --noproxy '*' --silent --show-error --connect-timeout 3 --max-time 10 -o "$body" -w '%{http_code}' "$@" "$url") || code=000
        if [[ $code == "$expected" ]] && grep -Fq -- "$pattern" "$body"; then return 0; fi
        sleep 2
    done
    fail "$label HTTP probe failed: expected status $expected and identifying response"
}
http_probe api-direct 403 'Credential was rejected from API Request' http://127.0.0.1:3001/user
http_probe api-nginx 403 'Credential was rejected from API Request' https://cycloid-acceptance.test/api/user --cacert "$cert" --resolve cycloid-acceptance.test:443:127.0.0.1
http_probe concourse 200 '"version"' https://127.0.0.1:8443/api/v1/info --insecure
vault_ready() {
    local status
    status=$(curl --noproxy '*' --silent --show-error --fail --insecure --max-time 10 https://127.0.0.1:8200/v1/sys/health) || return 1
    printf '%s' "$status" | python3 -c 'import json,sys; x=json.load(sys.stdin); sys.exit(0 if x.get("initialized") is True and x.get("sealed") is False else 1)'
}
wait_for Vault vault_ready
pass 'direct/proxied API 403, Concourse info 200, Vault initialized and unsealed'
if [[ $PHASE == initial ]]; then
    printf '%s\n' "$fingerprint" >"$STATE/cert-fingerprint"
    printf '%s\n' "$boot_id" >"$STATE/boot-id"
fi
if [[ $PHASE == post-reboot ]]; then pass 'boot ID changed'; fi
pass "$PHASE verification complete"
