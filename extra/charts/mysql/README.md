# MySQL chart

Deploys a standalone MySQL.
Based on the [bitnami chart](https://github.com/bitnami/charts/blob/mysql/13.0.2/bitnami/mysql/Chart.yaml
)

## Release

```bash
bash scripts/push.sh
```

## Validate

```bash
helm repo add cycloid-mysql https://cycloid-onprem-helm-charts.s3.amazonaws.com/stable/mysql/ --force-update
helm search repo cycloid-mysql/mysql
```
