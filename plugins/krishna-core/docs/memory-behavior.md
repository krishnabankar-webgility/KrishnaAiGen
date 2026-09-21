# Memory — how it behaves, and what to edit to change it

## The two stores

| Store | Where | Shared across |
|---|---|---|
| Claude's native auto-memory | `MEMORY.md` + one file per fact, under Claude's per-project memory directory | CLI, VS Code extension, desktop app — same machine, same account. **Not** reachable from a web/browser session. |
| Repo-tracked memory | `unify-enterprise/memories/<module>/*.{md,json}` (and any other repo that grows one) | Anywhere the repo is cloned, including a web session reading it from GitHub. Ordinary git-tracked files. |

Use native memory for cross-session facts that only matter on this machine (a debugging trick,
a convention, a customer quirk you don't want re-derived). Use repo-tracked memory for anything
tied to `unify-enterprise` specifically that should travel with the codebase, and for the
per-ticket customization write-ups `ticket-context` produces at
`unify-enterprise/memories/customizations/<TICKET>-<slug>.md`.

## The lifecycle: live -> archived -> permanently deleted

This is enforced by the `memory-gardener` agent (full rules in its own file — this is the
summary):

1. **Live** — the normal state. Read freely.
2. **Archived** (moved to a sibling `_archive/` folder, dropped from `MEMORY.md`'s index):
   - **Immediately**, if the memory is tied to a Jira ticket that reached **Done via RFT with a
     QA "testing completed" comment** — the clean finish line.
   - After **15 days idle**, if the ticket closed some *other* way (early close, Won't Do,
     Duplicate, or Done with no RFT/QA sign-off) — a sanity-check wait, not an instant archive.
   - After **15 days idle**, if there's no Jira ticket at all (personal-use notes, general
     conventions) — the plain idle rule.
   - **Never** while a ticket is still open, no matter how old the memory looks — a customer
     issue can legitimately sit quiet for weeks.
3. **Permanently deleted** (the one irreversible step; logged first to `_archive/_deleted-log.md`):
   once a file has sat **archived for 15 more days with zero updates**, on work that's already
   completed/closed. Nothing here is deleted while still open or before that second 15-day wait.

Archived memory is **not read by default** on a new request — `ticket-context` and
`resume-work` skip `_archive/` unless you name the ticket's history specifically or a task
genuinely needs it. That's what makes archiving actually save tokens instead of just moving the
cost around.

## What to run, and when

- Ask to "tidy up memory" / "check what's stale" any time — `memory-gardener` runs the rules
  above and reports what moved, what got deleted, and what it deliberately left alone.
- It runs read-only against Jira status via the Atlassian connector; if that's unavailable for a
  given file, it falls back to idle-time-only for that one and says so rather than guessing.

## Where to change the behavior

| To change | Edit |
|---|---|
| The idle-day threshold, the RFT/QA-comment fast path, the permanent-delete wait | `plugins/krishna-core/agents/memory-gardener.md` |
| Whether archived memory gets read by default | `plugins/krishna-core/skills/ticket-context/SKILL.md` and `plugins/krishna-core/skills/resume-work/SKILL.md` (the "skip `_archive/`" note in each) |
| What counts as a fact vs. a procedure vs. a routing change (where a correction should land) | `plugins/krishna-core/skills/krishnaaigen-skill-evolution/SKILL.md` |
| The per-ticket customization write-up template | `plugins/krishna-core/skills/ticket-context/SKILL.md` ("Writing the context back") |
