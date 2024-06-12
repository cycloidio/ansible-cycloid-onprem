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
mysql --protocol=TCP -u$DB_USER -p$DB_PWD -h $DB_HOST
```

TODO
====

  * Add monitoring
  * Get sysconfig from https://github.com/cycloid-community-catalog/stack-external-worker/blob/master/ansible/default.yml
  * Backups

Author Information
==================

Cycloid.io



# Playbook variables

## Common variables

|Name|Description|Type|Default|Required|
|---|---|:---:|:---:|:---:|
|`concourse_auth_password`|Defines the password for the Concourse CI user.|`string`|`"Ch4ngm3pls"`|`True`|
|`concourse_auth_user`|Defines the username for authenticating with Concourse CI.|`string`|`"admin"`|`True`|
|`concourse_db_host`|Specifies the hostname or IP address of the Concourse CI database server.|`string`|`""`|`True`|
|`concourse_db_name`|Defines the name of the Concourse CI database.|`string`|`"concourse"`|`False`|
|`concourse_db_password`|Defines the password for accessing the Concourse CI database.|`string`|`"Ch4ngm3pls"`|`True`|
|`concourse_db_port`|Defines the port number on which the Concourse CI database server is listening.|`string`|`"5432"`|`True`|
|`concourse_db_user`|Specifies the username for the Concourse CI database.|`string`|`"concourse"`|`True`|
|`concourse_log_level`|Sets the log level for Concourse CI.|`string`|`"info"`|`False`|
|`concourse_url`|Specifies the URL where Concourse CI can be accessed from the Cycloid API|`string`|`"https://{{ hostvars[groups['cycloid_scheduler'][0]]['ansible_default_ipv4']['address'] }}"`|`True`|
|`cost_estimation_gcp_cred_json`|GCP json credential used to reach GCP pricing datas.|`string`|`""`|`False`|
|`cost_estimation_ingestion_schedule`|Sets the schedule for CostEstimation Ingestion jobs.|`string`|`"Sun *-*-* 00:00:00"`|`False`|
|`cost_explorer_es_insecure_skip_tls`|Configures whether to ignore TLS certificate errors when connecting to Elasticsearch.|`bool`|`true`|`False`|
|`cost_explorer_es_password`|Defines the password for authenticating with the Elasticsearch service.|`string`|`"Ch4ngm3pls"`|`False`|
|`cost_explorer_es_url`|Defines the URL for connecting to the Elasticsearch service used by the Cost Explorer.|`string`|`"{{elasticsearch_schema}}://{{ hostvars[groups['elasticsearch'][0]]['ansible_default_ipv4']['address'] }}:{{elasticsearch_port_api}}"`|`False`|
|`cost_explorer_es_username`|Specifies the username for authenticating with the Elasticsearch service.|`string`|`"elastic"`|`False`|
|`cost_explorer_ingestion_schedule`|Sets the schedule for CostExplorer Ingestion jobs.|`string`|`"*-*-* 00:00:00"`|`False`|
|`cycloid_api_dns`|Resolvable domain name from the instance and externally to use Cycloid API.If not defined, proxypass from cycloid_console_dns will be used.|`string`|`""`|`False`|
|`cycloid_api_log_level`|Sets the log level for Cycloid API.|`string`|`"INFO"`|`False`|
|`cycloid_api_version`|Cycloid API version|`string`|`"latest-public"`|`False`|
|`cycloid_cache_host`|Specifies the hostname or IP address of Redis server.by default Get the address of the first defined host in cycloid_cache group|`string`|`"{{ hostvars[groups['cycloid_cache'][0]]['ansible_default_ipv4']['address'] }}"`|`True`|
|`cycloid_cache_password`|The password for authenticating with the Redis cache server. Set to empty "" to disable authentication.|`string`|`"Ch4ngm3pls"`|`False`|
|`cycloid_cache_port`|Specifies the port to reach Redis server.|`string`|`"6379"`|`False`|
|`cycloid_cache_schema`|Redis URI schema. Use "rediss" for Redis connection over a secure (SSL/TLS) connection.|`string`|`"redis"`|`False`|
|`cycloid_cache_username`|The username for authenticating with the Redis cache server. Set to empty "" to disable authentication.|`string`|`"default"`|`False`|
|`cycloid_console_dns`|Resolvable domain name from the instance and externally to use Cycloid console.|`string`|`""`|`True`|
|`cycloid_crypto_signing_key`|Define a cryptographic signing key within the Cycloid platform.|`string`|``|`True`|
|`cycloid_db_host`|Specifies the hostname or IP address of the Cycloid database server.by default Get the address of the first defined host in cycloid_db group|`string`|`"{{ hostvars[groups['cycloid_db'][0]]['ansible_default_ipv4']['address'] }}"`|`True`|
|`cycloid_db_name`|Defines the name of the Cycloid database.|`string`|`"cycloid"`|`False`|
|`cycloid_db_password`|Defines the password for accessing the Cycloid database.|`string`|`"Ch4ngm3pls"`|`True`|
|`cycloid_db_port`|Defines the port number on which the Cycloid database server is listening.|`string`|`"3306"`|`True`|
|`cycloid_db_user`|Specifies the username for the Cycloid database.|`string`|`"cycloid"`|`True`|
|`cycloid_email_addr_from`|Specifies the email address that will appear in the "From" field of emails sent by Cycloid.|`string`|`"noreply@cycloid.io"`|`True`|
|`cycloid_email_addr_return_path`|Defines the return email for bounced emails.|`string`|`"admin+bounce@cycloid.io"`|`True`|
|`cycloid_email_skip_tls_check`|Allow insecure TLS/SSL with email. Usefull when using local postfix as relayhost with selfsigned certs|`bool`|`"false"`|`False`|
|`cycloid_email_smtp_password`|Defines the password for SMTP authentication.|`string`|`"Ch4ngm3pls"`|`True`|
|`cycloid_email_smtp_svr_addr`|Specifies the address of the SMTP server used for sending emails.|`string`|`"{{ hostvars[groups['smtp_server'][0]]['ansible_default_ipv4']['address'] }}:1025"`|`True`|
|`cycloid_email_smtp_username`|Defines the username for SMTP authentication.|`string`|`"admin"`|`True`|
|`cycloid_frontend_version`|Cycloid Frontend version|`string`|`"latest-public"`|`False`|
|`cycloid_initial_user`|First Cycloid organization name.|`string`|`"Cycloid"`|`False`|
|`cycloid_job_cost_estimation_injection_aws`|Ingest the price of the AWS cloud provider for use in the Cost Estimation feature.|`bool`|`"false"`|`False`|
|`cycloid_job_cost_estimation_injection_azure`|Ingest the price of the Azure cloud provider for use in the Cost Estimation feature.|`bool`|`"false"`|`False`|
|`cycloid_job_cost_estimation_injection_gcp`|Ingest the price of the GCP cloud provider for use in the Cost Estimation feature.|`bool`|`"false"`|`False`|
|`cycloid_licence`|If provided, initialize Cycloid with the licence|`string`|`""`|`False`|
|`vault_url`|External vault url used by others services.|`string`|`"https://{{ hostvars[groups['cycloid_creds'][0]]['ansible_default_ipv4']['address'] }}:8200"`|`True`|

## Advanced variables

|Name|Description|Type|Default|Required|
|---|---|:---:|:---:|:---:|
|`azure_ad_client_id`|The client ID of Azure AD|`string`|`""`|`False`|
|`azure_ad_tenant_id`|The tenant ID of Azure AD|`string`|`""`|`False`|
|`ca_certificates_container_shared`|Share your rootCA from the host to containers|`bool`|`false`|`False`|
|`container_args_extra`|Used to give extra argument to containers. Example to override domain server "--dns 172.17.0.1"|`string`|`""`|`False`|
|`cycloid_admin_apikey`|Create admin APIKEY on the first organization. APIKEY will be stored localy under ``{{playbook_dir}}/admin.apikey`. (`cycloid_licence` need to be defined)|`bool`|`false`|`False`|
|`cycloid_cache_mon_install`|Asynqmon is used to debug redis worker queue. Set true to install it|`bool`|`false`|`False`|
|`cycloid_packages`|List of packages to install depending of the OS|`map`|`debian`|`False`|
|`cycloid_public_stacks`|Create a catalog repository with Cycloid Public Stacks. (`cycloid_licence` need to be defined)|`bool`|`true`|`False`|
|`extra_no_proxy`|Specify a list of domain names, IP addresses, or network blocks that should bypass the proxy|`list`|`[]`|`False`|
|`github_client_id`|The client ID of Github|`string`|`""`|`False`|
|`github_client_secret`|The client secret of Github|`string`|`""`|`False`|
|`google_client_id`|The client ID of Google|`string`|`""`|`False`|
|`google_client_secret`|The client secret of Google|`string`|`""`|`False`|
|`http_proxy`|Specify the proxy server for HTTP connections. When set, all HTTP requests will be routed through the specified proxy server.|`string`|`""`|`False`|
|`https_proxy`|Specify the proxy server for HTTPS connections. When set, all HTTPS requests will be routed through the specified proxy server.|`string`|`""`|`False`|
|`offline_setup`|Set true to not install packages automatically.|`bool`|`false`|`False`|
|`saml_auth_enabled`|Enabled SAML auth on Cyclid API.|`bool`|`false`|`False`|
|`saml_idp_metadata_file`|Name of your xml identity provider federation metadata file. It could also be provided as an url with saml_idp_metadata_url.|`string`|`"idp-metadata"`|`False`|
|`saml_idp_metadata_url`|URL to get your XML Identity Provider federation metadata file. If defined, do not provide saml_idp_metadata_file.|`string`|`""`|`False`|
|`saml_sp_certificate_file`|Name of the certificate private key stored in saml_local_path to use in cycloid|`string`|`"cycloid-saml-sp.crt"`|`False`|
|`saml_sp_private_key_file`|Name of the certificate private key stored in saml_local_path to use in cycloid|`string`|`"cycloid-saml-sp.key"`|`False`|
|`ssl_subject_alt_name`|Alternative common name to use in addition of the default ones for the self signed certs . Use `DNS` for a domain name and `IP` for a raw IP address.|`list`|`[]`|`False`|
|`uninstall`|/!\ Set to true only if you want to uninstall cycloid /!\|`bool`|`false`|`False`|
|`validate`|Wait and validate running services via validate.yml|`bool`|`true`|`False`|
|`validate_only`|If true, only run validate.yml and skip other tasks|`bool`|`false`|`False`|
|`vault_config`|Override Vault config such storage.|`map`|``|`False`|
