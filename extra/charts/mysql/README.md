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

### Test creation

Generate a custom values file
```bash
cat <<EOF > values.custom.yaml
extraEnvVars:
  MYSQL_EXTRA_DATABASES: "plugindb managerdb"

nameOverride: "mysql"

auth:
  rootPassword: "password"
  database: cycloid
  username: cycloid
  password: "password"
EOF
```

Install from chart
```bash
NS=test
helm -n $NS repo update cycloid-mysql
helm -n $NS install --values values.custom.yaml mysql cycloid-mysql/mysql
helm -n $NS upgrade --values values.custom.yaml mysql cycloid-mysql/mysql
```

Or install from local chart
```bash
NS=test
helm -n $NS install --values values.custom.yaml mysql .
helm -n $NS upgrade --values values.custom.yaml mysql .
```