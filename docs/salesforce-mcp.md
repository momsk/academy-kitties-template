# Salesforce MCP servers

Two independent routes to the org at
`https://cutarellivision.lightning.force.com`
(API host: `https://cutarellivision.my.salesforce.com`). They are
complementary, not alternatives — keep whichever you use and delete the
other from `.mcp.json`.

| | `salesforce` (local) | `salesforce-platform` (hosted) |
| --- | --- | --- |
| What | [Salesforce DX MCP server](https://github.com/salesforcecli/mcp), runs locally over stdio | Salesforce-hosted MCP endpoint over HTTP |
| Endpoint | `sf-mcp-server` process | `https://api.salesforce.com/platform/mcp/v1/platform/sobject-all` |
| Covers | metadata, deploy/retrieve, Apex tests, users, code analysis | sObject data access |
| Auth | Salesforce CLI auth store | OAuth bearer token |
| Needs local install | yes (`@salesforce/cli`, `@salesforce/mcp`) | no |

## Hosted endpoint (`salesforce-platform`)

Verified reachable from a session container. Unauthenticated requests
return `401 {"errors":[{"message":"JWT Token is required"}]}`; a bogus
bearer returns `401 Invalid token`. It advertises standard OAuth
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
advertises `authorization_code` + `refresh_token`, `client_secret_post`,
and PKCE `S256`.

### Recommended: let Claude Code run the OAuth flow

Because the endpoint publishes discovery metadata and supports
`authorization_code` + `refresh_token` + PKCE, Claude Code can own the
whole token lifecycle, including refresh:

```bash
claude mcp add --transport http salesforce-platform \
  https://api.salesforce.com/platform/mcp/v1/platform/sobject-all
# then, in session:  /mcp  ->  authenticate
```

This needs a browser for the consent step, so run it from a local Claude
Code session rather than a headless web container.

### Fallback: static bearer token

`.mcp.json` expands `${SF_ACCESS_TOKEN}` from the environment. This works
but the token is not refreshed — when it expires the server starts
failing and you have to set a new one and restart the session.

**Untested caveat:** the authorization server metadata lists only
`authorization_code` and `refresh_token` as supported grants. It does
*not* list `client_credentials`, so a token minted by
`scripts/sf-connect.sh` may be rejected by `api.salesforce.com` even
though it works fine against the org's own REST API. Verify before
relying on it. The `sfap_api` scope is likely required in addition to
`api`.

## Local DX server (`salesforce`)

The MCP server does not talk OAuth itself — it reads orgs out of the
Salesforce CLI auth store. So the CLI has to be authenticated *before*
the server starts.

| File | Role |
| --- | --- |
| `scripts/sf-connect.sh` | Gets an access token via the OAuth 2.0 client credentials flow and stores it in the CLI auth store. |
| `.claude/session-start.sh` | SessionStart hook: installs the CLI + MCP server and runs `sf-connect.sh` in fresh web containers. |

### Connected app requirements

In Setup → App Manager → your connected app → Edit:

- **Enable Client Credentials Flow** checked.
- A **Run As** user set (Manage → Edit Policies → Client Credentials Flow).
  Every MCP call runs with that user's permissions and sharing.
- OAuth scopes include `api` (no `refresh_token` — the client credentials
  flow does not issue one).
- IP relaxation set so the container's egress address is not blocked, or
  the run-as user's profile has "Login IP Ranges" left open.

### Credentials

`scripts/sf-connect.sh` reads:

- `SF_CLIENT_ID` — the connected app's consumer key
- `SF_CLIENT_SECRET` — the connected app's consumer secret

Optional overrides: `SF_INSTANCE_URL`, `SF_ORG_ALIAS`.

Set these as environment variables on the Claude Code environment rather
than pasting them into a session transcript. Never commit them.

### Manual run

```bash
npm install -g @salesforce/cli @salesforce/mcp
export SF_CLIENT_ID=...
export SF_CLIENT_SECRET=...
./scripts/sf-connect.sh          # prints org details on success
```

### Token lifetime

The client credentials flow returns a bare access token with no refresh
token. When it expires, re-run `scripts/sf-connect.sh`. Containers are
ephemeral, so in practice each new session re-authenticates from scratch
via the SessionStart hook.
