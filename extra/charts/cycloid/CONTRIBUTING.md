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
```

The unreleased pool of changes will be used to generate the `CHANGELOG.md` when cutting a new release.

## HOWTO cut a new release

Open a PR preparing the version bump:
```bash
./scripts/release/prepare.sh
```

Push the release to the S3 helm repository:
```bash
./scripts/release/push.sh
```

