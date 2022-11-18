#!/usr/bin/env bash
set -e

FLY=/usr/local/bin/fly

URL=$1
DATA=$(echo $URL | sed -ne 's/.*organizations\/\([^\/]\+\).*pipelines\/\([^\/]\+\).*jobs\/\([^\/]\+\).*/\1\ \2 \3/p')
RS_TYPE=job

if [ -z "$DATA" ]
then
  # Not a jobs url. Try resource

  DATA=$(echo $URL | sed -ne 's/.*organizations\/\([^\/]\+\).*pipelines\/\([^\/]\+\).*resources\/\([^\/#]\+\).*/\1\ \2 \3/p')
  RS_TYPE=resource
fi

ORG=$(echo $DATA | awk '{print $1}')
PIPE=$(echo $DATA | awk '{print $2}')
JOB=$(echo $DATA | awk '{print $3}')

function flylogin {
  org=$1

  if ! type "mysql" > /dev/null; then
    echo "mysql-client need to be installed"
    exit 1
  fi

  # Get concourse and mysql access
  eval $(grep 'MYSQL\|CONCOURSE' /etc/default/cycloid-api)

  # Get the teamId from org name (mysql)
  REQUEST="select team_name from concourse_accounts where organization_id = (select id from organizations where canonical='${org}');"
  TEAM=$(echo $REQUEST | mysql --protocol=TCP -u$MYSQL_USER -p$MYSQL_PASSWORD -h $YOUDEPLOY_MYSQL_SERVICE_HOST --database $MYSQL_DATABASE 2>/dev/null | tail -n1)
  # tail -n1 to remove field name (connect doesnt have --silence yet)
  echo "fly login $org"

  CCURL="${CONCOURSE_URL}:${CONCOURSE_PORT}"

  # Get fly cli
  if [ ! -f $FLY ]; then
      curl -k "$CCURL/api/v1/cli?arch=amd64&platform=linux" --output $FLY
      chmod +x $FLY
  fi

  echo "concourse URL: $CCURL"
  $FLY --target ${ORG} login --insecure -n ${TEAM} --concourse-url ${CCURL} -k -u ${CONCOURSE_USER} -p ${CONCOURSE_PASSWORD}
  $FLY --target ${org} sync 1>/dev/null
}

function flyhijack {
  org=$1
  hij=$2
  set -x
  if [ "$RS_TYPE" == "job" ]; then
    $FLY --target $org hijack -j $hij sh
  else
    $FLY --target $org hijack -c $hij sh
  fi
}

############
### Main ###
############

if [ $# -lt 1 ]
  then
    echo "Give a cycloid build url

    $0 <https://cycloid-build-url>"
    exit 0
fi

echo "org: $ORG"
echo "pipeline: $PIPE"
echo "job: $JOB"

flylogin $ORG
HIJ="${PIPE}/${JOB}"
flyhijack $ORG $HIJ
