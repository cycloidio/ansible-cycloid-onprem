#!/bin/bash
set -e

# Keep the error status code with | tee
set -o pipefail

LOGFILE=/tmp/cycloid-install.log

export ANSIBLE_FORCE_COLOR="true"

function check-requirements {
  # check OS
  cat /etc/issue >> $LOGFILE
  cat /etc/os-release >> $LOGFILE
}

function init {

  check-requirements

  if [ -z "$CYCLOID_CONSOLE_DNS" ]; then
    read -p 'CYCLOID_CONSOLE_DNS: ' domain
    export CYCLOID_CONSOLE_DNS=$domain
  fi

  ## Installation packages
  apt-get update | tee -a $LOGFILE
  apt-get install build-essential python3-dev python3-pip python3-venv -y | tee -a $LOGFILE

  ### Common tasks

  # if dns doesn't resolv, add entry to /etc/hosts
  set +e
  ping $CYCLOID_CONSOLE_DNS -c 1 -s 16
  if [ "$?" -ne 0 ]
  then
     echo "127.0.0.1 $CYCLOID_CONSOLE_DNS" | tee -a /etc/hosts
  fi
  set -e

  sed -i "s/@CYCLOID_CONSOLE_DNS@/$CYCLOID_CONSOLE_DNS/" environments/cycloid.yml

  ### Python requirements

  python3 -m venv venv | tee -a $LOGFILE
  source venv/bin/activate
  python3 -m pip install --upgrade pip | tee -a $LOGFILE
  python3 -m pip install -U -r pip-requirements.txt | tee -a $LOGFILE
}

function install-cycloid {
  source venv/bin/activate

  # Because we are using -c local
  # we don't initialisated a new tty
  # Ensure we use system python interpreteur and not virtualenv with desactivate
  # Else you have issue between pip system module and virtualenv. All ansible module doesn't use properly the library installer under venv
  ANSIBLE_PLAYBOOK=$(which ansible-playbook)
  deactivate

  #export ANSIBLE_PYTHON_INTERPRETER=$(which python3)
  export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

  echo "$ANSIBLE_PLAYBOOK -c local -i inventory playbook.yml"
  $ANSIBLE_PLAYBOOK -c local -i inventory playbook.yml | tee -a $LOGFILE
}

function install-worker {
  source venv/bin/activate
  ANSIBLE_PLAYBOOK=$(which ansible-playbook)
  deactivate

  export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

  echo "$ANSIBLE_PLAYBOOK -c local -i inventory worker.yml"
  $ANSIBLE_PLAYBOOK -c local -i inventory worker.yml | tee -a $LOGFILE
}

function display-access {
  grep -E "^(cycloid_console_dns| +email| +password)" environments/cycloid.yml
}

function uninstall-cycloid {
  source venv/bin/activate
  ANSIBLE_PLAYBOOK=$(which ansible-playbook)
  deactivate
  export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

  echo "$ANSIBLE_PLAYBOOK -c local -i inventory -e uninstall=True playbook.yml"
  $ANSIBLE_PLAYBOOK -c local -i inventory -e uninstall=True playbook.yml | tee -a $LOGFILE
}

function report {
  source venv/bin/activate
  ANSIBLE_PLAYBOOK=$(which ansible-playbook)
  deactivate
  export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

  echo "$ANSIBLE_PLAYBOOK -c local -i inventory report.yml"
  $ANSIBLE_PLAYBOOK -c local -i inventory report.yml | tee -a $LOGFILE
}

function help {
   # Display Help
   echo "Cycloid POC helper script."
   echo
   echo "Syntax: helper.sh [install|install-cycloid|install-worker|reinstall-cycloid|uninstall-cycloid|report|help]"
   echo "options:"
   echo "install              Install requirements, Cycloid and pipeline worker."
   echo "install-cycloid      Install Cycloid only."
   echo "install-worker       Install pipeline worker only."
   echo "reinstall-cycloid    Reinstall Cycloid (uninstall+install)."
   echo "uninstall            Uninstall Cycloid."
   echo "report               Generate a report to share with Cycloid team."
   echo
}

############################################################
# MAIN
############################################################

if [ $# -eq 0 ]; then
    echo "No argument provided"
    help
    exit 1
fi

case "$1" in
  "install")
    init
    install-cycloid
    install-worker
    display-access
    ;;
  "install-cycloid")
    install-cycloid
    display-access
    ;;
  "install-worker")
    install-worker
    display-access
    ;;
  "uninstall")
    uninstall-cycloid
    ;;
  "reinstall-cycloid")
    uninstall-cycloid
    install-cycloid
    display-access
    ;;
  "report")
    report
    ;;
  "help")
    help
    ;;

  *)
    echo "Wrong argument provided."
    help
    exit 1
    ;;
esac
