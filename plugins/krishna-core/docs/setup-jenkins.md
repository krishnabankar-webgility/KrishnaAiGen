# Jenkins — setup and workflow

## What this gives Claude

Trigger and poll the `UnifyEnterprise` Jenkins build, then copy the output to the QA share —
via the local `jenkins` MCP server, driven by the `ship-to-qa` agent / `/ship-to-qa` command
(renamed from `wd-jenkins-build` — it's the whole build-to-QA-handoff pipeline, not just the
Jenkins trigger).

## One-time setup

1. Get a Jenkins **API token**: Jenkins -> your user -> **Configure -> API Token -> Add new Token**.
2. In `C:\WG-Agentic\wg-ai-workspace\.env`, add:
   ```
   JENKINS_USERNAME=<your Jenkins username>
   JENKINS_API_TOKEN=<the token from step 1>
   ```
   These two are read directly by `wg-ai-workspace/.mcp-servers/jenkins/JenkinsTool.cs` (it
   throws `"JENKINS_USERNAME is not set in .env."` if missing) and **as of this writing are not
   yet in `.env`** — add them before the `jenkins` server will start. `JENKINS_URL` and
   `JENKINS_JOB_NAME` are already set in `KrishnaAiGen/.claude/mcp/wg-mcp.json`, not `.env` —
   change them there (then `sync-workspace.ps1`) if the job name or host ever changes.
3. Jenkins is only reachable over VPN — see `setup-remote-access.md` / the `vpn-smb-access` skill
   if `http://jenkins.webgility.com:8080` doesn't load (this is the #1 recurring cause: VPN MTU).
4. Run `sync-workspace.ps1` (see [README](../README.md#mcp-servers)) so `.mcp.json` picks up the
   server, and trust it once per project (or run `approve-mcp-trust.py` to do all of them at once).

## Verify

Ask Claude: *"what's the status of the last UnifyEnterprise build?"* — a real build number and
result back means the server and credentials are working.

## Workflow in short

`ship-to-qa` triggers the build, polls until it finishes, copies the DLLs to the QA share,
posts the RFT Jira transition with the QA comment, and notifies the standing Slack channel —
`-SkipJiraComment` is Krishna's default (see the `ship-to-qa-workflow` memory note for the
exact custom QA comment format used instead of the skill's built-in template).

## Changing behavior

| To change | Edit |
|---|---|
| Job name, Jenkins URL | `KrishnaAiGen/.claude/mcp/wg-mcp.json` → `jenkins.env`, then `sync-workspace.ps1` |
| Credentials | `wg-ai-workspace/.env` |
| Build → QA-share → Jira → Slack sequence, QA comment template | `plugins/krishna-core/skills/ship-to-qa/` (`SKILL.md` + `reference.md`) |
