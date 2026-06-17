# Troubleshooting Guide

Quick-reference for diagnosing and fixing common issues in a Cycloid on-premises deployment.

All examples assume release name `cycloid` and namespace `cycloid`. Adjust with `-n <namespace>` as needed.

---

## Table of contents

1. [General diagnostic commands](#general-diagnostic-commands)
2. [Vault](#vault)
   - [Pod stuck in Init or Pending](#pod-stuck-in-init-or-pending)
   - [postStart script did not run or failed](#poststart-script-did-not-run-or-failed)
   - [Vault is sealed after a pod restart](#vault-is-sealed-after-a-pod-restart)
   - [init.txt is missing from the PVC](#inittxt-is-missing-from-the-pvc)
   - [AppRole authentication fails](#approle-authentication-fails)
   - [vaultInitSecret curl fails](#vaultinitsecret-curl-fails)
3. [Backend](#backend)
   - [CrashLoopBackOff on startup](#crashloopbackoff-on-startup)
   - [Cannot connect to vault](#cannot-connect-to-vault)
   - [Cannot connect to MySQL](#cannot-connect-to-mysql)
   - [Cannot connect to Redis](#cannot-connect-to-redis)
   - [Backend healthy but API returns 500](#backend-healthy-but-api-returns-500)
4. [MySQL](#mysql)
   - [Pod not starting / CrashLoopBackOff](#mysql-pod-not-starting--crashloopbackoff)
   - [Access denied / wrong password](#access-denied--wrong-password)
   - [PVC bound but MySQL fails to start](#pvc-bound-but-mysql-fails-to-start)
5. [Redis](#redis)
   - [Pod not starting](#redis-pod-not-starting)
   - [TLS / certificate errors](#tls--certificate-errors)
   - [WRONGPASS authentication error](#wrongpass-authentication-error)
6. [Concourse](#concourse)
   - [Web pod not starting](#concourse-web-pod-not-starting)
   - [Workers not connecting](#workers-not-connecting)
   - [Vault credential manager failing](#vault-credential-manager-failing)
   - [Pipelines cannot resolve ((secrets))](#pipelines-cannot-resolve-secrets)
   - [PostgreSQL not ready](#concourse-postgresql-not-ready)
7. [Helm](#helm)
   - [Upgrade fails with immutable field error](#upgrade-fails-with-immutable-field-error)
   - [lookup always returns empty (offline rendering)](#lookup-always-returns-empty-offline-rendering)
   - [Values from values.custom.yaml not applied](#values-from-valuescustomyaml-not-applied)
   - [Subchart values not merging as expected](#subchart-values-not-merging-as-expected)
8. [Storage / PVC](#storage--pvc)
   - [PVC stuck in Pending](#pvc-stuck-in-pending)
   - [PVC lost after namespace deletion](#pvc-lost-after-namespace-deletion)
9. [Networking / Ingress](#networking--ingress)
   - [503 / connection refused from ingress](#503--connection-refused-from-ingress)
   - [TLS certificate not valid](#tls-certificate-not-valid)
10. [Image pull errors](#image-pull-errors)

---

## General diagnostic commands

```bash
# Overview of all pods
kubectl get pods -n cycloid

# Events (most useful first step — shows scheduling, image, mount failures)
kubectl get events -n cycloid --sort-by='.lastTimestamp' | tail -30

# Describe a specific pod (includes events, resource limits, volume mounts)
kubectl describe pod -n cycloid <pod-name>

# Logs for a running container
kubectl logs -n cycloid <pod-name>

# Logs for a previous crashed container
kubectl logs -n cycloid <pod-name> --previous

# Logs for a specific container in a multi-container pod
kubectl logs -n cycloid <pod-name> -c <container-name>

# Follow logs
kubectl logs -n cycloid <pod-name> -f

# List all secrets and their ages
kubectl get secrets -n cycloid

# List all PVCs and their status
kubectl get pvc -n cycloid

# List all config maps
kubectl get configmap -n cycloid
```

---

## Vault

### Pod stuck in Init or Pending

**Symptoms:** `cycloid-vault-0` stays in `Pending` or `Init:0/1`.

**Check 1 — PVC not bound:**

```bash
kubectl get pvc -n cycloid | grep vault
```

If the vault data PVC or the init-data PVC shows `Pending`, see [PVC stuck in Pending](#pvc-stuck-in-pending).

**Check 2 — Events:**

```bash
kubectl describe pod -n cycloid cycloid-vault-0
```

Look for `FailedScheduling`, `FailedMount`, or image pull errors in the Events section.

**Check 3 — ConfigMap missing:**

The `postStart` script is mounted from a ConfigMap. If the chart was partially applied:

```bash
kubectl get configmap -n cycloid cycloid-vault-init-script
```

If missing, re-run `helm upgrade`.

---

### postStart script did not run or failed

`postStart` stdout/stderr is not streamed to `kubectl logs`. Failures surface as the container entering `Error` state or as delayed pod readiness.

**Check if vault was configured correctly:**

```bash
# vault status should show Initialized: true, Sealed: false
kubectl exec -n cycloid cycloid-vault-0 -- vault status
```

**Check if init.txt was written:**

```bash
kubectl exec -n cycloid cycloid-vault-0 -- ls -lh /vault/init-data/
kubectl exec -n cycloid cycloid-vault-0 -- cat /vault/init-data/init.txt
```

**Run the init script manually** (safe — all steps are idempotent):

```bash
kubectl exec -n cycloid cycloid-vault-0 -- /bin/sh /vault/init-scripts/init.sh
```

This will print the script's output directly so you can see exactly which step fails.

**Check the ConfigMap content looks correct:**

```bash
kubectl get configmap -n cycloid cycloid-vault-init-script -o jsonpath='{.data.init\.sh}'
```

**Check that env vars are injected (extraSecretEnvironmentVars):**

```bash
kubectl exec -n cycloid cycloid-vault-0 -- env | grep VAULT_ROLE
# Expected: VAULT_ROLE_ID=<uuid>, VAULT_ROLE_ID_RO=<uuid>
```

If these are empty, the `cycloid-vault-approle` secret may not exist yet or the pod started before it was created:

```bash
kubectl get secret -n cycloid cycloid-vault-approle
# If missing: helm upgrade will recreate it
```

---

### Vault is sealed after a pod restart

**This is expected on pre-auto-init installations** that have not yet seeded `init.txt` on the PVC. The upgrade guard in the init script exits cleanly when vault is already initialised but `init.txt` is absent.

**Option 1 — Manual unseal (same as before the chart upgrade):**

```bash
bash scripts/vault-unseal.sh
```

**Option 2 — Enable auto-unseal by seeding init.txt:**

If you have your original vault init data, copy it to the PVC and future restarts will unseal automatically:

```bash
kubectl cp /path/to/init.txt cycloid/cycloid-vault-0:/vault/init-data/init.txt
```

The file must be in the raw `vault operator init` text format (not JSON). See
[credentials-retrieval.md](credentials-retrieval.md) for the expected format.

**On new installations**, if vault is sealed after a pod restart, the most likely cause is
that `init.txt` was deleted or the PVC was lost. See [init.txt is missing](#inittxt-is-missing-from-the-pvc).

---

### init.txt is missing from the PVC

**Symptoms:** Vault pod restarts, `vault status` shows `Sealed: true`, and `/vault/init-data/init.txt` does not exist.

**Causes:**
- PVC was deleted and recreated (e.g. namespace wipe, `helm uninstall`)
- Manual deletion of the file
- Pod restarted before init completed on first install

**Recovery options (in order of preference):**

1. **From the K8s Secret** (if `vaultInitSecret.enabled=true` was set at install time):

   ```bash
   kubectl get secret -n cycloid cycloid-vault-init-keys \
     -o jsonpath='{.data.init\.txt}' | base64 -d > /tmp/init.txt
   kubectl cp /tmp/init.txt cycloid/cycloid-vault-0:/vault/init-data/init.txt
   kubectl delete pod -n cycloid cycloid-vault-0  # trigger restart + auto-unseal
   ```

2. **From a local backup** (e.g. from `scripts/.out/vault-init.json` on the operator machine):

   ```bash
   # Convert from JSON to text format
   jq -r '
     (.unseal_keys_b64 | to_entries[] | "Unseal Key \(.key+1): \(.value)"),
     "",
     "Initial Root Token: \(.root_token)"
   ' scripts/.out/vault-init.json > /tmp/init.txt

   kubectl cp /tmp/init.txt cycloid/cycloid-vault-0:/vault/init-data/init.txt
   kubectl delete pod -n cycloid cycloid-vault-0
   ```

3. **Manual unseal + reconfigure** (if init data is lost permanently):

   ```bash
   # Unseal manually (you need 3 of the 5 unseal keys)
   kubectl exec -n cycloid cycloid-vault-0 -- vault operator unseal <key1>
   kubectl exec -n cycloid cycloid-vault-0 -- vault operator unseal <key2>
   kubectl exec -n cycloid cycloid-vault-0 -- vault operator unseal <key3>

   # Log in and re-configure AppRole with the existing credentials from vault-approle secret
   ROOT_TOKEN=<your-root-token>
   kubectl exec -n cycloid cycloid-vault-0 -- vault login "$ROOT_TOKEN"

   ROLE_ID=$(kubectl get secret -n cycloid cycloid-vault-approle \
     -o jsonpath='{.data.role-id}' | base64 -d)
   SECRET_ID=$(kubectl get secret -n cycloid cycloid-vault-approle \
     -o jsonpath='{.data.secret-id}' | base64 -d)

   kubectl exec -n cycloid cycloid-vault-0 -- \
     vault write auth/approle/role/cycloid/role-id role_id="$ROLE_ID"
   kubectl exec -n cycloid cycloid-vault-0 -- \
     vault write auth/approle/role/cycloid/secret-id secret_id="$SECRET_ID"
   ```

> **Prevention:** Enable `vaultInitSecret.enabled=true` in `values.custom.yaml` and keep a
> backup of the `cycloid-vault-init-keys` secret.

---

### AppRole authentication fails

**Symptoms:** Backend pods start but immediately fail with vault authentication errors. Vault logs show `permission denied` or `invalid role or secret ID`.

**Check 1 — Credentials in the secret match vault:**

```bash
# Get role-id from secret
kubectl get secret -n cycloid cycloid-vault-approle \
  -o jsonpath='{.data.role-id}' | base64 -d; echo

# Get role-id registered in vault
kubectl exec -n cycloid cycloid-vault-0 -- \
  vault read auth/approle/role/cycloid/role-id
```

If they differ, the secret was regenerated (e.g. after `helm uninstall`) but vault still
has the old credentials. Re-run the init script to re-register:

```bash
kubectl exec -n cycloid cycloid-vault-0 -- /bin/sh /vault/init-scripts/init.sh
```

**Check 2 — AppRole role exists in vault:**

```bash
ROOT_TOKEN=$(kubectl exec -n cycloid cycloid-vault-0 -- \
  grep "Initial Root Token:" /vault/init-data/init.txt | awk '{print $NF}')

kubectl exec -n cycloid cycloid-vault-0 -- vault login "$ROOT_TOKEN"
kubectl exec -n cycloid cycloid-vault-0 -- vault read auth/approle/role/cycloid
```

If the role does not exist, run the init script (idempotent, safe to re-run).

**Check 3 — Secret ID TTL expired:**

Secret IDs on the `cycloid` role have no TTL by default. If the role was created manually
with a TTL, it may have expired. Re-register with:

```bash
kubectl exec -n cycloid cycloid-vault-0 -- /bin/sh /vault/init-scripts/init.sh
```

---

### vaultInitSecret curl fails

**Symptoms:** Init script runs successfully but logs `WARNING: Failed to write K8s secret`.

**Check RBAC:**

```bash
kubectl get role,rolebinding -n cycloid | grep vault-init
```

If missing, verify `vaultInitSecret.enabled=true` is set and re-run `helm upgrade`.

**Check curl is available in the vault image:**

```bash
kubectl exec -n cycloid cycloid-vault-0 -- which curl
```

If not found, the vault image variant you are using does not include curl. Switch to the
standard `hashicorp/vault` image (not `-ubi` or minimal variants).

**Test the API call manually:**

```bash
kubectl exec -n cycloid cycloid-vault-0 -- sh -c '
  TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  curl -sSk -H "Authorization: Bearer $TOKEN" \
    https://kubernetes.default.svc/api/v1/namespaces/cycloid/secrets \
    -o /dev/null -w "%{http_code}\n"
'
# 200 = API reachable; 403 = RBAC issue
```

---

## Backend

### CrashLoopBackOff on startup

**This is expected behaviour** when vault has not finished initialising. Backend pods need vault to be unsealed and the AppRole configured before they can authenticate.

Monitor vault progress:

```bash
kubectl exec -n cycloid cycloid-vault-0 -- vault status
```

Once `Sealed: false` and the AppRole is configured, the backend pod will recover
automatically on its next restart — no manual intervention needed.

If the pod is still crash-looping more than 5 minutes after vault shows `Sealed: false`:

```bash
kubectl logs -n cycloid -l app.kubernetes.io/name=api --previous
```

Look for the actual error (database connection, missing env var, etc.) rather than vault.

---

### Cannot connect to vault

**Check vault is running and unsealed:**

```bash
kubectl exec -n cycloid cycloid-vault-0 -- vault status
```

**Check the vault URL the backend is using:**

```bash
kubectl exec -n cycloid deployment/cycloid-api -- env | grep VAULT_URL
# Expected: VAULT_URL=http://cycloid-vault:8200
```

**Test connectivity from the backend pod:**

```bash
kubectl exec -n cycloid deployment/cycloid-api -- \
  wget -qO- http://cycloid-vault:8200/v1/sys/health
# Expected: JSON with {"initialized":true,"sealed":false,...}
```

If this fails with `connection refused`, the vault service may not exist:

```bash
kubectl get svc -n cycloid | grep vault
```

---

### Cannot connect to MySQL

**Check the MySQL pod is running:**

```bash
kubectl get pods -n cycloid | grep mysql
kubectl logs -n cycloid cycloid-mysql-0
```

**Test connectivity from the backend pod:**

```bash
kubectl exec -n cycloid deployment/cycloid-api -- \
  env | grep -E "DB_HOST|DB_PORT|DB_USER|DB_NAME"

# Test TCP reachability
kubectl exec -n cycloid deployment/cycloid-api -- \
  sh -c 'echo > /dev/tcp/$DB_HOST/$DB_PORT && echo "reachable" || echo "unreachable"'
```

**Check the password secret:**

```bash
kubectl get secret -n cycloid cycloid-mysql \
  -o jsonpath='{.data.mysql-password}' | base64 -d; echo
```

Ensure this matches `mysql.auth.password` in your `values.custom.yaml`.

---

### Cannot connect to Redis

**Check the Redis pod:**

```bash
kubectl get pods -n cycloid | grep redis
kubectl logs -n cycloid cycloid-redis-master-0
```

**Test connectivity:**

```bash
kubectl exec -n cycloid deployment/cycloid-api -- \
  env | grep REDIS

REDIS_PWD=$(kubectl get secret -n cycloid cycloid-redis \
  -o jsonpath='{.data.redis-password}' | base64 -d)

kubectl exec -n cycloid cycloid-redis-master-0 -- \
  redis-cli -a "$REDIS_PWD" ping
# Expected: PONG
```

**TLS cert issue:** If Redis TLS is enabled (default), see [TLS / certificate errors](#tls--certificate-errors).

---

### Backend healthy but API returns 500

```bash
# Check recent backend logs for stack traces
kubectl logs -n cycloid deployment/cycloid-api --since=5m | grep -i error

# Check if vault KV secrets engine has been initialised
ROOT_TOKEN=$(kubectl exec -n cycloid cycloid-vault-0 -- \
  grep "Initial Root Token:" /vault/init-data/init.txt | awk '{print $NF}')
kubectl exec -n cycloid cycloid-vault-0 -- vault login "$ROOT_TOKEN" > /dev/null
kubectl exec -n cycloid cycloid-vault-0 -- vault secrets list | grep cycloid
# Should show: cycloid/   kv
```

If the `cycloid` secrets engine is missing, the init script did not complete. Re-run it:

```bash
kubectl exec -n cycloid cycloid-vault-0 -- /bin/sh /vault/init-scripts/init.sh
```

---

## MySQL

### MySQL pod not starting / CrashLoopBackOff

```bash
kubectl logs -n cycloid cycloid-mysql-0
kubectl describe pod -n cycloid cycloid-mysql-0
```

**Common causes:**

- **PVC not bound** — see [PVC stuck in Pending](#pvc-stuck-in-pending)
- **Wrong storageClass** — check `mysql.primary.persistence.storageClass` matches an available class:
  ```bash
  kubectl get storageclass
  ```
- **Existing data incompatible with new version** — if you upgraded MySQL major version and the PVC has old data, MySQL will refuse to start. Check logs for `InnoDB: Unsupported redo log format`.

---

### Access denied / wrong password

The most common cause is a mismatch between the password in `values.custom.yaml` and what
was originally written to the PVC when MySQL first started. MySQL stores the password in its
data directory — changing `mysql.auth.password` in values and upgrading does **not** change
the database password.

**Retrieve the current password from the secret:**

```bash
kubectl get secret -n cycloid cycloid-mysql \
  -o jsonpath='{.data.mysql-password}' | base64 -d; echo
```

**Reset the password in MySQL** (requires root access):

```bash
ROOT_PWD=$(kubectl get secret -n cycloid cycloid-mysql \
  -o jsonpath='{.data.mysql-root-password}' | base64 -d)

kubectl exec -n cycloid cycloid-mysql-0 -- \
  mysql -u root -p"$ROOT_PWD" -e \
  "ALTER USER 'cycloid'@'%' IDENTIFIED BY '<new-password>'; FLUSH PRIVILEGES;"
```

Then update `values.custom.yaml` with the new password and run `helm upgrade`.

---

### PVC bound but MySQL fails to start

If the PVC exists from a previous install (e.g. after `helm uninstall` without deleting PVCs),
MySQL may refuse to start because the existing data was created with a different root password
or a different MySQL version.

```bash
kubectl logs -n cycloid cycloid-mysql-0 | grep -i "error\|fatal\|permission"
```

If the data directory is from a different install and is not needed:

```bash
# WARNING: this destroys all MySQL data
kubectl delete pvc -n cycloid data-cycloid-mysql-0
kubectl delete pod -n cycloid cycloid-mysql-0
```

---

## Redis

### Redis pod not starting

```bash
kubectl logs -n cycloid cycloid-redis-master-0
kubectl describe pod -n cycloid cycloid-redis-master-0
```

Check for PVC issues (see [PVC stuck in Pending](#pvc-stuck-in-pending)) or permission errors
(`chown` failures suggest a `securityContext` / `fsGroup` mismatch with the StorageClass).

---

### TLS / certificate errors

Redis TLS is enabled by default. The chart generates a self-signed CA and certificate stored
in the `cycloid-redis-crt` secret, and mounts the CA cert as `REDIS_CA_CERT` in all backend
containers.

**Check the cert secret exists:**

```bash
kubectl get secret -n cycloid cycloid-redis-crt
```

**Check the CA cert is mounted in the backend:**

```bash
kubectl exec -n cycloid deployment/cycloid-api -- env | grep REDIS_CA_CERT
```

**Verify Redis accepts TLS connections:**

```bash
kubectl exec -n cycloid cycloid-redis-master-0 -- \
  redis-cli --tls --insecure ping
```

If using an external Redis with a custom TLS cert, set `REDIS_CA_CERT` via
`backend.extraSecretEnvVars` pointing to your cert secret.

---

### WRONGPASS authentication error

Retrieve the correct password and test:

```bash
REDIS_PWD=$(kubectl get secret -n cycloid cycloid-redis \
  -o jsonpath='{.data.redis-password}' | base64 -d)

kubectl exec -n cycloid cycloid-redis-master-0 -- \
  redis-cli -a "$REDIS_PWD" --tls --insecure ping
```

If this succeeds but the backend still fails, the password in the backend pod's environment
may be stale (pod needs a restart to pick up a secret update):

```bash
kubectl rollout restart deployment/cycloid-api -n cycloid
```

---

## Concourse

### Concourse web pod not starting

```bash
kubectl logs -n cycloid cycloid-concourse-web-<id>
kubectl describe pod -n cycloid cycloid-concourse-web-<id>
```

**Common causes:**

- **PostgreSQL not ready** — Concourse web waits for its PostgreSQL instance. Check:
  ```bash
  kubectl get pods -n cycloid | grep postgresql
  kubectl logs -n cycloid cycloid-concourse-postgresql-0
  ```

- **Missing secret keys** — SSH keys or encryption key not set. The `generate-random-passwords.sh`
  script must have been run before install:
  ```bash
  kubectl get secret -n cycloid cycloid-concourse-web \
    -o jsonpath='{.data}' | jq 'keys'
  # Must include: host-key, session-signing-key, worker-key, encryption-key, local-users
  ```

- **Wrong vault auth param** — `vaultAuthParam` is empty or malformed. See
  [Vault credential manager failing](#vault-credential-manager-failing).

---

### Workers not connecting

```bash
kubectl logs -n cycloid -l app=cycloid-concourse-worker
```

**Check TSA (web) is reachable from the worker:**

```bash
kubectl exec -n cycloid cycloid-concourse-worker-<id> -- \
  nc -zv cycloid-concourse-web 2222
```

**Check host key matches:** The worker uses `worker-key-pub` to verify the web's `host-key`.
If the web was reinstalled with a new key, the worker will refuse to connect. Both must be
regenerated together. Run `generate-random-passwords.sh` and `helm upgrade`.

---

### Vault credential manager failing

**Symptoms:** Concourse web logs show `failed to authenticate with vault` or `invalid auth param`.

**The `vaultAuthParam` value is empty by default** after upgrading to chart version 0.16.0+.
It must be set manually after the first install.

Retrieve the ro credentials and update `values.custom.yaml`:

```bash
ROLE_ID=$(kubectl get secret -n cycloid cycloid-vault-approle \
  -o jsonpath='{.data.role-id-ro}' | base64 -d)
SECRET_ID=$(kubectl get secret -n cycloid cycloid-vault-approle \
  -o jsonpath='{.data.secret-id-ro}' | base64 -d)

echo "vaultAuthParam: \"role_id:${ROLE_ID},secret_id:${SECRET_ID}\""
```

Add the output to `values.custom.yaml` under `concourse.secrets.vaultAuthParam`, then:

```bash
helm upgrade cycloid ./cycloid -n cycloid -f values.custom.yaml
```

**Verify vault approle auth backend is enabled:**

```bash
kubectl exec -n cycloid cycloid-vault-0 -- vault auth list | grep approle
```

---

### Pipelines cannot resolve ((secrets))

**Check the vault credential manager is enabled in values:**

```bash
# Should show: enabled: true, authBackend: approle, useAuthParam: true
grep -A10 'vault:' values.custom.yaml | grep -E "enabled|authBackend|useAuthParam"
```

**Check the secret path prefix:** Concourse looks under `/cycloid` by default
(`pathPrefix: /cycloid`). Secrets must be stored at `cycloid/<team>/<pipeline>/<key>` in
vault.

**Test a vault lookup manually:**

```bash
ROLE_ID=$(kubectl get secret -n cycloid cycloid-vault-approle \
  -o jsonpath='{.data.role-id-ro}' | base64 -d)
SECRET_ID=$(kubectl get secret -n cycloid cycloid-vault-approle \
  -o jsonpath='{.data.secret-id-ro}' | base64 -d)

kubectl exec -n cycloid cycloid-vault-0 -- sh -c "
  vault write -format=json auth/approle/login \
    role_id='$ROLE_ID' secret_id='$SECRET_ID' \
  | grep client_token
"
```

If the login fails, the ro AppRole is misconfigured. Re-run the init script.

---

### Concourse PostgreSQL not ready

```bash
kubectl logs -n cycloid cycloid-concourse-postgresql-0
```

**Wrong password:** Same issue as [MySQL access denied](#access-denied--wrong-password) —
the password in the PVC was set on first startup and changing values alone does not update it.

Reset:

```bash
PG_PWD=$(kubectl get secret -n cycloid cycloid-concourse-postgresql \
  -o jsonpath='{.data.postgres-password}' | base64 -d)

kubectl exec -n cycloid cycloid-concourse-postgresql-0 -- \
  psql -U postgres -c "ALTER USER concourse PASSWORD '<new-password>';"
```

---

## Helm

### Upgrade fails with immutable field error

```
Error: cannot patch "cycloid-mysql-0" with kind StatefulSet: ... field is immutable
```

Some StatefulSet fields (e.g. `volumeClaimTemplates`, `selector`) are immutable after
creation. This error appears after major chart upgrades that change these fields.

**Workaround:** Delete the StatefulSet (not the PVC) and let Helm recreate it:

```bash
kubectl delete statefulset -n cycloid cycloid-mysql --cascade=orphan
helm upgrade cycloid ./cycloid -n cycloid -f values.custom.yaml
```

`--cascade=orphan` deletes the StatefulSet controller but leaves pods and PVCs intact.

---

### lookup always returns empty (offline rendering)

```bash
helm template cycloid ./cycloid -f values.custom.yaml
```

`helm template` runs offline and `lookup` always returns `nil`. Every `randAlphaNum` /
`uuidv4` call generates new values on each render — this is expected and does not affect
`helm install` or `helm upgrade` (which run against the live cluster).

Use `helm upgrade --dry-run` to preview what a real upgrade would apply:

```bash
helm upgrade cycloid ./cycloid -n cycloid -f values.custom.yaml --dry-run
```

---

### Values from values.custom.yaml not applied

**Check precedence:** Multiple `-f` files are merged left-to-right; later files win. Make
sure your custom file is the last `-f` argument.

**Check for YAML parse errors:**

```bash
helm upgrade cycloid ./cycloid -n cycloid -f values.custom.yaml --dry-run 2>&1 | head -20
```

**Check the rendered output for the specific field:**

```bash
helm template cycloid ./cycloid -f values.custom.yaml | grep -A2 "the-field-you-expect"
```

---

### Subchart values not merging as expected

Helm **replaces** arrays in subchart values entirely rather than merging them. If you define
`concourse.web.sidecarContainers` in `values.custom.yaml`, it replaces the entire array from
`values.yaml`, not appending to it.

Always copy the full array from `values.yaml` into `values.custom.yaml` when overriding list
values, then add your entries.

---

## Storage / PVC

### PVC stuck in Pending

```bash
kubectl describe pvc -n cycloid <pvc-name>
```

**No StorageClass defined:** If `storageClass: ""` and no default StorageClass exists:

```bash
kubectl get storageclass
# Look for one marked (default)
```

Fix: either set a default StorageClass on the cluster, or specify one in your values:

```yaml
mysql:
  primary:
    persistence:
      storageClass: "your-storage-class"
```

**No available nodes / topology mismatch:** Check that nodes have enough free disk and that
the StorageClass topology constraints (e.g. zone affinity) can be satisfied.

---

### PVC lost after namespace deletion

`kubectl delete namespace` deletes PVCs. Whether the underlying PersistentVolume is also
deleted depends on the `reclaimPolicy` of the StorageClass:

- `Delete` (common default) — PV and its data are deleted permanently
- `Retain` — PV stays; you can manually rebind it

To avoid data loss, set your StorageClass `reclaimPolicy: Retain` for stateful workloads,
or snapshot PVCs before deletion.

---

## Networking / Ingress

### 503 / connection refused from ingress

**Check the service endpoints are populated:**

```bash
kubectl get endpoints -n cycloid cycloid-api
kubectl get endpoints -n cycloid cycloid-frontend
```

If `<none>`, the pods are not ready — check pod status first.

**Check the ingress class:**

```bash
kubectl get ingressclass
# The className in values.custom.yaml must match one of these
```

**Check the ingress resource:**

```bash
kubectl describe ingress -n cycloid
```

---

### TLS certificate not valid

If using cert-manager, check the Certificate resource:

```bash
kubectl describe certificate -n cycloid
kubectl get certificaterequest -n cycloid
```

If using a manually-provided TLS secret, verify the secret exists and the host matches:

```bash
kubectl get secret -n cycloid <tls-secret-name>
kubectl describe ingress -n cycloid | grep -A5 TLS
```

---

## Image pull errors

```bash
kubectl describe pod -n cycloid <pod-name> | grep -A5 "Failed to pull"
```

**Common causes:**

- **imagePullSecrets not configured:** Cycloid images are in a private registry. Ensure
  `imagePullSecrets` is set in `values.custom.yaml`:
  ```yaml
  imagePullSecrets:
    - name: cycloid-registry-credentials
  ```
  And the secret exists:
  ```bash
  kubectl get secret -n cycloid cycloid-registry-credentials
  ```

- **Image tag does not exist:** Verify the tag with the Cycloid support team.

- **Rate limiting on Docker Hub:** Some subchart images are pulled from Docker Hub. Use a
  registry mirror or configure `imagePullSecrets` with Docker Hub credentials.

- **Network policy blocking egress to registry:** Check whether a NetworkPolicy restricts
  pod egress and whitelist the registry CIDR or DNS if needed.
