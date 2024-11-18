#! /usr/bin/env bash

check() {
  set -o pipefail
  state='Unknown'

  echo "Waiting for backend ${CY_API_URL} to be ready"
  until [ "$state" == "Success" ]; do
    code="$(curl -Ssko status.json -w '%{http_code}' ${CY_API_URL}/status)"
    case "$code" in
    404)
      echo "API unreachable, response code: ${code}."
      sleep 2
      continue
      ;;
    esac

    jq_query='[.data.checks[] | select(.canonical == "pipeline" or .canonical == "database" or .canonical == "secret" and .status == "Success")] | length'

    services_up=$(jq -r "${jq_query}" status.json 2>/dev/null || echo "0")
    if [ "${services_up}" -lt "3" ]; then
      jq -r '.data.checks[] | select(.canonical == "pipeline" or .canonical == "database" or .canonical == "secret") | "\(.canonical): \(.status)"' status.json 2>/dev/null ||
        echo "State of the backend is unknown, response code: ${code}."
      state="Down"
    else
      echo "Backend ${CY_API_URL} is ready"
      state="Success"
    fi

    sleep 2
  done
  exit 0
}

export -f check

case "$ENV" in
prod)
  export CY_API_URL="https://http-api.cycloid.io"
  ;;
staging)
  export CY_API_URL="https://api.staging.cycloid.io/status"
  ;;
*)
  export CY_API_URL="https://api-${ENV}.staging.cycloid.io"
  ;;
esac

timeout "${TIMEOUT:-4}" bash -c check || {
  echo "Backend readiness for ${CY_API_URL} has timeout, check cycloid-backend ${ENV}"
  exit 1
}
