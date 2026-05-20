# Roblox Error Bridge

Cloudflare Worker bridge for `POST /roblox-error`.

## What it does

- accepts Roblox `ErrorReporter` payloads
- validates a shared secret from the request header
- searches GitHub Issues by `errorCode`
- creates a new issue if no matching issue exists
- updates the existing issue body plus adds a comment when the issue already exists
- creates labels when possible and skips label failures without crashing
- returns readable JSON errors and logs

## Required environment variables

- `GITHUB_TOKEN`
- `GITHUB_OWNER`
- `GITHUB_REPO`
- `ROBLOX_ERROR_SECRET`

`GITHUB_TOKEN` needs repo issue permissions for the target repository.

## Expected request

- method: `POST`
- path: `/roblox-error`
- header: `X-Roblox-Error-Secret: <same secret as ROBLOX_ERROR_SECRET>`
- body: JSON payload from Roblox `ErrorReporter`

## Cloudflare Worker deploy

1. Log in to Cloudflare:

```powershell
npx wrangler login
```

2. From `backend/roblox-error-bridge`, create local dev vars if needed:

```powershell
Copy-Item .dev.vars.example .dev.vars
```

3. Set production secrets:

```powershell
npx wrangler secret put GITHUB_TOKEN
npx wrangler secret put GITHUB_OWNER
npx wrangler secret put GITHUB_REPO
npx wrangler secret put ROBLOX_ERROR_SECRET
```

4. Deploy:

```powershell
npx wrangler deploy
```

After deploy, your endpoint will be:

```text
https://<your-worker-subdomain>/roblox-error
```

## Local development

```powershell
npx wrangler dev
```

## Roblox configuration

Paste the Worker URL into both files:

- `Level/ServerScriptService/Services/ErrorReporter.lua`
- `Four Peaks/ServerScriptService/Services/ErrorReporter.lua`

Set:

- `GITHUB_BRIDGE_URL = "https://<your-worker-subdomain>/roblox-error"`

Paste the same shared secret into both files:

- `GITHUB_BRIDGE_SECRET = "your-shared-secret"`

That secret must match backend env:

- `ROBLOX_ERROR_SECRET`

## Vercel note

If you prefer Vercel instead of Cloudflare Worker, keep the same route contract:

- `POST /roblox-error`
- same four environment variables
- same `X-Roblox-Error-Secret` header

This repo ships a ready Cloudflare Worker target because it is the smallest deploy surface for the current bridge.

## GitHub issue behavior

Issue title:

```text
[TD2-ERR-XXXXXXXX] ScriptName error in PlaceName
```

Labels:

- `roblox-error`
- `auto-report`
- `place:level` or `place:lobby`
- `system:<systemName>`

If the issue exists, the bridge:

- updates the issue body
- updates tracked occurrences in hidden metadata
- posts a comment with latest occurrence count, last seen, place name, and job id

## Example curl

```powershell
curl -X POST "https://<your-worker-subdomain>/roblox-error" `
  -H "Content-Type: application/json" `
  -H "X-Roblox-Error-Secret: your-shared-secret" `
  -d "{\"source\":\"roblox\",\"errorCode\":\"TD2-ERR-12345678\",\"placeName\":\"Level\",\"scriptName\":\"SpellService\",\"message\":\"test\",\"stackTrace\":\"test\",\"occurrenceCount\":1,\"context\":{\"system\":\"SpellService\",\"phase\":\"combat\",\"extra\":{}}}"
```
