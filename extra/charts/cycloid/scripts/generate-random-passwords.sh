#!/usr/bin/env sh
set -x
DIR="$(dirname $(readlink -f $0))"
OUTPUT_DIR="$DIR/.out"

source $DIR/cecho-utils.sh

[ ! -d $OUTPUT_DIR ] && mkdir $OUTPUT_DIR

VALUES_CUSTOM_YAML=./values.custom.yaml

PATTERNS="
##backend-cryptoSigningKey##
##concourse-password##
##mysql-auth-rootPassword##
##mysql-auth-password##
##redis-auth-password##
##concourse-postgresql-auth-postgresPassword##
##concourse-postgresql-auth-password##
"

set +x
if [ ! -f "$VALUES_CUSTOM_YAML" ]; then
    perror "$0 > $VALUES_CUSTOM_YAML file not found"
else
    psuccess "$0 > $VALUES_CUSTOM_YAML successfully found"
fi

injectKey () {
    pinfo "  ... Replacing $pattern"
    key_file=$1
    pattern=$2
    content=$(sed 's/^/      /' $key_file)
    
    sed -i -e "/$pattern/{
        r /dev/stdin
        d
    }" $VALUES_CUSTOM_YAML <<< "$content"
}

pwarning "$0 > Generate and replace passwords"
for pattern in $PATTERNS; do
    password="$(< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c32)"
    pinfo "  ... Replacing $pattern"
    sed -i "s/$pattern/$password/g" $VALUES_CUSTOM_YAML
done

pwarning "$0 > Generate keys using ssh-keygen"

test -f $OUTPUT_DIR/concourse_session_signing_key || ssh-keygen -C '' -N '' -t rsa -b 4096 -m PEM -f $OUTPUT_DIR/concourse_session_signing_key
test -f $OUTPUT_DIR/concourse_tsa_host_key || ssh-keygen -C '' -N '' -t rsa -b 4096 -m PEM -f $OUTPUT_DIR/concourse_tsa_host_key
test -f $OUTPUT_DIR/concourse_worker_key || ssh-keygen -C '' -N '' -t rsa -b 4096 -m PEM -f $OUTPUT_DIR/concourse_worker_key

injectKey "$OUTPUT_DIR/concourse_session_signing_key" "##concourse-secrets-sessionSigningKey##"
injectKey "$OUTPUT_DIR/concourse_tsa_host_key" "##concourse-secrets-hostKey##"
injectKey "$OUTPUT_DIR/concourse_tsa_host_key.pub" "##concourse-secrets-hostKeyPub##"
injectKey "$OUTPUT_DIR/concourse_worker_key" "##concourse-secrets-workerKey##"
injectKey "$OUTPUT_DIR/concourse_worker_key.pub" "##concourse-secrets-workerKeyPub##"
