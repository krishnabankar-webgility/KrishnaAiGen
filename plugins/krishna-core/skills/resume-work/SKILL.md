---
name: resume-work
description: "Use when starting a new session or asked to resume, continue, pick up where we left off, or catch up on a ticket - reconstructs what was in progress from memory, Reference/<TICKET>/, git state, and the ticket-context skill. Also use when the user says they are stopping for now, done for today, or asks to save progress - writes a resume note so any tool or session can pick it back up."
---

# resume-work — pick up across any session, any tool

Claude's own memory (`MEMORY.md` + the per-fact files) is already shared across the CLI, the
VS Code extension and the desktop app on this machine — same account, same `~/.claude`. It is
**not** reachable from a browser session at claude.ai, which has no local filesystem. This skill
exists for the gap that leaves: durable, resumable task state that a **git-tracked file** can
carry to a web session too, not just to another local one.

## Resuming (start of a session, or "where were we")

1. Load `ticket-context` if a ticket ID is in play — it covers `Reference/<TICKET>/` and the
   `memories/` module folders.
2. Check for a resume note: `Reference/<TICKET>/RESUME.md` if a ticket is named, otherwise
   `Reference/_active-work.md` for cross-ticket state (which tickets are open, which repo/branch
   each is on, what's next). Skip anything under an `_archive/` folder unless the user asks for
   that ticket's history specifically — `memory-gardener` archives it precisely so it's not
   re-read by default.
3. Check git state in both trees for the ticket's branch (`git branch -a | grep <id>`,
   `git status --short`) — a resume note can go stale; the branch itself is ground truth for
   what code changed since it was written.
4. State what you found in a few lines before doing anything else: what was in progress, what
   was last done, what's next per the note, and whether the note and the branch still agree.
   If they disagree, say so rather than picking one silently.

## Saving progress (end of a session, or asked to)

Write or update the resume note — don't just let it fall out of context:

```markdown
# Resume: <TICKET or task>

**Last updated:** <date>, session in <tool/surface if known>

## Status
<one line: what stage this is at>

## Done so far
- ...

## Next
- ...

## Branch / location
<repo>, branch `<name>`, tree <1 or 2>

## Watch out for
<anything non-obvious a fresh session would otherwise rediscover the hard way>
```

Keep it short — a page, not a transcript. If the durable fact belongs in memory instead (a
customer quirk, a root cause, a convention) write that separately per `krishnaaigen-skill-
evolution` — this note is for *in-progress* state, not settled knowledge.

Commit and push it if the user is likely to resume from a different machine or from web — that
is the only way a browser session can ever see it (point it at the file's GitHub URL and ask it
to read that before continuing).
