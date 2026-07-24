#!/usr/bin/env bash
# shellcheck shell=sh

DIR="$(dirname "$(readlink -f "$0")")"
OUTPUT_DIR="$DIR/.out"

# shellcheck source=./cecho-utils.sh
. "$DIR/cecho-utils.sh"

# Vault KV engine path prefix. Default: "cycloid"
# Change this if you need to isolate multiple deployments on a shared Vault.
# IMPORTANT: Must match:
#   - backend env var VAULT_PATH_PREFIX (or --vault-path-prefix flag)
#   - Concourse env var CONCOURSE_VAULT_PATH_PREFIX (helm: concourse.concourse.web.vault.pathPrefix)
# Example for a dev environment: VAULT_PATH_PREFIX="dev/cycloid"
VAULT_PATH_PREFIX="${VAULT_PATH_PREFIX:-cycloid}"

export VALUES_CUSTOM_YAML="${VALUES_CUSTOM_YAML:-./values.custom.yaml}"

if [ -z "$NAMESPACE" ]; then
  perror "$0 Make sure to defined export NAMESPACE="
  exit 1
fi

if [ ! -f "$VALUES_CUSTOM_YAML" ]; then
  perror "$0 > $VALUES_CUSTOM_YAML file not found"
  exit 1
else
  psuccess "$0 > $VALUES_CUSTOM_YAML successfully found"
fi

if ! command -v jq /dev/null; then
  perror "$0 > jq command not found. Please install it. For exammple apt-get install jq"
  exit 1
fi

command -v jq >/dev/null
JQ_STATUS=$?

set -e

pwarning "$0 > Vault login"
echo ">> Using initial root token"
if [ $JQ_STATUS -eq 0 ] && [ -f "$OUTPUT_DIR/vault-init.json" ]; then
  kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault login "$(jq -r '.root_token' "$OUTPUT_DIR/vault-init.json")"
else
  kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault login
fi

set +e
kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault auth list | grep approle >/dev/null
VAULT_APPROLE_STATUS=$?
set -e
pwarning "$0 > Enabling Vault approle auth backend"
if [ $VAULT_APPROLE_STATUS -ne 0 ]; then
  kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault auth enable approle
else
  perror "$0 > Vault approle auth backend already enabled"
fi

set +e
kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault secrets list | grep "$VAULT_PATH_PREFIX" >/dev/null
VAULT_CYCLOID_KV_STATUS=$?
set -e
pwarning "$0 > Enabling Vault $VAULT_PATH_PREFIX kv secrets backend"
if [ $VAULT_CYCLOID_KV_STATUS -ne 0 ]; then
  kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault secrets enable -path "$VAULT_PATH_PREFIX" kv
else
  perror "$0 > Vault $VAULT_PATH_PREFIX kv secrets backend already enabled"
fi

pwarning "$0 > Writing Vault ${VAULT_PATH_PREFIX}-ro policy"
cat <<EOF | kubectl -n "$NAMESPACE" exec -i cycloid-vault-0 -- vault policy write "${VAULT_PATH_PREFIX}-ro" -
path "${VAULT_PATH_PREFIX}/*" {
  policy = "read"
}

path "auth/token/create" {
  policy = "write"
}

path "auth/token/renew-self" {
  policy = "write"
}
EOF

pwarning "$0 > Writing Vault $VAULT_PATH_PREFIX policy"
cat <<EOF | kubectl -n "$NAMESPACE" exec -i cycloid-vault-0 -- vault policy write "$VAULT_PATH_PREFIX" -
path "${VAULT_PATH_PREFIX}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policy/${VAULT_PATH_PREFIX}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/approle/role/${VAULT_PATH_PREFIX}-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/approle/role/" {
  capabilities = ["read", "list"]
}

path "policies" {
  capabilities = ["read", "list"]
}

path "auth/token/create" {
  capabilities = ["create"]
}

path "auth/token/renew-self" {
  capabilities = ["create"]
}
EOF

set +e
kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault read "auth/approle/role/$VAULT_PATH_PREFIX" >/dev/null 2>&1
VAULT_CYCLOID_APPROLE_STATUS=$?
set -e
pwarning "$0 > Creating Vault $VAULT_PATH_PREFIX approle role"
if [ $VAULT_CYCLOID_APPROLE_STATUS -eq 2 ]; then
  kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault write "auth/approle/role/$VAULT_PATH_PREFIX" token_max_ttl=1h policies="$VAULT_PATH_PREFIX" token_ttl=20m
  kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault read -format=json "auth/approle/role/$VAULT_PATH_PREFIX/role-id" | tee "$OUTPUT_DIR/cycloid-role-id.json"
  pinfo "# ... Save this value as the cycloid role-id"
  kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault write -format=json -f "auth/approle/role/$VAULT_PATH_PREFIX/secret-id" | tee "$OUTPUT_DIR/cycloid-secret-id.json"
  pinfo "# ... Save this value as the cycloid secret-id"
  psuccess "# /!\\ /!\\ Please make sure to backup values.custom.yaml file and the following directory $OUTPUT_DIR"
else
  perror "$0 > Vault $VAULT_PATH_PREFIX approle role already exists"
fi

set +e
kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault read "auth/approle/role/${VAULT_PATH_PREFIX}-ro" >/dev/null 2>&1
VAULT_CYCLOID_APPROLE_STATUS=$?
set -e
pwarning "$0 > Creating Vault ${VAULT_PATH_PREFIX}-ro approle role"
if [ $VAULT_CYCLOID_APPROLE_STATUS -eq 2 ]; then
  kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault write "auth/approle/role/${VAULT_PATH_PREFIX}-ro" period=30m token_max_ttl=0m policies="${VAULT_PATH_PREFIX}-ro" token_ttl=30m
  kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault read -format=json "auth/approle/role/${VAULT_PATH_PREFIX}-ro/role-id" | tee "$OUTPUT_DIR/cycloid-ro-role-id.json"
  pinfo "# ...Save this value as the cycloid-ro role-id"
  kubectl -n "$NAMESPACE" exec -t -i cycloid-vault-0 -- vault write -format=json -f "auth/approle/role/${VAULT_PATH_PREFIX}-ro/secret-id" | tee "$OUTPUT_DIR/cycloid-ro-secret-id.json"
  pinfo "# ... Save this value as the cycloid-ro secret-id"

  pinfo "  ... Writing generated approles into $VALUES_CUSTOM_YAML"
  sed -i "s/##cycloid-vault-approle-role-id##/$(jq -r '.data.role_id' "$OUTPUT_DIR/cycloid-role-id.json")/g" "$VALUES_CUSTOM_YAML"
  sed -i "s/##cycloid-vault-approle-secret-id##/$(jq -r '.data.secret_id' "$OUTPUT_DIR/cycloid-secret-id.json")/g" "$VALUES_CUSTOM_YAML"
  sed -i "s/##cycloid-ro-vault-approle-role-id##/$(jq -r '.data.role_id' "$OUTPUT_DIR/cycloid-ro-role-id.json")/g" "$VALUES_CUSTOM_YAML"
  sed -i "s/##cycloid-ro-vault-approle-secret-id##/$(jq -r '.data.secret_id' "$OUTPUT_DIR/cycloid-ro-secret-id.json")/g" "$VALUES_CUSTOM_YAML"

  psuccess "# /!\\ /!\\ Please make sure to backup values.custom.yaml file and the following directory $OUTPUT_DIR"
else
  perror "$0 > Vault ${VAULT_PATH_PREFIX}-ro approle role already exists"
fi

pwarning "$0 > Vault configured for Cycloid"
