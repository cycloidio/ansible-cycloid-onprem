#!/usr/bin/env sh

DIR="$(dirname $(readlink -f $0))"
OUTPUT_DIR="$DIR/.out"

command -v jq >/dev/null
JQ_STATUS=$?

set -e

echo "\e[36m# $0 > Vault login\e[0m"
echo ">> Using initial root token"
if [ $JQ_STATUS -eq 0 ] && [ -f "$OUTPUT_DIR/vault-init.json" ]; then
  kubectl exec -t -i cycloid-vault-0 -- vault login $(cat "$OUTPUT_DIR/vault-init.json" | jq -r '.root_token')
else
  kubectl exec -t -i cycloid-vault-0 -- vault login
fi

set +e
kubectl exec -t -i cycloid-vault-0 -- vault auth list | grep approle >/dev/null
VAULT_APPROLE_STATUS=$?
set -e
echo "\e[36m# $0 > Enabling Vault approle auth backend\e[0m"
if [ $VAULT_APPROLE_STATUS -ne 0 ]; then
  kubectl exec -t -i cycloid-vault-0 -- vault auth enable approle
else
  echo -e "\e[33m# $0 > Vault approle auth backend already enabled\e[0m"
fi

set +e
kubectl exec -t -i cycloid-vault-0 -- vault secrets list | grep cycloid  >/dev/null
VAULT_CYCLOID_KV_STATUS=$?
set -e
echo "\e[36m# $0 > Enabling Vault cycloid kv secrets backend\e[0m"
if [ $VAULT_CYCLOID_KV_STATUS -ne 0 ]; then
  kubectl exec -t -i cycloid-vault-0 -- vault secrets enable -path cycloid kv
else
  echo -e "\e[33m# $0 > Vault cycloid kv secrets backend already enabled\e[0m"
fi

echo "\e[36m# $0 > Writing Vault cycloid-ro policy\e[0m"
cat << EOF | kubectl exec -i cycloid-vault-0 -- vault policy write cycloid-ro -
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

echo "\e[36m# $0 > Writing Vault cycloid policy\e[0m"
cat << EOF | kubectl exec -i cycloid-vault-0 -- vault policy write cycloid -
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
kubectl exec -t -i cycloid-vault-0 -- vault read auth/approle/role/cycloid >/dev/null 2>&1
VAULT_CYCLOID_APPROLE_STATUS=$?
set -e
echo "\e[36m# $0 > Creating Vault cycloid approle role\e[0m"
if [ $VAULT_CYCLOID_APPROLE_STATUS -eq 2 ]; then
  kubectl exec -t -i cycloid-vault-0 -- vault write auth/approle/role/cycloid token_max_ttl=1h policies=cycloid token_ttl=20m
  kubectl exec -t -i cycloid-vault-0 -- vault read auth/approle/role/cycloid/role-id -format=json | tee "$OUTPUT_DIR/cycloid-role-id.json"
  echo -e "\e[33m^^^ Save this value as the cycloid role-id, you will need it ^^^\e[0m"
  kubectl exec -t -i cycloid-vault-0 -- vault write -f auth/approle/role/cycloid/secret-id -format=json | tee "$OUTPUT_DIR/cycloid-secret-id.json"
  echo -e "\e[33m^^^ Save this value as the cycloid secret-id, you will need it ^^^\e[0m"
else
  echo "\e[33m# $0 > Vault cycloid approle role already exists\e[0m"
fi

set +e
kubectl exec -t -i cycloid-vault-0 -- vault read auth/approle/role/cycloid-ro >/dev/null 2>&1
VAULT_CYCLOID_APPROLE_STATUS=$?
set -e
echo "\e[36m# $0 > Creating Vault cycloid-ro approle role\e[0m"
if [ $VAULT_CYCLOID_APPROLE_STATUS -eq 2 ]; then
  kubectl exec -t -i cycloid-vault-0 -- vault write auth/approle/role/cycloid-ro period=30m token_max_ttl=0m policies=cycloid-ro token_ttl=30m
  kubectl exec -t -i cycloid-vault-0 -- vault read auth/approle/role/cycloid-ro/role-id -format=json | tee "$OUTPUT_DIR/cycloid-ro-role-id.json"
  echo -e "\e[33m^^^ Save this value as the cycloid-ro role-id, you will need it ^^^\e[0m"
  kubectl exec -t -i cycloid-vault-0 -- vault write -f auth/approle/role/cycloid-ro/secret-id -format=json | tee "$OUTPUT_DIR/cycloid-ro-secret-id.json"
  echo -e "\e[33m^^^ Save this value as the cycloid-ro secret-id, you will need it ^^^\e[0m"
else
  echo "\e[33m# $0 > Vault cycloid-ro approle role already exists\e[0m"
fi

echo -e "\e[32m# $0 > Vault configured for Cycloid\e[0m"
