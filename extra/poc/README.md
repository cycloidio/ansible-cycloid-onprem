# helper

Script used to setup [onprem-poc](https://docs.cycloid.io/onprem/onprem-poc.html) from an archive created by [cycloid-onprem-subscription stack](https://github.com/cycloidio/cycloid-stacks/tree/stacks/cycloid-onprem-subscription)

```
bash helper.sh

Cycloid POC helper script.

Syntax: helper.sh [install|install-cycloid|install-worker|reinstall-cycloid|uninstall-cycloid|report|help]
options:
install              Install requirements, Cycloid and pipeline worker.
install-cycloid      Install Cycloid only.
install-worker       Install pipeline worker only.
reinstall-cycloid    Reinstall Cycloid (uninstall+install).
uninstall            Uninstall Cycloid.
report               Generate a report to share with Cycloid team.
```
