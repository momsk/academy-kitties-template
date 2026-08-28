#!/usr/bin/env bash
# Authenticate the Salesforce CLI against the org using the OAuth 2.0
# client credentials flow, so the Salesforce MCP server can reach it.
#
# Requires SF_CLIENT_ID and SF_CLIENT_SECRET (consumer key/secret of the
# connected app, which must have "Enable Client Credentials Flow" checked
# and a run-as user assigned).
set -euo pipefail

INSTANCE_URL="${SF_INSTANCE_URL:-https://cutarellivision.my.salesforce.com}"
ORG_ALIAS="${SF_ORG_ALIAS:-cutarellivision}"

if [[ -z "${SF_CLIENT_ID:-}" || -z "${SF_CLIENT_SECRET:-}" ]]; then
  echo "sf-connect: SF_CLIENT_ID and SF_CLIENT_SECRET must be set." >&2
  exit 1
fi

response="$(curl -sS --fail-with-body -X POST "${INSTANCE_URL}/services/oauth2/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_id=${SF_CLIENT_ID}" \
  --data-urlencode "client_secret=${SF_CLIENT_SECRET}")"

token="$(printf '%s' "$response" | node -e \
  'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const j=JSON.parse(d);if(!j.access_token){console.error(d);process.exit(1)}process.stdout.write(j.access_token)})')"

SF_ACCESS_TOKEN="$token" sf org login access-token \
  --instance-url "$INSTANCE_URL" \
  --alias "$ORG_ALIAS" \
  --set-default \
  --no-prompt

sf org display --target-org "$ORG_ALIAS"
