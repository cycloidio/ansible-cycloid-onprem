#!/usr/bin/env bash

set -ex

export AWS_ACCESS_KEY_ID=$(vault read -field=access_key secret/cycloid/aws/access-keys/cycloid)
export AWS_SECRET_ACCESS_KEY=$(vault read -field=secret_key secret/cycloid/aws/access-keys/cycloid)
export AWS_DEFAULT_REGION=eu-west-1

VERSION=$(grep version: Chart.yaml | awk '{print $2}')

echo -e "\e[36m# $0 > packaging the local helm chart\e[0m"
helm package .

echo -e "\e[36m# $0 > making sure the S3 helm repo is added locally\e[0m"
helm repo add cycloid-mysql s3://cycloid-onprem-helm-charts/stable/mysql/ --force-update

echo -e "\e[36m# $0 > pushing the helm package to the S3 helm repo\e[0m"
helm s3 push --force ./mysql-$VERSION.tgz cycloid-mysql --relative

echo -e "\e[36m# $0 > removing the package locally\e[0m"
rm -f ./mysql-$VERSION.tgz

echo -e "\e[36m# $0 > searching the S3 helm repo to make sure the package has been pushed and indexed\e[0m"
helm repo add cycloid-mysql https://cycloid-onprem-helm-charts.s3.amazonaws.com/stable/mysql/ --force-update
helm search repo cycloid-mysql/mysql