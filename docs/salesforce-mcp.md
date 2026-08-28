# Salesforce MCP server

Connects this project to Salesforce via the Salesforce-hosted MCP
endpoint:

```
https://api.salesforce.com/platform/mcp/v1/platform/sobject-all
```

Registered in `.mcp.json` as `salesforce-platform`. It is a remote HTTP
MCP server — nothing runs locally, and no Salesforce CLI is involved.

## What the endpoint expects

Verified reachable from a session container. Unauthenticated requests
return `401 {"errors":[{"message":"JWT Token is required"}]}`; a bogus
bearer returns `401 Invalid token`. It publishes standard OAuth
discovery:

`https://api.salesforce.com/.well-known/oauth-protected-resource`

```json
{
  "resource": "https://api.salesforce.com",
  "authorization_servers": ["https://login.salesforce.com"],
  "scopes_supported": ["api", "sfap_api", "refresh_token", "einstein_gpt_api"]
}
```

`https://api.salesforce.com/.well-known/oauth-authorization-server`

```json
{
  "issuer": "https://login.salesforce.com",
  "authorization_endpoint": "https://login.salesforce.com/services/oauth2/authorize",
  "token_endpoint": "https://login.salesforce.com/services/oauth2/token",
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "token_endpoint_auth_methods_supported": ["client_secret_post"],
  "code_challenge_methods_supported": ["S256"]
}
```

## Recommended: let Claude Code run the OAuth flow

Because the endpoint publishes discovery metadata and supports
`authorization_code` + `refresh_token` + PKCE, Claude Code can own the
whole token lifecycle, refresh included:

```bash
claude mcp add --transport http salesforce-platform \
  https://api.salesforce.com/platform/mcp/v1/platform/sobject-all
# then, in session:  /mcp  ->  authenticate
```

The consent step needs a browser, so run it from a local Claude Code
session rather than a headless web container.

## Fallback: static bearer token

`.mcp.json` expands `${SF_ACCESS_TOKEN}` from the environment, so setting
that variable before the session starts also works. The token is not
refreshed — when it expires the server starts returning `Invalid token`
and you have to set a new one and restart the session.

`scripts/sf-token.sh` mints one from a connected app using the client
credentials flow:

```bash
export SF_CLIENT_ID=...        # connected app consumer key
export SF_CLIENT_SECRET=...    # connected app consumer secret
export SF_ACCESS_TOKEN="$(./scripts/sf-token.sh)"
```

Set the client id/secret as environment variables on the Claude Code
environment rather than pasting them into a session transcript. Never
commit them.

**Untested caveat:** the authorization server metadata above lists only
`authorization_code` and `refresh_token`. It does *not* list
`client_credentials`, so a token from `scripts/sf-token.sh` may be
rejected by `api.salesforce.com` even though it authenticates fine
against the org's own REST API at
`https://cutarellivision.my.salesforce.com`. Verify before relying on it.
The `sfap_api` scope is likely required in addition to `api`.

### Connected app requirements for this fallback

In Setup → App Manager → your connected app → Edit:

- **Enable Client Credentials Flow** checked.
- A **Run As** user set (Manage → Edit Policies → Client Credentials
  Flow). Every MCP call runs with that user's permissions and sharing.
- OAuth scopes include `api` and `sfap_api`.
- IP relaxation set so the container's egress address is not blocked, or
  the run-as user's profile has "Login IP Ranges" left open.
