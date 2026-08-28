#!/usr/bin/env bash
# SessionStart hook: make the Salesforce MCP server usable in a fresh
# Claude Code on the web container, which starts with no global npm
# packages and no CLI auth.
set -euo pipefail

command -v sf-mcp-server >/dev/null 2>&1 \
  || npm install -g @salesforce/cli @salesforce/mcp >/dev/null 2>&1

if [[ -n "${SF_CLIENT_ID:-}" && -n "${SF_CLIENT_SECRET:-}" ]]; then
  "$(dirname "$0")/../scripts/sf-connect.sh" >/dev/null 2>&1 \
    && echo "Salesforce org 'cutarellivision' authenticated." \
    || echo "Salesforce auth failed; run scripts/sf-connect.sh to see why."
else
  echo "SF_CLIENT_ID / SF_CLIENT_SECRET not set; Salesforce MCP will start unauthenticated."
fi
