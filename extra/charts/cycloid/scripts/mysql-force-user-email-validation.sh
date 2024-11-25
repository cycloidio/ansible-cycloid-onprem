#!/bin/bash

if [ -z "$NAMESPACE" ]
then
      echo 'Make sure to defined export NAMESPACE='
fi

echo "\e[36m# $0 > Mysql - Force user email validation\e[0m"

kubectl -n $NAMESPACE exec -i -t cycloid-mysql-0 -- bash -c 'mysql --protocol=TCP -u$MYSQL_USER -p$MYSQL_PASSWORD  $MYSQL_DATABASE -e "update user_emails set verification_token=NULL;" 2>/dev/null'
