#!/usr/bin/env bash
# Mint a Salesforce access token via the OAuth 2.0 client credentials flow
# and print it, for use as SF_ACCESS_TOKEN by the salesforce-platform MCP
# server in .mcp.json.
#
# Only needed for the static-bearer fallback. The preferred route is
# `claude mcp add --transport http` plus the /mcp consent flow, which lets
# Claude Code handle refresh itself. See docs/salesforce-mcp.md.
#
# Requires SF_CLIENT_ID and SF_CLIENT_SECRET (consumer key/secret of a
# connected app with "Enable Client Credentials Flow" checked and a run-as
# user assigned).
#
# Usage:  export SF_ACCESS_TOKEN="$(./scripts/sf-token.sh)"
set -euo pipefail

INSTANCE_URL="${SF_INSTANCE_URL:-https://cutarellivision.my.salesforce.com}"

if [[ -z "${SF_CLIENT_ID:-}" || -z "${SF_CLIENT_SECRET:-}" ]]; then
  echo "sf-token: SF_CLIENT_ID and SF_CLIENT_SECRET must be set." >&2
  exit 1
fi

response="$(curl -sS --fail-with-body -X POST "${INSTANCE_URL}/services/oauth2/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_id=${SF_CLIENT_ID}" \
  --data-urlencode "client_secret=${SF_CLIENT_SECRET}")"

printf '%s' "$response" | node -e \
  'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const j=JSON.parse(d);if(!j.access_token){console.error(d);process.exit(1)}process.stdout.write(j.access_token)})'
