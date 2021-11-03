# Cycloid helm chart

## Requirements

- Kubernetes cluster version: `>= 1.18.0 <= 1.22.0`.
- Make sure your `kubectl` context is targeting the intended namespace for the Cycloid setup.
- A working Ingress Controller installed within the cluster to access the Cycloid Console.
- Working DNS records for the Console and API domains you intend to use.

## Installation

### Setup the required secret in order to be allowed to pull Cycloid docker images
```
# Configure your AWS CLI with the Cycloid provided AWS credentials
aws --profile cycloid-onprem configure

# create the secret
kubectl create secret docker-registry cycloid-ecr \
    --docker-server=661913936052.dkr.ecr.eu-west-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password=$(aws --profile cycloid-onprem ecr get-login-password)
```

### Make a copy of the default chart values
```
cp -a values.yaml values.custom.yaml
```

### Install Vault first
```
helm dependency update

helm install \
    --values values.custom.yaml \
    --set frontend.enabled=false \
    --set backend.enabled=false \
    --set mysql.enabled=false \
    --set redis.enabled=false \
    --set concourse.enabled=false \
    cycloid .
```

### Init Vault
```
./scripts/vault-init.sh
```

### Unseal Vault

You will need to enter 3 Vault Unseal Keys that have been created in the `Init Vault` step, and saved for your convinence in `scripts/.out/vault-init.json`.
```
./scripts/vault-unseal.sh
```

### Configure Vault
You will need to enter the initial root token that have been created in the `Init Vault` step, and saved for your convinence in `scripts/.out/vault-init.json`.
```
./scripts/vault-config.sh
```

### Configuration

Replace all iterations of the `##cycloid-vault-approle-role-id##` with the Cycloid Approle client ID in the `Configure Vault` step.
For you convenience, you can use the following command:
```
sed -i "s/##cycloid-vault-approle-role-id##/$(cat ./scripts/.out/cycloid-role-id.json | jq -r '.data.role_id')/g" values.custom.yaml
```

Replace all iterations of the `##cycloid-vault-approle-secret-id##` with the Cycloid Approle secret ID in the `Configure Vault` step.
For you convenience, you can use the following command:
```
sed -i "s/##cycloid-vault-approle-secret-id##/$(cat ./scripts/.out/cycloid-secret-id.json | jq -r '.data.secret_id')/g" values.custom.yaml
```

Replace all iterations of the `##cycloid-ro-vault-approle-role-id##` with the Cycloid Approle secret ID in the `Configure Vault` step.
For you convenience, you can use the following command:
```
sed -i "s/##cycloid-ro-vault-approle-role-id##/$(cat ./scripts/.out/cycloid-ro-role-id.json | jq -r '.data.role_id')/g" values.custom.yaml
```

Replace all iterations of the `##cycloid-ro-vault-approle-secret-id##` with the Cycloid Approle secret ID in the `Configure Vault` step.
For you convenience, you can use the following command:
```
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

Check the `values.custom.yaml` file for additional configuration that you might want to take a look at, like enabling Ingress access to Concourse and Vault UI or setup your TLS secrets to enable HTTPS.

### Install the rest of the Cycloid setup
```
helm upgrade --values values.custom.yaml cycloid .
```

### Setup the initial Cycloid Console user and organization

- Connect to the Cycloid Console using the URL you've configured in the `values.custom.yml` file (the default one being [console.cycloid.local](http://console.cycloid.local))
- Create the first user (an activation email will be send via the configured SMTP server)
- Create the first and root organization

## Upgrades

### Upgrading the Cycloid Console versions

You can use newer Cycloid Console frontend and API versions by changing the following `tag` parameters in your `values.custom.yaml` file:
- `frontend.image.tag`
- `backend.image.tag`

Then upgrade your deployed helm release with the following:
```
helm upgrade --values values.custom.yaml cycloid .
```
