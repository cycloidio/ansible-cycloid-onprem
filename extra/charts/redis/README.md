# Redis chart

Simple chart to deploy a standalone redis

## Release

```bash
bash scripts/push.sh
```

## Validate

```bash
helm repo add cycloid-redis https://cycloid-onprem-helm-charts.s3.amazonaws.com/stable/redis/ --force-update
helm search repo cycloid-redis/redis
```
