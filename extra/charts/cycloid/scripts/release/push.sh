#!/usr/bin/env bash

set -e

export AWS_ACCESS_KEY_ID=$(vault read -field=access_key secret/cycloid/aws)
export AWS_SECRET_ACCESS_KEY=$(vault read -field=secret_key secret/cycloid/aws)
export AWS_DEFAULT_REGION=eu-west-1

echo -e "\e[36m# $0 > switching to master brabnch and make sure it's up-to-date\e[0m"
# git checkout master && git pull --rebase=merges
git checkout master && git pull --rebase=true

VERSION=$(changie latest)

echo -e "\e[36m# $0 > preparing the helm dependencies for the packaging process\e[0m"
# helm dep build requires to add the repository first
helm dep list | tail -n+2 | head -n-1 | awk '{print $1","$3}' | while read repo; do helm repo add ${repo%%,*} ${repo##*,}; done < /dev/stdin
helm dependency build

echo -e "\e[36m# $0 > packaging the local helm chart\e[0m"
helm package .

echo -e "\e[36m# $0 > making sure the S3 helm repo is added locally\e[0m"
helm repo add cycloid-onprem s3://cycloid-onprem-helm-charts/stable/cycloid/ --force-update

echo -e "\e[36m# $0 > copy changelog on s3\e[0m"
aws s3 cp CHANGELOG.md s3://cycloid-onprem-helm-charts/stable/cycloid/

echo -e "\e[36m# $0 > pushing the helm package to the S3 helm repo\e[0m"
helm s3 push ./cycloid-$VERSION.tgz cycloid-onprem --relative

echo -e "\e[36m# $0 > removing the package locally\e[0m"
rm -f ./cycloid-$VERSION.tgz

echo -e "\e[36m# $0 > searching the S3 helm repo to make sure the package has been pushed and indexed\e[0m"
helm search repo cycloid-onprem
