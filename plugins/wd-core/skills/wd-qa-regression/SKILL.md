---
name: wd-qa-regression
description: 'Use for WD QA execution runs and regression gap analysis - running use cases, posting orders, unsyncing, and finding coverage gaps. The primary QA skill for Webgility Desktop.'
---

# wd-qa-regression

The full instructions for this skill are maintained by the WD team inside the
`unify-enterprise` repo. **Read `.github/skills/qa-skill-regression.md`** (relative to the repo root)
and follow it — this page only points at it, so team edits take effect immediately.

If that path does not exist you are not running inside `unify-enterprise`
(`C:\WG-Agentic\unify-enterprise`, mirror `C:\WG-Agentic 2\unify-enterprise`).
Say so and stop rather than improvising.

The file is written for GitHub Copilot. Translate its tool names: `read`/`search` ->
`Read`/`Glob`/`Grep`, `edit` -> `Edit`/`Write`, `execute` -> `Bash`/`PowerShell`,
`agent` -> the `Agent` tool, `atlassian/*` -> `mcp__claude_ai_Atlassian_Rovo__*`.
A `#file:../x` reference means a path relative to the file you are reading.
