# Salesforce MCP server

Connects this project to the Salesforce org at
`https://cutarellivision.lightning.force.com`
(API host: `https://cutarellivision.my.salesforce.com`) via the official
[Salesforce DX MCP server](https://github.com/salesforcecli/mcp).

## Pieces

| File | Role |
| --- | --- |
| `.mcp.json` | Registers the `salesforce` MCP server (`sf-mcp-server`) for the project. |
| `scripts/sf-connect.sh` | Gets an access token via the OAuth 2.0 client credentials flow and stores it in the Salesforce CLI auth store. |
| `.claude/session-start.sh` | SessionStart hook: installs the CLI + MCP server and runs `sf-connect.sh` in fresh web containers. |

The MCP server does not talk OAuth itself — it reads orgs out of the
Salesforce CLI auth store. So the CLI has to be authenticated *before* the
server starts.

## Connected app requirements

In Setup → App Manager → your connected app → Edit:

- **Enable Client Credentials Flow** checked.
- A **Run As** user set (Manage → Edit Policies → Client Credentials Flow).
  Every MCP call runs with that user's permissions and sharing.
- OAuth scopes include `api` (and `refresh_token` is not needed — the
  client credentials flow does not issue one).
- IP relaxation set so the container's egress address is not blocked, or
  the run-as user's profile has "Login IP Ranges" left open.

## Credentials

`scripts/sf-connect.sh` reads two environment variables:

- `SF_CLIENT_ID` — the connected app's consumer key
- `SF_CLIENT_SECRET` — the connected app's consumer secret

Optional overrides: `SF_INSTANCE_URL`, `SF_ORG_ALIAS`.

Set these as environment variables on the Claude Code environment rather
than pasting them into a session transcript. Never commit them.

## Manual run

```bash
npm install -g @salesforce/cli @salesforce/mcp
export SF_CLIENT_ID=...
export SF_CLIENT_SECRET=...
./scripts/sf-connect.sh          # prints org details on success
```

## Token lifetime

The client credentials flow returns a bare access token with no refresh
token. When it expires, re-run `scripts/sf-connect.sh`. Containers are
ephemeral, so in practice each new session re-authenticates from scratch
via the SessionStart hook.
