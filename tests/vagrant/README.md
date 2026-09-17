# Local VM acceptance tests

This harness proves that a generated Cycloid POC archive installs on the current
Debian and Ubuntu releases in real systemd VMs. It intentionally complements the
legacy Molecule scenarios: Docker-in-Docker cannot exercise guest boot, host
firewall rules, Docker bridge-to-host routing, or reboot recovery.

The version-pinned matrix is in `matrix.json`. Updating an OS box is a reviewed
test change because Vagrant does not update an existing VM when a box changes.
The current matrix uses Debian 13 and Ubuntu 26.04 LTS with libvirt.

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

Run both operating systems with the current checkout overlaid into the supplied
archive:

```sh
python3 tests/vagrant/run.py test \
  --archive /absolute/path/to/cycloid-onprem.tar \
  --os all \
  --source checkout
```

Use `--source archive` to test the role bundled in the archive without an
overlay. `--os debian` and `--os ubuntu` select one lane. VMs are sequential and
destroyed after collection by default; `--keep` retains them for diagnosis.

Each lane performs a clean install, certificate/service/API/authenticated SQL
checks, a safe convergence rerun, a real guest reboot, and the same checks after
reboot. JUnit output and diagnostics are written below
`tests/vagrant/.work/RUN_ID/`.

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
