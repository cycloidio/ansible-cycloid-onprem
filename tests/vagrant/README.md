# Local VM acceptance tests

This harness proves that a generated Cycloid POC archive installs on the current
Debian and Ubuntu releases in real systemd VMs. It intentionally complements the
legacy Molecule scenarios: Docker-in-Docker cannot exercise guest boot, host
firewall rules, Docker bridge-to-host routing, or reboot recovery.

The version-pinned matrix is in `matrix.json`. Updating an OS box is a reviewed
test change because Vagrant does not update an existing VM when a box changes.

| Key | Distribution | Box | Pinned version |
|---|---|---|---|
| `debian12` | Debian 12 | `cloud-image/debian-12` | `20260909.2596.0` |
| `debian13` | Debian 13 | `cloud-image/debian-13` | `20260914.2601.0` |
| `ubuntu2404` | Ubuntu 24.04 LTS | `cloud-image/ubuntu-24.04` | `20260911.0.0` |
| `ubuntu2604` | Ubuntu 26.04 LTS | `cloud-image/ubuntu-26.04` | `20260823.0.0` |

All four machines use the libvirt provider.

## Prerequisites

- Vagrant 2.4 or newer
- the `vagrant-libvirt` plugin
- readable system libvirt (`qemu:///system`) and working KVM acceleration
- at least 4 vCPUs, 12 GiB RAM, and 60 GiB sparse disk capacity per sequential VM
- a freshly generated `cycloid-onprem.tar` archive with test-only credentials

Run the read-only checks first:

```sh
python3 tests/vagrant/run.py preflight
```

Run the full OS matrix with the current checkout overlaid into the supplied
archive:

```sh
python3 tests/vagrant/run.py test \
  --archive /absolute/path/to/cycloid-onprem.tar \
  --os all \
  --source checkout
```

Use `--source archive` to test the role bundled in the archive without an
overlay. `--os` accepts `all`, a single matrix key (e.g. `--os debian12`), or a
comma-separated list of matrix keys (e.g. `--os debian12,ubuntu2404`). VMs are
sequential and destroyed after collection by default; `--keep` retains them for
diagnosis.

Each lane performs a clean install, certificate/service/API/authenticated SQL
checks, a safe convergence rerun, a real guest reboot, and the same checks after
reboot. JUnit output and diagnostics are written below
`tests/vagrant/.work/RUN_ID/`.

### Upgrade lane

Add `--upgrade-archive` to exercise an in-place upgrade on top of the primary
install, in the same guest: the harness uploads the second archive, replays the
install flow from it (optionally overlaid with the current checkout via
`--upgrade-source checkout`, default `archive`), then verifies and reboots a
second time. This adds the `upload-upgrade-archive`,
`upload-upgrade-candidate` (checkout only), `upgrade-install`,
`verify-post-upgrade`, `collect-post-upgrade`, `reboot-2`, and
`verify-post-upgrade-reboot` junit testcases per machine.

```sh
python3 tests/vagrant/run.py test \
  --archive /absolute/path/to/cycloid-onprem-broken.tar \
  --os debian12 \
  --source archive \
  --upgrade-archive /absolute/path/to/cycloid-onprem.tar \
  --upgrade-source checkout \
  --tolerate-initial-failure
```

`--tolerate-initial-failure` records a failure in `verify-initial`, `rerun`,
`verify-post-rerun`, `reboot`, or `verify-post-reboot` as a junit failure
without aborting the lane — every primary phase still gets attempted, and (if
the guest stayed reachable, i.e. `install`/`ssh-config` succeeded) the upgrade
lane still runs afterwards. Without this flag, a primary-phase failure stops
the lane at that phase as before, and the upgrade lane is skipped. Upgrade-lane
phases themselves are always sequential/gated: a failure in
`upload-upgrade-archive`, `upgrade-install`, `verify-post-upgrade`, or
`reboot-2` skips the remaining upgrade phases for that machine.

Raw Ansible/Vagrant logs and the generated candidate archive may contain
credentials. The run directory and its files are mode-restricted and ignored by
Git. Publish only `junit.xml` and the sanitized `artifacts/` directory. Never
publish `raw/`, `config.json`, a POC archive, SSH state, or guest environment
files.

For a retained run:

```sh
python3 tests/vagrant/run.py collect --run RUN_ID --phase manual
python3 tests/vagrant/run.py destroy --run RUN_ID
```

Runner unit tests do not require Vagrant:

```sh
python3 -m unittest discover -s tests/vagrant/unit -v
```
