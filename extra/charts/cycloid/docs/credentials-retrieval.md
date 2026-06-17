# Credentials Retrieval Guide

This document lists all credentials managed by the Cycloid Helm chart and the exact commands
to retrieve them from a running cluster.

All examples assume:
- Release name: `cycloid` (adjust if yours differs)
- Namespace: `cycloid` (adjust with `-n <your-namespace>`)

A quick alias to decode a secret key:

```bash
# Usage: ksecret <secret-name> <key>
ksecret() { kubectl get secret -n cycloid "$1" -o jsonpath="{.data.$2}" | base64 -d; echo; }
```

---

## Table of contents

1. [Vault](#vault)
   - [Unseal keys and root token](#unseal-keys-and-root-token)
   - [AppRole credentials (rw — backend)](#approle-credentials-rw--backend)
   - [AppRole credentials (ro — Concourse)](#approle-credentials-ro--concourse)
2. [Backend](#backend)
   - [Concourse admin password](#concourse-admin-password)
   - [Crypto signing key](#crypto-signing-key)
   - [JWT key](#jwt-key)
3. [MySQL](#mysql)
   - [Internal MySQL (bundled)](#internal-mysql-bundled)
   - [External MySQL](#external-mysql)
4. [Redis](#redis)
   - [Internal Redis (bundled)](#internal-redis-bundled)
   - [External Redis](#external-redis)
5. [Concourse](#concourse)
   - [Local user password](#local-user-password)
   - [PostgreSQL password](#postgresql-password)
   - [Vault auth param (ro approle)](#vault-auth-param-ro-approle)
   - [SSH and signing keys](#ssh-and-signing-keys)
6. [Plugins registry](#plugins-registry)
7. [All secrets at a glance](#all-secrets-at-a-glance)

---

## Vault

### Unseal keys and root token

The vault init script writes the output of `vault operator init` to
`/vault/init-data/init.txt` on a dedicated PVC. The root token and unseal keys live there.

**Read from the vault pod (always available):**

```bash
kubectl exec -n cycloid cycloid-vault-0 -- cat /vault/init-data/init.txt
```

Example output:

```
Unseal Key 1: <key1>
Unseal Key 2: <key2>
Unseal Key 3: <key3>
Unseal Key 4: <key4>
Unseal Key 5: <key5>

Initial Root Token: hvs.XXXXXXXXXXXXXXXXXXXX
```

Extract just the root token:

```bash
kubectl exec -n cycloid cycloid-vault-0 -- \
  grep "Initial Root Token:" /vault/init-data/init.txt | awk '{print $NF}'
```

Extract a specific unseal key (e.g. key 1):

```bash
kubectl exec -n cycloid cycloid-vault-0 -- \
  grep "Unseal Key 1:" /vault/init-data/init.txt | awk '{print $NF}'
```

**Read from the Kubernetes Secret (only if `vaultInitSecret.enabled=true`):**

```bash
# Full content
kubectl get secret -n cycloid cycloid-vault-init-keys \
  -o jsonpath='{.data.init\.txt}' | base64 -d

# Root token only
kubectl get secret -n cycloid cycloid-vault-init-keys \
  -o jsonpath='{.data.init\.txt}' | base64 -d | \
  grep "Initial Root Token:" | awk '{print $NF}'
```

> **Security note:** The root token grants full access to vault. Revoke it with
> `vault token revoke <token>` after initial setup if you follow a least-privilege policy.
> You can regenerate a new root token later with `vault operator generate-root` using only
> the unseal keys.

---

### AppRole credentials (rw — backend)

The read-write AppRole (`cycloid` role) is used by all backend pods to authenticate to vault.
Credentials are stored in the `cycloid-vault-approle` secret.

```bash
# role-id
kubectl get secret -n cycloid cycloid-vault-approle \
  -o jsonpath='{.data.role-id}' | base64 -d; echo

# secret-id
kubectl get secret -n cycloid cycloid-vault-approle \
  -o jsonpath='{.data.secret-id}' | base64 -d; echo
```

Verify they match what vault has registered:

```bash
ROOT_TOKEN=$(kubectl exec -n cycloid cycloid-vault-0 -- \
  grep "Initial Root Token:" /vault/init-data/init.txt | awk '{print $NF}')

kubectl exec -n cycloid cycloid-vault-0 -- \
  vault login "$ROOT_TOKEN" > /dev/null

kubectl exec -n cycloid cycloid-vault-0 -- \
  vault read auth/approle/role/cycloid/role-id
```

---

### AppRole credentials (ro — Concourse)

The read-only AppRole (`cycloid-ro` role) is used by the Concourse vault sidecar for
pipeline credential lookups. Credentials are stored in the same `cycloid-vault-approle`
secret, under different keys.

```bash
# role-id-ro
kubectl get secret -n cycloid cycloid-vault-approle \
  -o jsonpath='{.data.role-id-ro}' | base64 -d; echo

# secret-id-ro
kubectl get secret -n cycloid cycloid-vault-approle \
  -o jsonpath='{.data.secret-id-ro}' | base64 -d; echo
```

---

## Backend

The backend secret is named after the release (`cycloid` when release name is `cycloid`).

### Concourse admin password

This is the password for the `cycloid` local user in Concourse, also set as the backend
API's Concourse integration password.

```bash
kubectl get secret -n cycloid cycloid \
  -o jsonpath='{.data.concourse-password}' | base64 -d; echo
```

---

### Crypto signing key

Used by the backend to sign cryptographic tokens.

```bash
kubectl get secret -n cycloid cycloid \
  -o jsonpath='{.data.crypto-signing-key}' | base64 -d; echo
```

---

### JWT key

Used by the backend to sign JWTs issued to API consumers.

```bash
kubectl get secret -n cycloid cycloid \
  -o jsonpath='{.data.jwt-key-1}' | base64 -d; echo
```

---

## MySQL

### Internal MySQL (bundled)

When `mysql.enabled=true`, the MySQL secret is managed by the MySQL subchart and is named
after the MySQL release (`cycloid-mysql` by default).

```bash
# Application password (used by the backend)
kubectl get secret -n cycloid cycloid-mysql \
  -o jsonpath='{.data.mysql-password}' | base64 -d; echo

# Root password
kubectl get secret -n cycloid cycloid-mysql \
  -o jsonpath='{.data.mysql-root-password}' | base64 -d; echo
```

Connect to MySQL directly from a pod:

```bash
MYSQL_ROOT_PWD=$(kubectl get secret -n cycloid cycloid-mysql \
  -o jsonpath='{.data.mysql-root-password}' | base64 -d)

kubectl exec -it -n cycloid cycloid-mysql-0 -- \
  mysql -u root -p"$MYSQL_ROOT_PWD"
```

---

### External MySQL

When using an external MySQL (`mysql.enabled=false`), the password is stored in a chart-managed
secret if `externalMysql.existingSecret` is not set.

```bash
kubectl get secret -n cycloid cycloid-externalmysql \
  -o jsonpath='{.data.mysql-password}' | base64 -d; echo
```

If you provided your own secret via `externalMysql.existingSecret`, retrieve the password
from that secret directly.

---

## Redis

### Internal Redis (bundled)

When `redis.enabled=true`, the Redis secret is managed by the Redis subchart and is named
after the Redis release (`cycloid-redis` by default).

```bash
kubectl get secret -n cycloid cycloid-redis \
  -o jsonpath='{.data.redis-password}' | base64 -d; echo
```

Connect to Redis directly:

```bash
REDIS_PWD=$(kubectl get secret -n cycloid cycloid-redis \
  -o jsonpath='{.data.redis-password}' | base64 -d)

kubectl exec -it -n cycloid cycloid-redis-master-0 -- \
  redis-cli -a "$REDIS_PWD"
```

---

### External Redis

When using an external Redis (`redis.enabled=false`), the password is stored in a
chart-managed secret if `externalRedis.existingSecret` is not set.

```bash
kubectl get secret -n cycloid cycloid-externalredis \
  -o jsonpath='{.data.redis-password}' | base64 -d; echo
```

---

## Concourse

Concourse credentials are split across two secrets: `cycloid-concourse-web` (managed by the
Concourse subchart) and `cycloid-concourse-postgresql` (managed by the PostgreSQL subchart
bundled with Concourse).

### Local user password

The password for the `cycloid` local Concourse user (used to log in to the Concourse UI
and for the backend → Concourse API integration).

```bash
kubectl get secret -n cycloid cycloid-concourse-web \
  -o jsonpath='{.data.local-users}' | base64 -d; echo
# Output format: "cycloid:<password>"
```

To extract just the password:

```bash
kubectl get secret -n cycloid cycloid-concourse-web \
  -o jsonpath='{.data.local-users}' | base64 -d | cut -d: -f2; echo
```

This password is the same value as `backend.concourse.password` and is also stored in the
backend secret under `concourse-password` (see [Concourse admin password](#concourse-admin-password)).

---

### PostgreSQL password

Concourse uses a dedicated PostgreSQL instance (`cycloid-concourse-postgresql`).

```bash
# Application user password
kubectl get secret -n cycloid cycloid-concourse-postgresql \
  -o jsonpath='{.data.password}' | base64 -d; echo

# Postgres admin password
kubectl get secret -n cycloid cycloid-concourse-postgresql \
  -o jsonpath='{.data.postgres-password}' | base64 -d; echo
```

---

### Vault auth param (ro approle)

The Concourse web pod uses the `cycloid-ro` AppRole to fetch pipeline credentials from vault.
The combined `role_id:...,secret_id:...` string is stored in the Concourse web secret.

```bash
kubectl get secret -n cycloid cycloid-concourse-web \
  -o jsonpath='{.data.vault-auth-param}' | base64 -d; echo
# Output: "role_id:<role-id-ro>,secret_id:<secret-id-ro>"
```

> This value is derived from the `cycloid-vault-approle` secret keys `role-id-ro` and
> `secret-id-ro`. If the values differ, the `cycloid-vault-approle` secret is authoritative
> (those are the values registered in vault by the init script).

---

### SSH and signing keys

```bash
# Concourse TSA host key (private)
kubectl get secret -n cycloid cycloid-concourse-web \
  -o jsonpath='{.data.host-key}' | base64 -d

# Concourse TSA host key (public)
kubectl get secret -n cycloid cycloid-concourse-web \
  -o jsonpath='{.data.host-key-pub}' | base64 -d

# Session signing key (private)
kubectl get secret -n cycloid cycloid-concourse-web \
  -o jsonpath='{.data.session-signing-key}' | base64 -d

# Worker key (private)
kubectl get secret -n cycloid cycloid-concourse-web \
  -o jsonpath='{.data.worker-key}' | base64 -d

# Worker key (public)
kubectl get secret -n cycloid cycloid-concourse-web \
  -o jsonpath='{.data.worker-key-pub}' | base64 -d
```

---

## Plugins registry

When `plugins.enabled=true`, the chart creates a secret for the private Docker registry
bundled with the plugin system.

```bash
# Registry username
kubectl get secret -n cycloid cycloid-plugin-registry \
  -o jsonpath='{.data.REGISTRY_USERNAME}' | base64 -d; echo

# Registry password
kubectl get secret -n cycloid cycloid-plugin-registry \
  -o jsonpath='{.data.REGISTRY_PASSWORD}' | base64 -d; echo

# Registry URI (host:port)
kubectl get secret -n cycloid cycloid-plugin-registry \
  -o jsonpath='{.data.REGISTRY_URI}' | base64 -d; echo
```

Log in to the registry:

```bash
REGISTRY_URI=$(kubectl get secret -n cycloid cycloid-plugin-registry \
  -o jsonpath='{.data.REGISTRY_URI}' | base64 -d)
REGISTRY_USER=$(kubectl get secret -n cycloid cycloid-plugin-registry \
  -o jsonpath='{.data.REGISTRY_USERNAME}' | base64 -d)
REGISTRY_PASS=$(kubectl get secret -n cycloid cycloid-plugin-registry \
  -o jsonpath='{.data.REGISTRY_PASSWORD}' | base64 -d)

docker login "$REGISTRY_URI" -u "$REGISTRY_USER" -p "$REGISTRY_PASS"
```

---

## All secrets at a glance

Quick reference — list every relevant secret in the namespace and the keys each contains:

```bash
kubectl get secrets -n cycloid \
  cycloid \
  cycloid-vault-approle \
  cycloid-mysql \
  cycloid-redis \
  cycloid-concourse-web \
  cycloid-concourse-postgresql \
  -o json | \
  jq -r '.items[] | .metadata.name as $n | .data | keys[] | "\($n)  \(.)"'
```

Individual dump of all decoded values (use with care — outputs sensitive data):

```bash
for secret in \
  cycloid \
  cycloid-vault-approle \
  cycloid-mysql \
  cycloid-redis \
  cycloid-concourse-web \
  cycloid-concourse-postgresql \
  cycloid-plugin-registry; do
  echo "=== $secret ==="
  kubectl get secret -n cycloid "$secret" -o json | \
    jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'
  echo
done
```

Summary table of secrets and what they contain:

| Secret | Key | Description | Auto-generated |
|---|---|---|---|
| `cycloid-vault-approle` | `role-id` | Vault rw AppRole role-id | Yes (Helm, uuidv4) |
| `cycloid-vault-approle` | `secret-id` | Vault rw AppRole secret-id | Yes (Helm, randAlphaNum 32) |
| `cycloid-vault-approle` | `role-id-ro` | Vault ro AppRole role-id | Yes (Helm, uuidv4) |
| `cycloid-vault-approle` | `secret-id-ro` | Vault ro AppRole secret-id | Yes (Helm, randAlphaNum 32) |
| `cycloid-vault-init-keys` | `init.txt` | Vault unseal keys + root token | Yes (vault, optional) |
| `cycloid` | `concourse-password` | Concourse `cycloid` user password | Yes (`generate-random-passwords.sh`) |
| `cycloid` | `crypto-signing-key` | Backend crypto key | Yes (`generate-random-passwords.sh`) |
| `cycloid` | `jwt-key-1` | JWT signing key | Yes (`generate-random-passwords.sh`) |
| `cycloid-mysql` | `mysql-password` | MySQL app user password | Yes (`generate-random-passwords.sh`) |
| `cycloid-mysql` | `mysql-root-password` | MySQL root password | Yes (`generate-random-passwords.sh`) |
| `cycloid-redis` | `redis-password` | Redis password | Yes (`generate-random-passwords.sh`) |
| `cycloid-concourse-web` | `local-users` | Concourse local users (user:pass) | Yes (`generate-random-passwords.sh`) |
| `cycloid-concourse-web` | `vault-auth-param` | Vault ro approle for Concourse | Yes (from `cycloid-vault-approle`) |
| `cycloid-concourse-web` | `host-key` | Concourse TSA host private key | Yes (`generate-random-passwords.sh`) |
| `cycloid-concourse-web` | `session-signing-key` | Concourse session signing key | Yes (`generate-random-passwords.sh`) |
| `cycloid-concourse-web` | `worker-key` | Concourse worker private key | Yes (`generate-random-passwords.sh`) |
| `cycloid-concourse-postgresql` | `password` | Concourse PostgreSQL app password | Yes (`generate-random-passwords.sh`) |
| `cycloid-concourse-postgresql` | `postgres-password` | Concourse PostgreSQL root password | Yes (`generate-random-passwords.sh`) |
| `cycloid-plugin-registry` | `REGISTRY_PASSWORD` | Plugin registry password | Yes (Helm, randAlphaNum 30) |
