# Chart testing

You can test the chart locally using [kind](https://kind.sigs.k8s.io/).

## Create cluster and namespace

```bash
kind create cluster --config kind-config.yaml
kubectl create namespace cycloid
```

## Setup NGINX Ingress Controller

```bash
wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
sed -i 's/allow-snippet-annotations: "false"/allow-snippet-annotations: "true"/' deploy.yaml
kubectl apply -f deploy.yaml
```

source: https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx

## Installing the local helm chart

For more details regarding the helm instalatiion, check our [doc pages](https://docs.cycloid.io/onprem/k8s.html#installation).

1. Install the helm charts dependecies

```bash
helm dependency update
```

2. Create the regitry-secret secret. Note! the name of the secret should be the same as the one in the helm variable [imagePullSecrets](values.yaml).

```bash
export SCW_SECRET_KEY=...
kubectl -n cycloid create secret docker-registry registry-secret --docker-server=rg.fr-par.scw.cloud --docker-username=nologin --docker-password=$SCW_SECRET_KEY
```

3. Install Mailhog

```bash
helm repo add codecentric https://codecentric.github.io/helm-charts
helm -n cycloid install mailhog codecentric/mailhog
```

3. Setup Vault first

```bash
helm install -n ${NAMESPACE} \
    --values values.custom.yaml \
    --set frontend.enabled=false \
    --set backend.enabled=false \
    --set mysql.enabled=false \
    --set redis.enabled=false \
    --set concourse.enabled=false \
    cycloid .
bash ./scripts/vault-init.sh
bash ./scripts/vault-unseal.sh
bash ./scripts/vault-config.sh
```

4. Chart configuration

```bash
sed -i 's/# EMAIL_DEV_MODE: false/EMAIL_DEV_MODE: true/' values.yaml
sed -i 's/EMAIL_SMTP_SVR_ADDR: "##smtp-host:smtp-port##"/EMAIL_SMTP_SVR_ADDR: "mailhog:1025"/' values.yaml
sed -i "s/##cycloid-vault-approle-role-id##/$(cat scripts/.out/cycloid-role-id.json | jq -r '.data.role_id')/g" values.yaml
sed -i "s/##cycloid-vault-approle-secret-id##/$(cat scripts/.out/cycloid-secret-id.json | jq -r '.data.secret_id')/g" values.yaml
sed -i "s/##cycloid-ro-vault-approle-role-id##/$(cat scripts/.out/cycloid-ro-role-id.json | jq -r '.data.role_id')/g" values.yaml
sed -i "s/##cycloid-ro-vault-approle-secret-id##/$(cat scripts/.out/cycloid-ro-secret-id.json | jq -r '.data.secret_id')/g" values.yaml
```

5. Install the rest of the helm chart

```bash
helm upgrade -n cycloid --values values.custom.yaml cycloid .
```

## Testing the local helm chart

To test an application, you can add an entry in your `/etc/hosts` file using the IP of the control-plane node where the ingress controller is installed.

Get the IP of the node:
```bash
kubectl get nodes -l ingress-ready=true -o wide
```

Add the following in your `/etc/hosts`:
```
<IP> api.cycloid.local console.cycloid.local
```

To do the initial setup of cycloid console

1. Connect to the Cycloid Console using the URL you've configured in the values.custom.yml file (the default one being console.cycloid.local (opens new window)).
2. Create the first user (an activation email will be send via the configured SMTP server). Validate the email using `./scripts/mysql-force-user-email-validation.sh`
4. Create the first and root organization.

## Delete cluster

```bash
kind delete cluster --name cycloid-onprem-helm-chart-testing
```
