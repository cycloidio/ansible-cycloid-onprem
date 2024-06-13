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
  apt-get install build-essential python3-dev python3-pip python3-venv unzip -y | tee -a $LOGFILE

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

  # Restart BE to make sur BE-worker is running
  systemctl restart cycloid-api_container
}

function install-worker {
  source venv/bin/activate
  ANSIBLE_PLAYBOOK=$(which ansible-playbook)
  deactivate

  export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

  # Temporary until schedule use 7 version.
  # Update worker to fix cgroup2 issue on debian 11
  sed -i 's/concourse_version: ".*"/concourse_version: "7.8.2"/g' environments/cycloid.yml
  echo "concourse_worker_runtime: containerd" >> environments/cycloid.yml

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

function force-user-email-validation {
  source venv/bin/activate
  ANSIBLE_PLAYBOOK=$(which ansible-playbook)
  deactivate

  export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

  echo "$ANSIBLE_PLAYBOOK -c local -i inventory mysql-force-user-email-validation.yml"
  $ANSIBLE_PLAYBOOK -c local -i inventory mysql-force-user-email-validation.yml | tee -a $LOGFILE

  # Auto validate user signup and invite to main org (with custom role 5)
  # if mysql installed
  # source  /etc/default/cycloid-api
  # ROLEID=5
  # mysql --protocol=TCP -u$DB_USER -p$DB_PWD -h $DB_HOST --database $DB_NAME -e "select * from user_emails where verification_token is not NULL;" -Ns
  # for u in $(mysql --protocol=TCP -u$DB_USER -p$DB_PWD -h $DB_HOST --database $DB_NAME -e "select user_id from user_emails where verification_token is not NULL;" -Ns);do
  #   echo "user $u"
  #   # valide user
  #   mysql --protocol=TCP -u$DB_USER -p$DB_PWD -h $DB_HOST --database $DB_NAME -e "update user_emails set verification_token=NULL;" -Ns
  #   # invite user
  #   mysql --protocol=TCP -u$DB_USER -p$DB_PWD -h $DB_HOST --database $DB_NAME -e "INSERT INTO users_organizations_roles (organization_id, role_id, user_id) VALUES (1, $ROLEID, ${u})" -Ns
  # done
}

function force-pay-orgs {
  source venv/bin/activate
  ANSIBLE_PLAYBOOK=$(which ansible-playbook)
  deactivate

  export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3

  echo "$ANSIBLE_PLAYBOOK -c local -i inventory mysql-force-pay-orgs.yml"
  $ANSIBLE_PLAYBOOK -c local -i inventory mysql-force-pay-orgs.yml | tee -a $LOGFILE
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
   echo "Syntax: helper.sh [install|install-cycloid|install-worker|reinstall-cycloid|uninstall-cycloid|force-user-email-validation|force-pay-orgs|report|help]"
   echo "options:"
   echo "install                        Install requirements, Cycloid and pipeline worker."
   echo "install-cycloid                Install Cycloid only."
   echo "install-worker                 Install pipeline worker only."
   echo "reinstall-cycloid              Reinstall Cycloid (uninstall+install)."
   echo "uninstall                      Uninstall Cycloid."
   echo "force-user-email-validation    Valide newly created users on Cycloid"
   echo "force-pay-orgs                 Unblock newly created organizations on Cycloid"
   echo "report                         Generate a report to share with Cycloid team."
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
  "force-user-email-validation")
    force-user-email-validation
    ;;
  "force-pay-orgs")
    force-pay-orgs
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
