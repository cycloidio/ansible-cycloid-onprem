#!/usr/bin/env bash

set -e

[[ $# -ge 1 ]] || (echo -e "\e[33mUSAGE: $0 <version>" && exit 2)

VERSION=${1}

echo -e "\e[36m# $0 > switching to master branch and make it's up-to-date"
git checkout master && git pull --rebase=preserve

echo -e "\e[36m# $0 > creating version_$VERSION PR branch"
git checkout -b version_$VERSION

echo -e "\e[36m# $0 > batching all unreleases changes into a version"
changie batch $VERSION

echo -e "\e[36m# $0 > merging it into the parent changelog"
changie merge

echo -e "\e[36m# $0 > committing the changed files"
git commit -m "Release $VERSION" Chart.yaml CHANGELOG.md changes/

echo -e "\e[36m# $0 > pushing the version_$VERSION PR branch"
git push --set-upstream origin version_$VERSION

echo -e "\e[36m# $0 > opening Github PR creation WebUI in your browser"
set +e
OPEN_CMD=$(command -v open >/dev/null)
set -e
if [[ $OPEN_CMD -eq 0 ]]; then
  # macOS and linux alias compatibility
  open "https://github.com/cycloidio/ansible-cycloid-onprem/compare/master...version_$VERSION"
else
  # fallback on xdg-open
  xdg-open "https://github.com/cycloidio/ansible-cycloid-onprem/compare/master...version_$VERSION"
fi

