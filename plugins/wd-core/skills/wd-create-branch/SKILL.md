---
name: wd-create-branch
description: 'Use to create a git branch in unify-enterprise from the current state using the teams deterministic branch bootstrap workflow.'
---

# wd-create-branch

The full instructions for this skill are maintained by the WD team inside the
`unify-enterprise` repo. **Read `.github/skills/create-branch-from-current/SKILL.md`** (relative to the repo root)
and follow it — this page only points at it, so team edits take effect immediately.

If that path does not exist you are not running inside `unify-enterprise`
(`C:\WG-Agentic\unify-enterprise`, mirror `C:\WG-Agentic 2\unify-enterprise`).
Say so and stop rather than improvising.

The file is written for GitHub Copilot. Translate its tool names: `read`/`search` ->
`Read`/`Glob`/`Grep`, `edit` -> `Edit`/`Write`, `execute` -> `Bash`/`PowerShell`,
`agent` -> the `Agent` tool, `atlassian/*` -> `mcp__claude_ai_Atlassian_Rovo__*`.
A `#file:../x` reference means a path relative to the file you are reading.
