#!/bin/bash
set -e

# Keep the error status code with | tee
set -o pipefail

LOGFILE=/tmp/cycloid-install.log

export ANSIBLE_FORCE_COLOR="true"

ANSIBLE_USER=admin

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
  export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3
  python3 -m pip install --upgrade pip | tee -a $LOGFILE
  python3 -m pip install -U -r pip-requirements.txt | tee -a $LOGFILE
}

function install-cycloid {
  source venv/bin/activate
  export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

  echo "ansible-playbook -u $ANSIBLE_USER -c local -b -i inventory playbook.yml"
  ansible-playbook -u $ANSIBLE_USER -c local -b -i inventory playbook.yml | tee -a $LOGFILE
}

function install-worker {
  source venv/bin/activate
  export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

  echo "ansible-playbook -u $ANSIBLE_USER -c local -b -i inventory worker.yml"
  ansible-playbook -u $ANSIBLE_USER -c local -b -i inventory worker.yml | tee -a $LOGFILE
}

function uninstall-cycloid {
  source venv/bin/activate
  export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

  echo "ansible-playbook -u $ANSIBLE_USER -c local -b -i inventory -e uninstall=True playbook.yml"
  ansible-playbook -u $ANSIBLE_USER -c local -b -i inventory -e uninstall=True playbook.yml | tee -a $LOGFILE
}

function report {
  source venv/bin/activate
  export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

  echo "ansible-playbook -u $ANSIBLE_USER -c local -b -i inventory report.yml"
  ansible-playbook -u $ANSIBLE_USER -c local -b -i inventory report.yml | tee -a $LOGFILE
}

function help {
   # Display Help
   echo "Cycloid POC helper script."
   echo
   echo "Syntax: helper.sh [install|install-cycloid|install-worker|reinstall-cycloid|uninstall-cycloid|report|help]"
   echo "options:"
   echo "install              Install requirements, Cycloid and pipeline worker."
   echo "install-cycloid      Install Cycloid."
   echo "install-worker       Install pipeline worker."
   echo "reinstall-cycloid    Reinstall Cycloid."
   echo "uninstall            Uninstall Cycloid."
   echo "report               Generate a report to share with Cycloid team."
   echo
}

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
    ;;
  "install-cycloid")
    install-cycloid
    ;;
  "install-worker")
    install-worker
    ;;
  "uninstall")
    uninstall-cycloid
    ;;
  "reinstall-cycloid")
    uninstall-cycloid
    install-cycloid
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
