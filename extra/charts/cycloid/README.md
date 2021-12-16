# Cycloid on-premises on Kubernetes

The Cycloid on-premises setup on Kubernetes provide a way to setup the Cycloid platform and dependencies within your own Kubernetes cluster.

This setup is provided as a [Helm chart](https://helm.sh/docs/topics/charts/) which is kind of the de facto standard to package applications for Kubernetes.

This chart is only accessible from a private Helm repository hosted on AWS S3.

To access and run it, you will need to get from Cycloid AWS credentials to access our Helm repository and private docker registry.

## Requirements

In order to make use of this setup, you will need the following:

* Cluster
  - Kubernetes cluster version: `>= 1.19.0`.
  - Make sure your `kubectl` context is targeting the intended cluster and namespace for the Cycloid setup.
  - A working [Kubernetes Ingress Controller](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/) installed within the cluster to access the Cycloid Console.
  - Working DNS records pointing to your Kubernetes cluster for the Console and API domains you intend to use.
* Locally
  - [Helm v3](https://helm.sh/docs/intro/install/).
  - [Helm S3 plugin](https://github.com/hypnoglow/helm-s3): `helm plugin install https://github.com/hypnoglow/helm-s3.git`.
  - [AWS CLI](https://docs.aws.amazon.com/fr_fr/cli/latest/userguide/cli-chap-install.html).
  - The [jq](https://stedolan.github.io/jq/) utility if you want to make use of the convenient script automation during the Vault configuration.

## Configure the Cycloid AWS credentials

```bash
# Configure your AWS CLI with the Cycloid provided AWS credentials
aws --profile cycloid-onprem configure

# Add required AWS ENVVARs that will be used to access the Helm repository
export AWS_PROFILE=cycloid-onprem AWS_REGION=eu-west-1
```

## Setup the required secret to access the Cycloid docker images

```bash
kubectl create secret docker-registry cycloid-ecr \
    --docker-server=661913936052.dkr.ecr.eu-west-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password=$(aws --profile cycloid-onprem ecr get-login-password)
```

## Add the Cycloid on-premises Helm repository

```bash
# Add the cycloid-onprem helm repository to helm locally
helm repo add cycloid-onprem s3://cycloid-onprem-helm-charts/stable/cycloid/

# Verify that helm can see the cycloid-onprem/cycloid chart
helm search repo cycloid
```

## Installation

The Cycloid helm chart is more complex that most of other Helm charts as it will deploy all the platform requirements and dependencies instead of a the Cycloid application itself.

Because of that the chart installation will be achieve in two big steps:

- Installation and/or configuration of the [Hashicorp Vault](https://www.hashicorp.com/products/vault) dependency.
- Installation of the rest of the stack

To achieve that, the Helm chart will need to be pull locally instead of installing it directly from the Helm repository and why we will ask you to make a copy of the default chart values to make the necessary modifications and add your custom ones.

### Pull the Cycloid on-premises Helm chart locally

```bash
# Pull the helm chart
helm pull --untar cycloid-onprem/cycloid

# or if you want to pull a specific version
helm pull --untar cycloid-onprem/cycloid --version <version>
```

### Make a copy of the default chart values

```bash
# Enter the cycloid helm chart directory pull previously
cd cycloid/

# Make a copy of the default values in order to add your modifications
cp -a values.yaml values.custom.yaml
```

### Setup Vault first

#### Installation

```bash
helm install \
    --values values.custom.yaml \
    --set frontend.enabled=false \
    --set backend.enabled=false \
    --set mysql.enabled=false \
    --set redis.enabled=false \
    --set concourse.enabled=false \
    cycloid .
```

#### Initialization

```bash
./scripts/vault-init.sh
```

We highly recommend you to make a backup of JSON files that have been generated in the `scripts/.out/` directory as they contain key informations about Vault Unseal keys, initial root tokens and required Approle used by the Cycloid platform.

#### Unsealing

You will need to enter 3 Vault Unseal Keys that have been created in the [Initialization](#initialization) step, and saved for your convinence in `scripts/.out/vault-init.json`.

If you have the [jq](https://stedolan.github.io/jq/) utility installed locally, the values will be entered automatically.

```bash
./scripts/vault-unseal.sh
```

#### Configuration

You will need to enter the initial root token that have been created in the [Initialization](#initialization) step, and saved for your convinence in `scripts/.out/vault-init.json`.

If you have the [jq](https://stedolan.github.io/jq/) utility installed locally, the values will be entered automatically.

```bash
./scripts/vault-config.sh
```

### Chart Configuration

#### Required modifications

Replace all iterations of the `##cycloid-vault-approle-role-id##` with the Cycloid Approle client ID in the [Setup Vault first](#setup-vault-first) step.

For you convenience, you can use the following command:
```bash
sed -i "s/##cycloid-vault-approle-role-id##/$(cat ./scripts/.out/cycloid-role-id.json | jq -r '.data.role_id')/g" values.custom.yaml
```

Replace all iterations of the `##cycloid-vault-approle-secret-id##` with the Cycloid Approle secret ID in the [Setup Vault first](#setup-vault-first) step.

For you convenience, you can use the following command:
```bash
sed -i "s/##cycloid-vault-approle-secret-id##/$(cat ./scripts/.out/cycloid-secret-id.json | jq -r '.data.secret_id')/g" values.custom.yaml
```

Replace all iterations of the `##cycloid-ro-vault-approle-role-id##` with the Cycloid Approle secret ID in the [Setup Vault first](#setup-vault-first) step.

For you convenience, you can use the following command:
```bash
sed -i "s/##cycloid-ro-vault-approle-role-id##/$(cat ./scripts/.out/cycloid-ro-role-id.json | jq -r '.data.role_id')/g" values.custom.yaml
```

Replace all iterations of the `##cycloid-ro-vault-approle-secret-id##` with the Cycloid Approle secret ID in the [Setup Vault first](#setup-vault-first) step.

For you convenience, you can use the following command:
```bash
sed -i "s/##cycloid-ro-vault-approle-secret-id##/$(cat ./scripts/.out/cycloid-ro-secret-id.json | jq -r '.data.secret_id')/g" values.custom.yaml
```

Replace the following with your SMTP server, Cycloid will send emails during the user creation process:
- `##smtp-host:smtp-port##`
- `##smtp-username##`
- `##smtp-password##`

Replace the following domains with your desired ones:
- Console: `console.cycloid.local`
- API: `api.cycloid.local`
You will need a working Ingress Controller deployed within your Kubernetes cluster for these to work, the Ingress resources are setup to work with the NGINX Ingress Controller out of the box. You will also need to make sure the DNS records used for your customized domains are working in order to have access to the Console after the installation.

We highly suggest you to change the default passwords:
- MySQL in `mysql.auth.rootPassword` and `mysql.auth.password` if you want to use the provided one, otherwise set `mysql.enabled` to `false` and setup the `externalMysql.*` parameters accordingly to your external MySQL.
- Redis in `redis.auth.password` if you want to use the provided one, otherwise set `redis.enabled` to `false` and setup the `externalRedis.*` parameters accordingly to your external Redis.
- PostgreSQL in `concourse.postgresql.postgresqlPassword` if you want to use the provided one, otherwise set `concourse.postgresql.enabled` to `false` and setup the following parameters accordingly to your external PostgreSQL:
  - `concourse.concourse.web.postgres.host`
  - `concourse.concourse.web.postgres.port`
  - `concourse.concourse.web.postgres.database`
  - `concourse.secrets.postgresUser`
  - `concourse.secrets.postgresPassword`
- Concourse default user in:
  - `backend.concourse.password`
  - `concourse.secrets.localUsers`
- Concourse default keys in:
  - `concourse.secrets.hostKey`
  - `concourse.secrets.hostKeyPub`
  - `concourse.secrets.sessionSigningKey`
  - `concourse.secrets.workerKey`
  - `concourse.secrets.workerKeyPub`

#### Custom modifications

Check the `values.custom.yaml` file for additional configuration that you might want to take a look at, like enabling Ingress access to Concourse and Vault UI or setup your TLS secrets to enable HTTPS.

### Install the rest of the Cycloid setup

```bash
helm upgrade --values values.custom.yaml cycloid .
```

### Setup the initial Cycloid Console user and organization

- Connect to the Cycloid Console using the URL you've configured in the `values.custom.yml` file (the default one being [console.cycloid.local](http://console.cycloid.local)).
- Create the first user (an activation email will be send via the configured SMTP server).
- Create the first and root organization.

## Upgrades

### Upgrade the Cycloid Console versions

You can use newer Cycloid Console frontend and API versions by changing the following `tag` parameters in your `values.custom.yaml` file:
- `frontend.image.tag`
- `backend.image.tag`

Then upgrade your deployed helm release with the following:

```bash
helm upgrade --values values.custom.yaml cycloid .
```

### Upgrade the Helm chart entirely

Make sure to make a backup of the `values.custom.yaml` file you have created during the first installation.

```bash
# Update the cycloid-onprem repo locally
helm repo update cycloid-onprem

# Remove the previously pulled chart if you still have it as helm won't override existing directory matching the `cycloid` chart name

# Pull the helm chart
helm pull --untar cycloid-onprem/cycloid

# or if you want to pull a specific version
helm pull --untar cycloid-onprem/cycloid --version <version>

# Restore the values.custom.yaml file to re-use your custom modifications

# Upgrade your deployed Helm release
helm upgrade -f values.custom.yaml cycloid ./cycloid
```

