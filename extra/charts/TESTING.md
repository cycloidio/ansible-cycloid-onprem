# Chart testing

You can test the chart locally using [kind](https://kind.sigs.k8s.io/).

## Create cluster

```
kind create cluster --config kind-config.yaml
```

## Setup NGINX Ingress Controller

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

source: https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx

## Delete cluster

```
kind delete cluster --name cycloid-onprem-helm-chart-testing
```
