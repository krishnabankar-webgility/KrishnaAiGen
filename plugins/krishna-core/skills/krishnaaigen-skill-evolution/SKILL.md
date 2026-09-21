---
name: krishnaaigen-skill-evolution
description: "Use when: the user corrects a behavior, points out a wrong or missing instruction, teaches a way of working, or says 'remember this for next time' - recognize whether it repeats a past pattern, persist the fix into the right skill/agent file or into memory, and say plainly what changed. Also the default close-out after a specialist agent finishes a thread."
---

# KrishnaAiGen — Skill and agent evolution

When a session reveals **wrong behavior**, **missing steps**, **API quirks**, or a **correction**
("actually do X", "the formula should be…", "no — it's always Y"), that is a signal to update
something durable, not just this conversation, so the mistake or the re-explanation does not
happen again.

## Step 0 — recognize a repeat before doing anything else

Before treating this as brand new, check: does this match an instruction, correction, or
way-of-working already captured in a skill, an agent file, or memory? Search for it (grep the
skill/agent bodies, check `MEMORY.md` and the `memories/` folders, check this file's own history
of past edits if uncertain).

- **If it matches** — say so in one line ("this is the same rule as `<skill>` §x — applying it,
  not re-deriving it") and go straight to doing the work. Do not re-ask for details already on
  file. Only ask for what is genuinely different this time.
- **If it's the same structure with different dynamic values** — e.g. "same as always, but for
  ticket UD-31900" or "run the digest, this time for last Friday" — **do not edit anything.**
  This is not a new pattern to codify, it's a call to a standard instruction that already takes
  the changing part as a parameter. Just do the work with the new value(s). Only touch the skill
  if this occurrence reveals a genuine new *exception* to how the standard case behaves (not just
  a new value) — then add it as a named exception under the existing entry (see Step 1a), never
  as a second near-duplicate skill for "the version where X is different."
- **If it's a refinement of an existing rule** (narrower, an exception, a correction to a past
  fact) — update the existing entry in place rather than adding a second, half-contradictory one.
- **If it's new** — proceed to Step 1.

**Codify immediately, don't wait to be asked.** Once a pattern is recognized as worth keeping —
whether brand new or a refinement — make the edit now, in the same turn, and tell the user what
you changed and where after the fact. Do not hold the edit for a confirmation step first; that
was a deliberate choice (see the "teach-mode autonomy" decision recorded in `MEMORY.md`/this
skill's own history) traded for speed over a pre-edit sign-off. The user still sees the diff-like
summary every time, so nothing changes invisibly — they just review it after, not before.

## Step 1 — decide what kind of thing this is

| This correction is about… | Goes into | Not into |
|---|---|---|
| **How to do a task** — a procedure, a formula, a JQL, a field mapping, a workflow step | The relevant `SKILL.md` (or its `reference.md`) under `plugins/krishna-core/skills/` or `plugins/wd-core/skills/` | Memory — memory is facts, not procedures |
| **A fact worth remembering** — a customer's account setup, a bug's root cause, a ticket's status history, a codebase quirk that isn't a repo-documented convention | Claude's native memory (`MEMORY.md` + one file per fact under the memory directory) | A skill — don't bloat a skill with one-off facts |
| **Which agent should handle X, or how agents hand off to each other** | The routing table in `C:\WG-Agentic\CLAUDE.md`, and the relevant agent's `description:` frontmatter | — |
| **A brand-new kind of recurring task with no home yet** | A new skill or agent — invoke the `skill-author` agent | — |

## Step 1a — recording an exception without forking the skill

When a request matches an existing standard skill/instruction structurally, but this occurrence
needs different handling for one specific case, add it as a short **"Exceptions"** entry inside
the *same* `SKILL.md` (or agent file) — a one- or two-line "if X, do Y instead" — rather than:
- writing a new skill/agent for "the X variant," or
- writing a new memory fact every time X recurs, or
- re-asking the user to explain X again next time it comes up.

The standard instruction stays the default path; the exceptions list is what makes it handle the
cases that don't fit the default, in one place, growing by a line instead of by a file.

## Modification scope

Edit **`plugins/krishna-core/`** and **`plugins/wd-core/`** under `KrishnaAiGen/` — that is the
live, executed copy (installed as the `krishna-core`/`wd-core` plugins). The `.cursor/` and
`.github/` trees in this repo are historical reference only; **nothing reads them anymore** —
do not maintain them and do not treat a difference between them and `plugins/` as a bug to fix
there. Never modify the WD team's own files under `unify-enterprise/.github/` — the `wd-core`
agents/skills are thin routers onto those files precisely so the team's copy is never touched.

You may also write to Claude's own native memory (see the table above) — that is a legitimate
target for this skill now, not just repo files.

## What to edit, concretely

| Change type | Update |
|---|---|
| Procedure, formula, JQL, field map | `plugins/krishna-core/skills/<name>/SKILL.md` (or `reference.md` for the split large ones) |
| A fact, not a procedure | Claude's native memory — one file per fact, plus its `MEMORY.md` index line |
| Which file an agent reads first, or its trigger description | `plugins/krishna-core/agents/<name>.md` |
| Cross-repo routing | `C:\WG-Agentic\CLAUDE.md` routing tables |
| A brand-new skill or agent | Invoke `skill-author` rather than hand-rolling one ad hoc |

## agent-learning agent

Use the **`agent-learning`** agent (or just describe the correction) when the task is "fix the
skill/memory from this feedback." It reads this file plus the target skill or memory file,
applies the edit per Step 0/Step 1 above, and reports what changed.

## Memory lifecycle — archived means don't read it by default

`memory-gardener` moves stale memory through **live -> archived -> permanently deleted** (it can
now actually delete, not just archive — see that agent's file for the exact rules). The part
that matters here: once something is archived, don't read it back in on a routine task just
because it exists. Archived memory is for when the user names it, asks about that ticket's
history specifically, or a task genuinely needs the old context — never as part of a default
"load everything relevant" pass. That's what makes archiving pay for itself in tokens instead of
just moving the cost around.

## What not to put in a skill or in memory

Ephemeral session notes, one-off analysis, or scratch reminders belong in `local/ephemeral/` or
`logs/` (see `krishnaaigen-ephemeral-output`) — not in a skill and not in memory. Memory is for
facts that will matter again; a skill is for a procedure that will run again. If neither is true,
it doesn't belong in either place.

---
> Ported from `.cursor/skill-library/krishnaaigen-skill-evolution.skill.md` originally; that copy
> is now historical only — this file (under `plugins/krishna-core/skills/`) is the live one.
