#!/usr/bin/env sh
set -x
DIR="$(dirname $(readlink -f $0))"
OUTPUT_DIR="$DIR/.out"
[ ! -d $OUTPUT_DIR ] && mkdir $OUTPUT_DIR

if [ -z "$NAMESPACE" ]
then
      echo 'Make sure to defined export NAMESPACE='
fi

kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault operator init -status
VAULT_INIT_STATUS=$?

set -e

if [ $VAULT_INIT_STATUS -eq 2 ]; then
  echo -e "\e[36m# $0 > Initializing Vault\e[0m"
  kubectl -n $NAMESPACE exec -t -i cycloid-vault-0 -- vault operator init -format=json | tee "$OUTPUT_DIR/vault-init.json"
  echo -e "\e[33m^^^ Save those values, you will need it ^^^\e[0m"
  echo -e "\e[32m# $0 > Vault initialized\e[0m"
elif [ $VAULT_INIT_STATUS -eq 0 ]; then
  echo -e "\e[33m# $0 > Vault already initialized\e[0m"
else
  echo -e "\e[31m# $0 > ERROR: something is wrong with Vault\e[0m" >&2
fi
