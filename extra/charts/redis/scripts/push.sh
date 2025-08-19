#!/usr/bin/env bash

set -e

export AWS_ACCESS_KEY_ID=$(vault read -field=access_key secret/cycloid/aws/access-keys/cycloid)
export AWS_SECRET_ACCESS_KEY=$(vault read -field=secret_key secret/cycloid/aws/access-keys/cycloid)
export AWS_DEFAULT_REGION=eu-west-1

VERSION=$(grep version: Chart.yaml | awk '{print $2}')

echo -e "\e[36m# $0 > packaging the local helm chart\e[0m"
helm package .

echo -e "\e[36m# $0 > making sure the S3 helm repo is added locally\e[0m"
helm repo add cycloid-redis s3://cycloid-onprem-helm-charts/stable/redis/ --force-update

echo -e "\e[36m# $0 > pushing the helm package to the S3 helm repo\e[0m"
helm s3 push --force ./redis-$VERSION.tgz cycloid-redis --relative

echo -e "\e[36m# $0 > removing the package locally\e[0m"
rm -f ./redis-$VERSION.tgz

echo -e "\e[36m# $0 > searching the S3 helm repo to make sure the package has been pushed and indexed\e[0m"
helm repo add cycloid-redis https://cycloid-onprem-helm-charts.s3.amazonaws.com/stable/redis/ --force-update
helm search repo cycloid-redis/redis
