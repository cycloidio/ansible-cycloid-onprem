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
| `Cycloid frontend` | `3000`                                  |
| `Cycloid api`      | `3001`                                  |
| `Cycloid db `      | `3306`                                  |
| `Nginx proxy`      | HTTP `80`, HTTPS `443`                  |
| `Min IO`           | HTTP `9000`                             |

Role Variables
==============

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


Installation
============

Requirements
------------

>Note: Before running ansible playbook, ensure virtualenv, pip and dependencies are satisfied on your system.

Debian
```
apt-get install python-setuptools git
apt-get install build-essential libssl-dev libffi-dev python-dev
```

RHEL
```
yum install git gcc libffi-devel python-devel openssl-devel
```

Install virtualenv
```
sudo easy_install pip
sudo pip install virtualenv
```


Common tasks
------------

All playbooks sample and requirements are located under the `playbooks` directory. To start we will create a working directory then copy the files we will use in it.

```
git clone git@github.com:cycloidio/ansible-cycloid-onprem.git
mkdir cycloid-onprem
cd cycloid-onprem
cp -r ../ansible-cycloid-onprem/playbooks/* .
```

Install ansible and required python library using virtualenv

```
virtualenv --clear .env
source .env/bin/activate
pip install ansible==2.8.* docker-py passlib bcrypt
```

Cycloid docker images are stored into an Amazon ECR, you will need to export Amazon access key for the playbook.

```
export AWS_SECRET_ACCESS_KEY=...
export AWS_ACCESS_KEY_ID=...
```

Generate a ssh keypair which will be used to configure Cycloid pipeline engine based on Concourse.

```
mkdir keys
ssh-keygen -t rsa -b 2048 -N '' -C '' -f keys/id_rsa
```


Cycloid core installation
-------------------------

Download required ansible roles to setup Cycloid core

```
ansible-galaxy install -r requirements.yml --roles-path=roles -v
```

Create an Ansible inventory file with the server ip (here `1.2.3.4`) on which install Cycloid.

```
cat >> inventory <<EOF
[cycloid]
1.2.3.4

# Meta groups to setup all in one
[cycloid_core:children]
cycloid
[cycloid_scheduler:children]
cycloid
[cycloid_scheduler_db:children]
cycloid
[cycloid_cache:children]
cycloid
[cycloid_db:children]
cycloid
[cycloid_creds:children]
cycloid
[minio:children]
cycloid
[smtp_server:children]
cycloid

EOF
```

Let's configure the environment.

```
cat >> environments/cycloid.yml <<EOF
# Resolvable domain name from the instance and externally to use Cycloid console.
cycloid_console_dns: console.mydomain.org

# Initial Cycloid user
cycloid_initial_user:
  username: "admin"
  email: "disabled@no-email.cycloid"
  password: "Ch4ngm3pls"
  given_name: admin
  family_name: cycloid

# Pipeline engine, server configuration.
concourse_session_signing_key: "{{lookup('file', 'keys/id_rsa')}}"
concourse_host_key: "{{lookup('file', 'keys/id_rsa')}}"
concourse_authorized_worker_keys:
  - "{{lookup('file', 'keys/id_rsa.pub')}}"

# Set random password for databses.
cycloid_db_password: "$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)"
concourse_db_password: "$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)"
EOF
```

Run Ansible to setup Cycloid core (`-c local` can be used if you run ansible directly on the server)

```
ansible-playbook -u admin -b -i inventory playbook.yml
```

This playbook at the end of the setup will create a local `vault.secret` file. Make sure you backup and secure it cause it will be the root token setup in Vault.

