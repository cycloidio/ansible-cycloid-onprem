#!/usr/bin/env sh

DIR="$(dirname $(readlink -f $0))"
OUTPUT_DIR="$DIR/.out"

source $DIR/cecho-utils.sh

if [ -z "$NAMESPACE" ]
then
      perror "$0 Make sure to defined export NAMESPACE="
      exit 1
fi

command -v jq >/dev/null
JQ_STATUS=$?

set -e

pwarning "$0 > Vault login"
echo ">> Using initial root token"
if [ $JQ_STATUS -eq 0 ] && [ -f "$OUTPUT_DIR/vault-init.json" ]; then
  kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault login $(cat "$OUTPUT_DIR/vault-init.json" | jq -r '.root_token')
else
  kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault login
fi

set +e
kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault auth list | grep approle >/dev/null
VAULT_APPROLE_STATUS=$?
set -e
pwarning "$0 > Enabling Vault approle auth backend"
if [ $VAULT_APPROLE_STATUS -ne 0 ]; then
  kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault auth enable approle
else
  perror "$0 > Vault approle auth backend already enabled"
fi

set +e
kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault secrets list | grep cycloid  >/dev/null
VAULT_CYCLOID_KV_STATUS=$?
set -e
pwarning "$0 > Enabling Vault cycloid kv secrets backend"
if [ $VAULT_CYCLOID_KV_STATUS -ne 0 ]; then
  kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault secrets enable -path cycloid kv
else
  perror "$0 > Vault cycloid kv secrets backend already enabled"
fi

pwarning "$0 > Writing Vault cycloid-ro policy"
cat << EOF | kubectl -n $NAMESPACE exec -i cycloid-vault-0 -- vault policy write cycloid-ro -
path "cycloid/*" {
  policy = "read"
}

path "auth/token/create" {
  policy = "write"
}

path "auth/token/renew-self" {
  policy = "write"
}
EOF

pwarning "$0 > Writing Vault cycloid policy"
cat << EOF | kubectl -n $NAMESPACE exec -i cycloid-vault-0 -- vault policy write cycloid -
path "cycloid/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policy/cycloid/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/approle/role/cycloid-*" {
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
kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault read auth/approle/role/cycloid >/dev/null 2>&1
VAULT_CYCLOID_APPROLE_STATUS=$?
set -e
pwarning "$0 > Creating Vault cycloid approle role"
if [ $VAULT_CYCLOID_APPROLE_STATUS -eq 2 ]; then
  kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault write auth/approle/role/cycloid token_max_ttl=1h policies=cycloid token_ttl=20m
  kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault read auth/approle/role/cycloid/role-id -format=json | tee "$OUTPUT_DIR/cycloid-role-id.json"
  pinfo "# ... Save this value as the cycloid role-id"
  kubectl -n $NAMESPACE  exec -t -i cycloid-vault-0 -- vault write -f auth/approle/role/cycloid/secret-id -format=json | tee "$OUTPUT_DIR/cycloid-secret-id.json"
  pinfo "# ... Save this value as the cycloid secret-id"
  psuccess "# /!\\ /!\\ Please make sure to backup values.custom.yaml file and the following directory $OUTPUT_DIR"
else
  perror "$0 > Vault cycloid approle role already exists"
fi

set +e
kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault read auth/approle/role/cycloid-ro >/dev/null 2>&1
VAULT_CYCLOID_APPROLE_STATUS=$?
set -e
pwarning "$0 > Creating Vault cycloid-ro approle role"
if [ $VAULT_CYCLOID_APPROLE_STATUS -eq 2 ]; then
  kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault write auth/approle/role/cycloid-ro period=30m token_max_ttl=0m policies=cycloid-ro token_ttl=30m
  kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault read auth/approle/role/cycloid-ro/role-id -format=json | tee "$OUTPUT_DIR/cycloid-ro-role-id.json"
  pinfo "# ...Save this value as the cycloid-ro role-id"
  kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault write -f auth/approle/role/cycloid-ro/secret-id -format=json | tee "$OUTPUT_DIR/cycloid-ro-secret-id.json"
  pinfo "# ... Save this value as the cycloid-ro secret-id"
  psuccess "# /!\\ /!\\ Please make sure to backup values.custom.yaml file and the following directory $OUTPUT_DIR"
else
  perror "$0 > Vault cycloid-ro approle role already exists"
fi

pwarning "$0 > Vault configured for Cycloid"
