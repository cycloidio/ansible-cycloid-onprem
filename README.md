ansible-cycloid-onprem
======================

Provide a way to setup Cycloid platforme and dependencies on one or several servers using Docker.

![Schema](https://github.com/cycloidio/ansible-cycloid-onprem/raw/master/onprem.png)

After a default run of this playbook on a server, you will find those different services :

| **Service**        | **Port**                                |
|--------------------|-----------------------------------------|
| `Concourse web`    | TSA `2222`, WEB `8080`, WEB SSL `8443`  |
| `Concourse db`     | `5432`                                  |
| `vault`            | `8200`                                  |
| `Cycloid frontend` | `8888`                                  |
| `Cycloid api`      | `3001`                                  |
| `Cycloid db `      | `3306`                                  |
| `Nginx proxy`      | HTTP `80`, HTTPS `443`                  |

Role Variables
--------------

**Timer:**

| **Variable**                        | **Description**                              | **Default**           | **Required** |
|-------------------------------------|----------------------------------------------|-----------------------|--------------|
| `concourse_db_password`             | Concourse database password                  |                       | **Yes**      |
| `concourse_session_signing_key`     | Concourse session signing key                |                       | **Yes**      |
| `concourse_host_key`                | Concourse host key                           |                       | **Yes**      |
| `concourse_authorized_worker_keys`  | Concourse authorized worker keys             |                       | **Yes**      |
| `cycloid_db_password`               | Cycloid database password                    |                       | **Yes**      |
| `cycloid_console_dns`               | Cycloid dns name to use for console vhost    |                       | **Yes**      |
| `cycloid_api_dns`                   | Cycloid dns name to use for api vhost        |                       | **Yes**      |

Example Playbook
----------------

Sample of playbooks and variable file can be found under the `playbooks` directory.

Run tests
---------

This role is tested with molecule

```
virtualenv --clear .env
source .env/bin/activate
pip install molecule ansible docker-py

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

TODO
----

  * Improve HA and offer more way to customize the setup (eg external db, external vault, persistent storage, ...)
  * Add monitoring
  * Get sysconfig from https://github.com/cycloid-community-catalog/stack-external-worker/blob/master/ansible/default.yml
  * Backups

Author Information
------------------

Cycloid.io

