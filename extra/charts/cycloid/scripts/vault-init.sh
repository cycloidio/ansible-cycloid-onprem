#!/bin/bash
set -x
DIR="$(dirname $(readlink -f $0))"
OUTPUT_DIR="$DIR/.out"

source $DIR/cecho-utils.sh

[ ! -d $OUTPUT_DIR ] && mkdir $OUTPUT_DIR

if [ -z "$NAMESPACE" ]
then
      perror "$0 Make sure to defined export NAMESPACE="
      exit 1
fi

kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault operator init -status
VAULT_INIT_STATUS=$?

set -e

if [ $VAULT_INIT_STATUS -eq 2 ]; then
  pwarning "$0 > Initializing Vault"
  kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault operator init -format=json | tee "$OUTPUT_DIR/vault-init.json"
  psuccess "# /!\\ /!\\ Please make sure to backup values.custom.yaml file and the following directory $OUTPUT_DIR"
  pinfo "$0 > Vault initialized"
elif [ $VAULT_INIT_STATUS -eq 0 ]; then
  perror "$0 > Vault already initialized"
else
  perror "$0 > ERROR: something is wrong with Vault" >&2
fi


pwarning "$0 > Calling $DIR/vault-unseal.sh"
bash $DIR/vault-unseal.sh

pwarning "$0 > Calling $DIR/vault-config.sh"
bash $DIR/vault-config.sh
