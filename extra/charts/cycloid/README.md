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

Because of that, the chart installation will be achieved in two big steps:

- Installation and/or configuration of the [Hashicorp Vault](https://www.hashicorp.com/products/vault) dependency.
- Installation of the rest of the stack

For that purpose, the Helm chart will need to be pulled locally instead of installing it directly from the Helm repository.
We will then ask you to make a copy of the default chart values to make the necessary modifications and add your custom ones.

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

You will need to enter 3 Vault Unseal Keys created in the [Initialization](#initialization) step and saved for your convenience in `scripts/.out/vault-init.json`.

If you have the [jq](https://stedolan.github.io/jq/) utility installed locally, the values will be entered automatically.

```bash
./scripts/vault-unseal.sh
```

#### Configuration

You will need to enter the initial root token created in the [Initialization](#initialization) step and saved for your convenience in `scripts/.out/vault-init.json`.

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

Change the `backend.cryptoSigningKey` parameter to something more secure than the default value as this value will be used by the backend to encrypt passwords.
For e.g., this can generated with `pwgen 32 1`.

Replace the following with your SMTP server, Cycloid will send emails during the user creation process:
- `##smtp-host:smtp-port##`
- `##smtp-username##`
- `##smtp-password##`

Replace the following domains with your desired ones:
- Console: `console.cycloid.local`
- API: `api.cycloid.local`

You will need a working Ingress Controller deployed within your Kubernetes cluster for these to work, the Ingress resources are setup to work with the NGINX Ingress Controller out of the box. You will also need to make sure the DNS records used for your customized domains are working in order to have access to the Console after the installation.

We highly suggest you to change the all the default passwords:

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

The AWS ECR password in the docker-registry secret provided by the AWS CLI will, unfortunately, expire after 12 hours.
If you are upgrading your Helm release and are experiencing `ErrImagePull` and/or `ImagePullBackOff` errors, you will have to delete the `cycloid-ecr` secret and re-create it as described [here](#setup-the-required-secret-to-access-the-cycloid-docker-images).

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

## Frequenly Asked Question

### How to expose the Concourse worker gateway port to allow external Concourse workers usage

In order for your external workers to join the Concourse server included in this chart, you will need to expose the Concourse worker gateway port.
This can be achieved in most managed Kubernetes cluster by creating a Kubernetes Service of type `LoadBalancer`.

For e.g. using the following manifest:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: cycloid-concourse-web-worker-gateway-custom
  # namespace: your-namespace
  labels:
    app: cycloid-concourse-web
spec:
  type: LoadBalancer
  ports:
  - name: worker-gateway
    port: 2222
    protocol: TCP
    targetPort: tsa
  selector:
    app: cycloid-concourse-web
```

You will then be able to use the `External IP` of this Service as your `concourse_tsa_host` parameter for your external workers which can be retried with the following command:

```bash
kubectl get service cycloid-concourse-web-worker-gateway-custom -o template --template="{{.spec.loadBalancerIP}}"
```

### How to enable console-wide concourse worker running in the Kubernetes cluster

We usually recommend using [external workers](/manage/workers/workers.md) with Cycloid by [exposing the Concourse worker gateway port](#how-to-expose-the-concourse-worker-gateway-port-to-allow-external-concourse-workers-usage) of the Concourse web server deployed with this Helm chart.

But if you are intested in running global Kubernetes Concourse workers shared across all the organizations of your setup, here are the following configuration steps to make it work.

In your `values.custom.yaml`, you should be able to see `worker` sub-section within the `concourse` block.
Changing the `enabled` field to `true` will enable the concourse worker statefulset included in the concourse sub-helm chart and deploy a number of replicas equivalent to the `replicas` field.
The resources attributed to each worker can be modified in the `worker.resources` and `persistence.worker` sub-sections.

For e.g.

```yaml
…
concourse:
  …
  worker:
    ## Enable or disable the worker component.
    ## This can allow users to create web only releases by setting this to false
    ##
    enabled: true

    ## Number of replicas.
    ##
    replicas: 2

    ## Configure resource requests and limits.
    ## Ref: https://kubernetes.io/docs/user-guide/compute-resources/
    ##
    resources:
      requests:
        cpu: "2"
        memory: "4Gi"
      limits:
        cpu: "2"
        memory: "4Gi"

    ## Node selector for the worker nodes.
    ## Ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#nodeselector
    ##
    nodeSelector:
      "kubernetes.io/os": linux

  persistence:
    enabled: true
    worker:
      ## concourse data Persistent Volume Storage Class
      ## If defined, storageClassName: <storageClass>
      ## If set to "-", storageClassName: "", which disables dynamic provisioning
      ## If undefined (the default) or set to null, no storageClassName spec is
      ##   set, choosing the default provisioner.  (gp2 on AWS, standard on
      ##   GKE, AWS & OpenStack)
      ##
      storageClass:

      ## Persistent Volume Access Mode.
      ##
      accessMode: ReadWriteOnce

      ## Persistent Volume Storage Size.
      ##
      size: 100Gi
…
```

Don't forget to upgrade your Helm release to take your changes into account:

```bash
helm upgrade -f values.custom.yaml cycloid ./cycloid
```

### Enable the Cloud Cost Management feature by using an external Elasticsearch endpoint

In order to use Cycloid Cloud Cost Management capabilities, you will need give the Cycloid Console access to an existing Elasticsearch node/cluster.
We are planning to add an Elasticsearch instance deployment option in the Helm chart in the future, but as for now using an externally deployed ElasticSearch endpoint is the only way to benefit for our Cloud Cost Management feature offering.

To enable it, search for the `externalElasticsearch` section in your `values.custom.yaml`, switch the `enabled` field to `true` and fill out the remaning fields with the information that will be used by the Cycloid Backend to connect to your ElasticSearch endpoint and make sure it will be capable to access it

This Elasticsearch endpoint needs to respect the following requirements:
- Version: up to 7.17.x
- Plugins: mapper-murmur3

A recommended way to deploy a ElasticSearch cluster in Kubernetes is to use the official [Elastic ECK Operator](https://www.elastic.co/fr/elastic-cloud-kubernetes), which can be deployed following [their documentation](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-eck.html).

The Elastic ECK Operator gives you the ability to deploy complex and full-featured Elasticsearch cluster scenarios using their custom kubernetes resource called `Elasticsearch`.
Here a very small and simple single instance Elasticsearch Kubernetes manifest, but this is merely an example for the purpose of that guide and shouldn't be taken as is.
Your Elasticsearch deployment scenario needs to be evaluated depending on how much data you are planning to ingest.

```yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: cost-explorer
  labels:
    app.kubernetes.io/name: cost-explorer
spec:
  version: 7.17.1
  nodeSets:
  - name: hot
    count: 1
    config:
      node.roles: [ data, ingest, master ]
    podTemplate:
      spec:
        initContainers:
        - name: install-plugins
          command: ['sh', '-c', 'bin/elasticsearch-plugin install mapper-murmur3']
        - name: sysctl
          securityContext:
            privileged: true
            runAsUser: 0
          command: ['sh', '-c', 'sysctl -w vm.max_map_count=262144']
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 2Gi
            limits:
              memory: 4Gi
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data # Do not change this name unless you set up a volume mount for the data path.
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 10Gi
```

You can then connect the Cycloid Console to this Elasticsearch cluster using, for e.g., the following `values.custom.yaml` Helm chart configuration:

```yaml
…
#
# External Elasticsearch Configuration
#
externalElasticsearch:
  # for now, the externalElasticsearch config will be at first
  # the only solution to configure the backend for Cloud Cost Management
  enabled: true
  #External ES server protocol
  scheme: https
  #External ES server host
  host: cost-explorer-es-http
  #External ES server port
  port: 9200
  #External ES server database
  username: elastic
  #External ES password
  password: ""
  #The name of an existing secret with database credentials
  # NOTE: Must contain key `elasticsearch-password` by default is not overriden with `existingSecretKey`
  # NOTE: When it's set, the `externalElasticsearch.password` parameter is ignored
  existingSecret: cost-explorer-es-elastic-user
  existingSecretKey: elastic
…
```

If you are using an Elasticsearch endpoint over HTTPS with custom certificates, you will need to either tell the Cycloid Backend to ignore Insecure TLS warnings with the following environment variable:

```yaml
…
backend:
  …
  extraEnvVars:
    COST_EXPLORER_ES_INSECURE_SKIP_TLS: true
…
```

or give it access to the Elasticsearch CA certificate through a Kubernetes secret with:

```yaml
…
backend:
  …
  extraSecretEnvVars:
    - envName: COST_EXPLORER_ES_CA_CERT
      secretName: cost-explorer-es-http-certs-public
      secretKey: ca.crt
…
```

Don't forget to upgrade your Helm release to take your changes into account:

```bash
helm upgrade -f values.custom.yaml cycloid ./cycloid
```
