#!/usr/bin/env sh

DIR="$(dirname $(readlink -f $0))"
OUTPUT_DIR="$DIR/.out"

command -v jq >/dev/null
JQ_STATUS=$?

kubectl exec -t -i cycloid-vault-0 -- vault status
VAULT_SEAL_STATUS=$?

set -e

if [ $VAULT_SEAL_STATUS -eq 2 ]; then
  echo -e "\e[36m# $0 > Unsealing Vault\e[0m"
  echo ">> Key 1"
  if [ $JQ_STATUS -eq 0 ] && [ -f "$OUTPUT_DIR/vault-init.json" ]; then
    kubectl exec -t -i cycloid-vault-0 -- vault operator unseal $(cat "$OUTPUT_DIR/vault-init.json" | jq -r '.unseal_keys_b64[0]')
  else
    kubectl exec -t -i cycloid-vault-0 -- vault operator unseal
  fi
  echo ">> Key 2"
  if [ $JQ_STATUS -eq 0 ] && [ -f "$OUTPUT_DIR/vault-init.json" ]; then
    kubectl exec -t -i cycloid-vault-0 -- vault operator unseal $(cat "$OUTPUT_DIR/vault-init.json" | jq -r '.unseal_keys_b64[1]')
  else
    kubectl exec -t -i cycloid-vault-0 -- vault operator unseal
  fi
  echo ">> Key 3"
  if [ $JQ_STATUS -eq 0 ] && [ -f "$OUTPUT_DIR/vault-init.json" ]; then
    kubectl exec -t -i cycloid-vault-0 -- vault operator unseal $(cat "$OUTPUT_DIR/vault-init.json" | jq -r '.unseal_keys_b64[2]')
  else
    kubectl exec -t -i cycloid-vault-0 -- vault operator unseal
  fi
  echo -e "\e[32m# $0 > Vault unsealed\e[0m"
elif [ $VAULT_SEAL_STATUS -eq 0 ]; then
  echo -e "\e[33m# $0 > Vault already unsealed\e[0m"
else
  echo -e "\e[31m# $0 > ERROR: something is wrong with Vault\e[0m" >&2
fi
