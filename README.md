ansible-cycloid-onprem
======================

How to install Cycloid onprem documentation is available here : https://docs.cycloid.io/onprem/overview.html

Run tests
=========

This role is tested with molecule

```
virtualenv --clear .env
virtualenv -p python3 --clear .env
source .env/bin/activate
pip install ansible==2.9.* docker-py passlib bcrypt molecule==3.0a4 pytest==4.6.9

export AWS_SECRET_ACCESS_KEY=$(vault read -field=secret_key secret/$CUSTOMER/aws)
export AWS_ACCESS_KEY_ID=$(vault read -field=access_key secret/$CUSTOMER/aws)

molecule test

# Instead you also can run :
molecule destroy
molecule converge
molecule verify
```

You can also connect on the running container and it's nested containers :

```
docker exec -it instance bash
docker exec -e VAULT_SKIP_VERIFY=true -it vault vault read ...
```

Access to the database :

```
source  /etc/default/cycloid-api
mysql --protocol=TCP -u$MYSQL_USER -p$MYSQL_PASSWORD -h $YOUDEPLOY_MYSQL_SERVICE_HOST
```

TODO
====

  * Add monitoring
  * Get sysconfig from https://github.com/cycloid-community-catalog/stack-external-worker/blob/master/ansible/default.yml
  * Backups

Author Information
==================

Cycloid.io
