#!/usr/bin/env sh
set -x
DIR="$(dirname $(readlink -f $0))"
OUTPUT_DIR="$DIR/.out"

VALUES_CUSTOM_YAML=./values.custom.yaml

source $DIR/cecho-utils.sh

[ ! -d $OUTPUT_DIR ] && mkdir $OUTPUT_DIR

if [ -z "$NAMESPACE" ]
then
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

kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault operator init -status
VAULT_INIT_STATUS=$?

set -e

if [ $VAULT_INIT_STATUS -eq 2 ]; then
  pwarning "$0 > Initializing Vault"
  kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault operator init -format=json | tee "$OUTPUT_DIR/vault-init.json"

  pinfo "  ... Writing generated approles into $VALUES_CUSTOM_YAML"
  sed -i "s/##cycloid-vault-approle-role-id##/$(cat $OUTPUT_DIR/cycloid-role-id.json | jq -r '.data.role_id')/g" $VALUES_CUSTOM_YAML
  sed -i "s/##cycloid-vault-approle-secret-id##/$(cat $OUTPUT_DIR/cycloid-secret-id.json | jq -r '.data.secret_id')/g" $VALUES_CUSTOM_YAML
  sed -i "s/##cycloid-ro-vault-approle-role-id##/$(cat $OUTPUT_DIR/cycloid-ro-role-id.json | jq -r '.data.role_id')/g" $VALUES_CUSTOM_YAML
  sed -i "s/##cycloid-ro-vault-approle-secret-id##/$(cat $OUTPUT_DIR/cycloid-ro-secret-id.json | jq -r '.data.secret_id')/g" $VALUES_CUSTOM_YAML

  psuccess "# /!\\ /!\\ Please make sure to backup values.custom.yaml file and the following directory $OUTPUT_DIR"
  pinfo "$0 > Vault initialized"
elif [ $VAULT_INIT_STATUS -eq 0 ]; then
  perror "$0 > Vault already initialized"
else
  perror "$0 > ERROR: something is wrong with Vault" >&2
fi
