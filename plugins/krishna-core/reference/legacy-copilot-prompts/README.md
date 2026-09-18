# Legacy GitHub Copilot prompts (archive — NOT active)

These are verbatim copies of `KrishnaAiGen/.github/prompts/*.prompt.md` as they existed when the
Claude plugin was built (2026-09-17). They are kept for history only.

**Do not follow them.** Several contradict the canonical skills, e.g.:

| Topic | Legacy prompt says | Canonical skill says |
|---|---|---|
| Original Estimate | `1 SP = 4h`, always 3 subtasks, `(SP x 4) / 3` | `jira-workflow` §2.2: `(SP x 8) / N` where N = actual subtask count |
| Story defaults | always P2 / Desktop-Customization / assign Krishna | `jira-workflow` §1.6c: Priority **Rank** 1 + estimated Story Points; do not apply unrequested defaults |

The active slash commands in `../commands/` delegate to the subagents in `../agents/`,
which load the skills in `../skills/`. That chain is the single source of truth.
