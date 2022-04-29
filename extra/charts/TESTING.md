# Chart testing

You can test the chart locally using [kind](https://kind.sigs.k8s.io/).

## Create cluster

```bash
kind create cluster --config kind-config.yaml
```

## Setup NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

To test an application, you can add an entry in your `/etc/hosts` file using the IP of the control-plane node where the ingress controller is installed.

Get the IP of the node:
```bash
kubectl get nodes -l ingress-ready=true -o wide
```

Add the following in your `/etc/hosts`:
```
<IP> api.cycloid.local console.cycloid.local
```


source: https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx

## Delete cluster

```bash
kind delete cluster --name cycloid-onprem-helm-chart-testing
```
