# Salesforce MCP connection

Salesforce access is provided by the first-party **Salesforce - Beta**
connector in claude.ai, not by anything in this repository. There is no
`.mcp.json` and no setup script — the connector is account-level
configuration, so it applies to every session without any repo wiring.

Org: `https://cutarellivision.lightning.force.com`
(API host: `https://cutarellivision.my.salesforce.com`)

## Setup

All steps work from a browser, including mobile Safari.

A connected app is **required**. Salesforce does not support OAuth
dynamic client registration, so the connector cannot create its own OAuth
client — see [Connected app required](#connected-app-required) below for
why, and configure the app before starting here.

1. claude.ai → Settings → Connectors
2. Add the **Salesforce** connector
3. Open its settings and enter the connected app's **Consumer Key** as
   the OAuth Client ID (plus the Consumer Secret if the field is shown)
4. Authorize it, selecting the `cutarellivision` org at the Salesforce
   login prompt — the OAuth consent screen is what binds the connector to
   a specific org, so pick carefully if you are logged into more than one
5. Enable the connector for the chat or session you want to use it in

### Connected app required

Connecting without a client ID fails with:

```
Couldn't register with Salesforce - Beta's sign-in service.
You can try again, or add an OAuth Client ID in the connector settings.
```

This is expected, not a bug, and retrying cannot fix it.
`https://api.salesforce.com/.well-known/oauth-authorization-server`
publishes no `registration_endpoint`, so RFC 7591 dynamic client
registration has nothing to register against. The OAuth client must be
supplied by hand.

An earlier failure mode, `Failed to start MCP authorization`, comes from
the same cause but gives no useful detail. If the connector record is
left in `installState: "unknown"`, remove and re-add it rather than
retrying on top of the stale record.

Configure the connected app in Setup → App Manager → Edit:

- **Enable OAuth Settings** on. An app built only for the client
  credentials flow will not have this configured, since that flow uses no
  callback.
- **Callback URL** set to the redirect URI shown in the connector's
  settings screen. Copy it from there rather than reproducing it from
  memory; it must match exactly.
- **Selected OAuth Scopes**: `api`, `refresh_token`, and `sfap_api` if
  the org lists it.
- If the connector asks for a client ID but no secret, it is acting as a
  public client: uncheck *Require Secret for Web Server Flow* and
  *Require Secret for Refresh Token Flow*, and check *Require Proof Key
  for Code Exchange (PKCE)*.

Connected app changes take several minutes to propagate. Retrying
immediately produces a failure indistinguishable from the original one.

Credentials come from App Manager → View → **Manage Consumer Details**.

A connector can show as connected at the account level while still being
toggled off for an individual chat, in which case its tools are not
loaded. If the tools do not appear, check the per-chat connector
settings.

Tools exposed: `describe`, `discover`, `dispatch`, `dispatch_readonly`.

## Notes

- On a managed or enterprise Claude account, an admin may need to approve
  the connector before it can be added.
- A Salesforce admin may need to permit the Claude connected app in the
  org.

## Alternatives considered

Two other routes were evaluated and rejected. Both work, but each costs
setup that the first-party connector does not.

### Hosted platform endpoint as a custom connector

`https://api.salesforce.com/platform/mcp/v1/platform/sobject-all` is a
live OAuth-protected MCP server. Unauthenticated requests return
`401 {"errors":[{"message":"JWT Token is required"}]}`; a bogus bearer
returns `401 Invalid token`. It publishes discovery at
`/.well-known/oauth-protected-resource` and
`/.well-known/oauth-authorization-server`:

```
authorization_servers:   https://login.salesforce.com
scopes_supported:        api, sfap_api, refresh_token, einstein_gpt_api
grant_types_supported:   authorization_code, refresh_token
code_challenge_methods:  S256
registration_endpoint:   (absent)
```

No `registration_endpoint` means no dynamic client registration, so
adding it as a claude.ai custom connector requires supplying a connected
app's OAuth client ID and secret, plus adding claude.ai's redirect URI to
that connected app's callback URLs and granting it `api`, `sfap_api`, and
`refresh_token`.

Its tool surface is limited to sObject access, which the first-party
connector's `dispatch` already covers.

### Local Salesforce DX MCP server

[`@salesforce/mcp`](https://github.com/salesforcecli/mcp) run over stdio,
authenticated through the Salesforce CLI auth store. This covers more
ground than the hosted endpoint — metadata, deploy/retrieve, Apex tests,
code analysis — but requires installing `@salesforce/cli` and
`@salesforce/mcp` in every session container and authenticating the CLI
before the server starts. Worth revisiting if metadata or deployment
tooling is ever needed; it is the only one of the three that provides it.

Note that the client credentials flow, which is the practical way to
authenticate the CLI headlessly, returns no refresh token, so each
session has to re-authenticate.
