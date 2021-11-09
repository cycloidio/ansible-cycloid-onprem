#!/usr/bin/env bash

set -e

[[ $# -ge 1 ]] || (echo -e "\e[33mUSAGE: $0 <version>" && exit 2)

VERSION=${1}
BRANCH="helm-version_$VERSION"

echo -e "\e[36m# $0 > switching to master branch and make it's up-to-date\e[0m"
git checkout master && git pull --rebase=preserve

echo -e "\e[36m# $0 > creating $BRANCH PR branch\e[0m"
git checkout -b $BRANCH

echo -e "\e[36m# $0 > batching all unreleases changes into a version\e[0m"
changie batch $VERSION

echo -e "\e[36m# $0 > merging it into the parent changelog\e[0m"
changie merge
# changie replacement in Chart.yaml doesn't seem to work well with the ^
# @see https://github.com/miniscruff/changie/discussions/179
sed -i "s/^version: .*/version: $VERSION/" Chart.yaml

echo -e "\e[36m# $0 > committing the changed files\e[0m"
git add Chart.yaml CHANGELOG.md changes/
git commit -m "helm: release $VERSION" Chart.yaml CHANGELOG.md changes/

echo -e "\e[36m# $0 > pushing the $BRANCH PR branch\e[0m"
git push --set-upstream origin $BRANCH

echo -e "\e[36m# $0 > opening Github PR creation WebUI in your browser\e[0m"
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