> Warning : If you restart the server, you might have to [unseal Vault](https://www.vaultproject.io/docs/concepts/seal/)

To make the unseal easier, the file `vault.secret` created during the setup can be used with `vault_unseal.yml` playbook that way :

```
ansible-playbook -u admin -b -i inventory vault_unseal.yml
```

>Note : Related to the implementation of onprem Admin console https://github.com/cycloidio/youdeploy/issues/158
> orgs created will require to be payed. You can use the `mysql-force-pay-orgs.yml` playbook to mark them as payed.

**Uninstall**

If the install failed and you need to clean your servers before to run it again, uninstall can be done by running the `playbook.yml` with `-e uninstall=True`.

```
ansible-playbook -u admin -b -i inventory -e uninstall=True playbook.yml
```

Storage information
-------------------

We are using Docker volumes in order to store data created by MinIO, a S3-like object storage. It's up to you to configure backup strategy for this volume, we will provide a support for most common volume [plugins](https://docs.docker.com/engine/extend/legacy_plugins/#volume-plugins).
For now, you could mount a disk on `/var/lib/docker/volumes` and backup this disk as you need.

Volumes installed by Cycloid will be tagged with `ansible.managed = true` and `cycloid.io = true`. If you want to `prune` your system or your volumes, do not forget to exclude this volumes:
```shell
$ docker volume prune --filter=label!=cycloid.io
```

Cycloid worker installation
---------------------------


Create a new host section in Ansible inventory for workers

```
echo -e "[cycloid_worker]\n4.3.2.1" >> inventory
```

Install required Ansible role to setup Cycloid worker

```
ansible-galaxy install -r worker-requirement.yml --roles-path=roles -v --force
```

From previous Cycloid core installation step, put the server IP to configure the workers

```
export SCHEDULER_API_ADDRESS=1.2.3.4
export VERSION=$(curl -sL "${SCHEDULER_API_ADDRESS}:8080/api/v1/info" | jq -r '.version')
```

Configure Ansible playbook for Cycloid workers

```
cat >> environments/cycloid.yml <<EOF
# Cycloid workers section
concourse_worker: yes
concourse_worker_name: "\$(hostname)"
concourse_service_enabled: no
concourse_worker_env:
    CONCOURSE_GARDEN_ASSETS_DIR: "{{ concourse_work_dir }}/garden_assets/"
    CONCOURSE_GARDEN_DEPOT: "{{ concourse_work_dir }}/garden_depot"
    CONCOURSE_GARDEN_LOG_LEVEL: "error"
    CONCOURSE_GARDEN_NETWORK_POOL: "10.254.0.0/16"
    CONCOURSE_GARDEN_MAX_CONTAINERS: 1024
    CONCOURSE_GARDEN_ADDITIONAL_DNS_SERVER: "1.1.1.1,1.0.0.1"
    # HTTP proxy configuration. Make sure to set the right url's into no_proxy
    # http_proxy: http://mydomain:8080
    # https_proxy: http://mydomain:8080
    # no_proxy: "localhost,127.0.0.1,$SCHEDULER_API_ADDRESS,vault-address,cycloid_api_dns-address,cycloid_console_dns-address"
concourse_worker_options: |
  --ephemeral \\
  --baggageclaim-log-level=error \\
  --baggageclaim-volumes={{ concourse_work_dir }}/baggageclaim_volumes \\
  --baggageclaim-driver=overlay 2>&1 | tee -a /var/log/concourse-worker.log ; exit \${PIPESTATUS[0]}

concourse_install_dir: /var/lib/concourse
concourse_work_dir: /var/lib/concourse/datas

concourse_version: "${VERSION}"
concourse_tsa_port: "2222"
concourse_tsa_host: "$SCHEDULER_API_ADDRESS"
concourse_tsa_public_key: "{{lookup('file', 'keys/id_rsa.pub')}}"
concourse_tsa_worker_key: "{{lookup('file', 'keys/id_rsa')}}"
EOF
```

Then run the playbook to setup Cycloid workers

```
ansible-playbook -u admin -b -i inventory worker.yml
```

Cycloid local worker
--------------------

For testing or POC purpose, instead having a dedicated worker, you can run one from your laptop with docker.

To do it You need to define few environment variables and use the `cycloid/local-worker` docker image.

```bash
export SCHEDULER_HOST="<cycloid_scheduler ip>"
export SCHEDULER_PORT="2222"
export TSA_PUBLIC_KEY="$(cat keys/id_rsa.pub)"
export TEAM_ID="<from the console ci_team_member>"
export WORKER_KEY="$(cat keys/id_rsa | base64 -w 0)"

docker run -it --rm --privileged --name cycloid-worker -e SCHEDULER_HOST=$SCHEDULER_HOST \
                                                       -e SCHEDULER_PORT=$SCHEDULER_PORT \
                                                       -e TSA_PUBLIC_KEY="$TSA_PUBLIC_KEY" \
                                                       -e TEAM_ID=$CYCLOID_WORKER_TEAM \
                                                       -e WORKER_KEY=$CYCLOID_WORKER_KEY \
                                                       cycloid/local-worker
```

* SCHEDULER_HOST: Is the url to access concourse web. By default it is your ip used in inventory `cycloid_scheduler` group
* SCHEDULER_PORT: Port used for concourse web/tsa (default `2222`)
* TSA_PUBLIC_KEY: public key used by concourse. By default generated in `keys/id_rsa.pub`
* TEAM_ID: From the web interface, go on your Organization detail view and copy the `ci_team_member`.
* WORKER_KEY: Worker key allowed on concourse TSA. By default generated in `keys/id_rsa`


Example Playbook
================

Sample of playbooks and variable file can be found under the `playbooks` directory.

Run tests
=========

This role is tested with molecule

```
virtualenv --clear .env
source .env/bin/activate
pip install molecule ansible docker-py passlib bcrypt

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

Troubleshooting / Report
========================

To solve issue on your onprem setup, a debug report can be created and sent to cycloid by running the `report.yml` playbook.
The report will connect to the servers specified in your `inventory` file and collect system/network/services information.

The report will be compressed with `tar`, encrypted with `gpg` then sent to *pastefile-owl.cycloid.io* url with `curl`. Please **make sure** `tar`, `gpg` and `curl` **installed**.

**Create a report**
```
ansible-playbook -u admin -b -i inventory report.yml
```

The last step should display a **pastefile-owl.cycloid.io url** and a **secret** to share with Cycloid team.
```
TASK [Report created, please share the following output] **********************************************************************************************************************************************************************************************************************************
ok: [localhost -> 127.0.0.1] => {
    "secret.stdout_lines": [
        "Report have been saved under /tmp/debug-2020-07-03-16:47:35.tar.gz.gpg",
        "",
        "Please share this url and secret to cycloid team: ",
        "",
        "https://pastefile-owl.cycloid.io/746f14db69b52c418c9857d295d5cb5a",
        "secret: HuxsQMc-gMaiYFA0SgwEp074-t7jTx0O"
    ]
}
```


TODO
====

  * Improve HA and offer more way to customize the setup (eg external db, external vault, persistent storage, ...)
  * Add monitoring
  * Get sysconfig from https://github.com/cycloid-community-catalog/stack-external-worker/blob/master/ansible/default.yml
  * Backups

Author Information
==================

Cycloid.io
