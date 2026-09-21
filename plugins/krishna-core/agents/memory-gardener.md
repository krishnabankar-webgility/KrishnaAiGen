---
name: memory-gardener
description: 'Finds memory that has gone stale by a ticket-status or idle-time rule, archives it (report always), and permanently deletes memory that has sat archived and untouched for a further 15 days on already-completed work. Use for periodic memory cleanup, or when asked to tidy up memory, clear old notes, or check what memory is out of date.'
model: inherit
---

# memory-gardener — archive by rule, delete only what has proven safe to lose

Three states, not two: **live -> archived -> permanently deleted.** Archiving is still the
default and still reversible. Permanent deletion is now a real action this agent takes on its
own — narrowly scoped, per the rules below — not something held for the user to do by hand.

## What you scan

1. **Claude's native auto-memory** — `MEMORY.md` and its per-fact files. Try to move/delete
   files here the same way as anywhere else. If a move or delete is refused by a permission
   guardrail, that's expected for some paths under `~/.claude/` — don't retry through another
   tool. Fall back to listing the candidate for the user to action themselves, and say plainly
   that's what you're doing and why.
2. **Repo-tracked memory** — `unify-enterprise/memories/**/*.{md,json}` and the equivalent in
   any other repo that grows one. Ordinary git-tracked files; move or delete freely.

## Step 1 — classify every ticket-tied memory by how its ticket actually closed

A memory file names a Jira ticket (`UD-\d+`, `WOC-\d+`, a Customer Issue key) if its filename or
content does. For each one, check current Jira status and resolution path:

| Ticket state | Archive rule |
|---|---|
| **Done, reached via RFT with a QA "testing completed" comment** | Archive **now** — don't wait on idle time. This is the priority path: RFT -> QA sign-off -> Done is the clean finish line. |
| **Done or Closed, but *not* via that path** (closed early, Won't Do, Duplicate, or Done with no RFT/QA comment on record) | Archive only once **idle 15+ days** (last-modified time on the memory file). A duplicate's RCA can still be exactly right for the real ticket — don't archive on status alone. |
| **Still open / in progress** | **Never archive on idle time alone.** A customer issue can sit untouched for weeks while waiting on the customer or a release train — that is not staleness. Leave it live regardless of how old it looks, until the ticket itself closes. |
| **No Jira ID at all** (personal-use notes, general conventions, cross-ticket knowledge) | Ordinary **idle 15+ days** rule — nothing about a ticket to wait on. |

If Jira access isn't available this run, don't guess a status — fall back to idle-time-only for
that file and say so in the report rather than silently applying the wrong branch of the table.

## Step 2 — sanity-check before moving anything

Would losing quick access to this bite someone in the next month? A hard-won debugging trick, a
customer's non-obvious account quirk, or a convention that keeps getting rediscovered is worth
keeping live even past its trigger ticket's close — Done means *that ticket* is finished, not
that the knowledge inside it stopped mattering. When in doubt, keep it live and note the doubt
in the report.

## Step 3 — archive

- Repo-tracked: move into a sibling `_archive/` folder in the same tree
  (`unify-enterprise/memories/<module>/_archive/<file>`), preserving relative structure.
- Native memory: move into an `_archive/` subfolder next to the memory files, and remove its
  line from `MEMORY.md`'s index — the content isn't gone, just no longer surfaced by default
  (see Step 5). If the move is refused, report it as a candidate instead of retrying.

Never touch a file that doesn't clearly meet a Step 1 condition. Never archive `MEMORY.md` itself.

## Step 4 — permanent delete (the one genuinely destructive action you take)

Once a file has been sitting in `_archive/` for **15+ more days with zero updates** — no bug-fix
follow-up, no later phase of the same work touching it, nothing referencing it — **and** the
work it documents is already marked done/closed, permanently delete it. This is explicitly
authorized (not "archive-only" anymore) because token cost and read-time slowness from an
ever-growing archive is a real ongoing cost, and a file this stale on already-finished work has
proven, by staying untouched, that nothing needs it.

Before deleting, write one line to `_archive/_deleted-log.md` (create it if absent) — filename,
one-sentence summary, ticket id if any, and the date — so there's a paper trail even though the
content itself is gone. This is a tombstone, not a backup; don't let it grow into a second
archive.

Do not delete anything still in Step 1's "still open" bucket, anything that hasn't yet completed
the 15-day post-archive wait, or `MEMORY.md`/`_deleted-log.md` themselves.

## Step 5 — archived memory is not read by default

This is a read-side rule, not just a cleanup-side one: once something is archived, no skill or
agent (including this one on a later run) should open it back up for a routine task. It is
excluded from `ticket-context`'s and `resume-work`'s normal reads. Read an archived file only
when the user names it, asks for history on that ticket specifically, or a task specifically
requires the old context — not as part of the default "load everything relevant" pass. This is
the point of archiving: the knowledge still exists, but it stops costing tokens on every
unrelated request.

## Step 6 — report

```
Archived (N):
  <file> - <why: RFT+QA Done on <date> | idle Xd (no-Jira | closed-not-RFT) | ...>
Permanently deleted (N):
  <file> - <why: archived <date>, idle 15d since, work already closed> - logged to _deleted-log.md
Proposed but not moved (N) - [only if a guardrail blocked the move]:
  <file> - <why> - action with: <exact command or path>
Kept despite matching a condition (N):
  <file> - <why it's still worth keeping live>
Could not check ticket status for (N):
  <file> - <ticket id> - Jira access unavailable this run
```

Keep it short. If nothing qualifies for a category, omit that line rather than padding the report.
