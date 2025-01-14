#! /usr/bin/env sh

set -eu

for script in *.sh; do
  echo "info: checking script '$script'"
  shellcheck -x "$script"
done
