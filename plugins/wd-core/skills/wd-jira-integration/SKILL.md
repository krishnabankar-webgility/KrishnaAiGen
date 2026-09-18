---
name: wd-jira-integration
description: 'Use when a Jira ticket reference appears while working in unify-enterprise and WD-specific ticket handling is needed - how wd-master fetches, digests and routes a UD ticket.'
---

# wd-jira-integration

The full instructions for this skill are maintained by the WD team inside the
`unify-enterprise` repo. **Read `.github/skills/jira-integration-skill.md`** (relative to the repo root)
and follow it — this page only points at it, so team edits take effect immediately.

If that path does not exist you are not running inside `unify-enterprise`
(`C:\WG-Agentic\unify-enterprise`, mirror `C:\WG-Agentic 2\unify-enterprise`).
Say so and stop rather than improvising.

The file is written for GitHub Copilot. Translate its tool names: `read`/`search` ->
`Read`/`Glob`/`Grep`, `edit` -> `Edit`/`Write`, `execute` -> `Bash`/`PowerShell`,
`agent` -> the `Agent` tool, `atlassian/*` -> `mcp__claude_ai_Atlassian_Rovo__*`.
A `#file:../x` reference means a path relative to the file you are reading.
