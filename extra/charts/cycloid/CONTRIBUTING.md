# Contributing

## Requirements

* Install Changie: https://changie.dev/guide/installation/
* Install Helm v3: https://helm.sh/docs/intro/install/
* Install the helm-s3 plugin: `helm plugin install https://github.com/hypnoglow/helm-s3.git`

## HOWTO add a change file

Try to add a change file to the unreleased pool for every distinct changes you have done.

The following command will prompt you for several information and generate a change file for you:
```bash
changie new
git add .
git commit -p
git push
```

The unreleased pool of changes will be used to generate the `CHANGELOG.md` when cutting a new release.

## HOWTO add a new release

Update the version
```bash
vim Chart.yaml
# commit/push on master ?
```

Open a PR preparing the version bump:
```bash
# check the current version
NEW_VERSION=$(grep ^version: Chart.yaml | awk '{print $2}')

./scripts/release/prepare.sh $NEW_VERSION

# Check the changes
git show
```

If you have newline issue on `CHANGELOG.md` (missing newline before `##`)
```bash
sed -i  -E 's/(## [0-9].*)/\n\n\1/' CHANGELOG.md

# rebase + push --force
```

If not already done, create a PR from the `helm-version_xxx` branch in order to merge the `CHANGELOG.md` update

Push the release to the S3 helm repository
```bash
./scripts/release/push.sh
```

If the s3 push fail (example `Error: plugin "s3" exited with error`)
A docker image can be used

```bash
echo "export AWS_ACCESS_KEY_ID=$(vault read -field=access_key secret/cycloid/aws)" > /tmp/awslogin
echo "export AWS_SECRET_ACCESS_KEY=$(vault read -field=secret_key secret/cycloid/aws)" >> /tmp/awslogin
echo "export AWS_DEFAULT_REGION=eu-west-1" >> /tmp/awslogin

sudo docker run -v $(pwd):/opt/ -v /tmp/awslogin:/tmp/awslogin -it --entrypoint sh  hypnoglow/helm-s3:commit.f2dded8-helm3.13

# from the docker image
cd /opt/
# /tmp/awslogin container AWS creds
source /tmp/awslogin
helm repo add cycloid-onprem s3://cycloid-onprem-helm-charts/stable/cycloid/
VERSION=$(grep ^version: Chart.yaml | awk '{print $2}')
helm s3 push ./cycloid-$VERSION.tgz cycloid-onprem --relative
helm search repo cycloid-onprem
```

`--relative` is used to push https:// url instead of s3:// in the index
If s3:// url have been pushed, please reindex it:
`helm s3 reindex cycloid-onprem --relative`

### Update the external local charts (if Chart.yaml updated)

If you updated a chart dependency version, you need to update charts/ and Chart.lock with the following commands

```bash
rm charts/* Chart.lock -rf
helm dep list | tail -n+2 | head -n-1 | awk '{print $1","$3}' | while read repo; do helm repo add ${repo%%,*} ${repo##*,}; done < /dev/stdin
helm dependency build
cd charts
for i in $(ls *.tgz);do tar zxf $i;done ; rm *.tgz
cd -
```

## Update cycloid-intercept script

If the cycloid-intercept has been updated, make sure to push the latest version on the public s3 bucket

```bash
export AWS_ACCESS_KEY_ID=$(vault read -field=access_key secret/cycloid/aws)
export AWS_SECRET_ACCESS_KEY=$(vault read -field=secret_key secret/cycloid/aws)
export AWS_DEFAULT_REGION=eu-west-1

aws s3 cp ../../../files/scripts/cycloid-intercept.sh s3://cycloid-onprem-helm-charts/

```
