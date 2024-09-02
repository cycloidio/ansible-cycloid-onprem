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

kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault status
VAULT_SEAL_STATUS=$?

set -e

if [ $VAULT_SEAL_STATUS -eq 2 ]; then
  pwarning "$0 > Unsealing Vault"
  echo ">> Key 1"
  if [ $JQ_STATUS -eq 0 ] && [ -f "$OUTPUT_DIR/vault-init.json" ]; then
    kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault operator unseal $(cat "$OUTPUT_DIR/vault-init.json" | jq -r '.unseal_keys_b64[0]')
  else
    kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault operator unseal
  fi
  echo ">> Key 2"
  if [ $JQ_STATUS -eq 0 ] && [ -f "$OUTPUT_DIR/vault-init.json" ]; then
    kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault operator unseal $(cat "$OUTPUT_DIR/vault-init.json" | jq -r '.unseal_keys_b64[1]')
  else
    kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault operator unseal
  fi
  echo ">> Key 3"
  if [ $JQ_STATUS -eq 0 ] && [ -f "$OUTPUT_DIR/vault-init.json" ]; then
    kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault operator unseal $(cat "$OUTPUT_DIR/vault-init.json" | jq -r '.unseal_keys_b64[2]')
  else
    kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault operator unseal
  fi
  psuccess "$0 > Vault unsealed"
elif [ $VAULT_SEAL_STATUS -eq 0 ]; then
  pinfo "$0 > Vault already unsealed"
else
  perror "$0 > ERROR: something is wrong with Vault" >&2
fi
