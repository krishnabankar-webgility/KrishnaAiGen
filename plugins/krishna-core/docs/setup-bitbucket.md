# Bitbucket — setup and workflow

## What this gives Claude

Branch creation, PRs, PR comments/replies, and repo metadata on `unify-enterprise` (and any
other Bitbucket repo in the workspace) via the local `bitbucket` MCP server, driven by the
`bitbucket-automation` agent / `/bitbucket` command.

## One-time setup

1. **Create a Bitbucket HTTP access token** — not an Atlassian API token from
   `id.atlassian.com`, a *repository* token:
   Bitbucket repo -> **Repository settings -> Access tokens -> Create access token**.
   Scopes needed: `repository:write`, `pullrequest:write`.
2. Open `C:\WG-Agentic\wg-ai-workspace\.env` and set:
   ```
   BITBUCKET_USERNAME=<your Bitbucket account slug, e.g. krishnabankar — NOT your email>
   BITBUCKET_PASSWORD=<the access token from step 1>
   BITBUCKET_WORKSPACE=<the Bitbucket workspace slug, e.g. webgility>
   ```
   The `@` in an email breaks the git remote URL this feeds — the slug, not the email, is what
   goes in `BITBUCKET_USERNAME`.
3. Run the sync so every repo's `.mcp.json` picks up the server:
   ```
   powershell -ExecutionPolicy Bypass -File C:\WG-Agentic\KrishnaAiGen\.claude\scripts\sync-workspace.ps1
   ```
4. First time only, Claude Code will ask to trust the new `bitbucket` server per project — or
   run `approve-mcp-trust.py` once (see the main [README](../README.md#one-time-setup-extras))
   to skip that for every repo/tree at once.

## Verify

Ask Claude: *"list open PRs on unify-enterprise"*. A working response means the token, username
and workspace are all correct — a 401/403 means the token or scopes, a 404 the workspace slug.

## Workflow in short

`git-automation` commits and pushes; `bitbucket-automation` then opens the branch as a PR,
posts the description, and can reply into review threads. `wd-review` runs against the diff
before the PR goes up. The `/bitbucket` command is the direct entry point when you already know
you want a PR action and don't need routing.

## Changing behavior

| To change | Edit |
|---|---|
| Which env vars the server reads | `C:\WG-Agentic\wg-ai-workspace\.env` |
| Server command/args, log location | `KrishnaAiGen/.claude/mcp/wg-mcp.json` → `bitbucket`, then `sync-workspace.ps1` |
| PR description format, reply behavior | `plugins/krishna-core/skills/bitbucket-workflow/` (or `agents/bitbucket-automation.md` if not split) |
