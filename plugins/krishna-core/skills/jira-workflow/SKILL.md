---
name: jira-workflow
description: "Use when: any Jira UD work - creating Stories/Bugs/Tasks/Sub-tasks, Story Points and Priority Rank 1 defaults, Original Estimate (SP x 8)/N redistribution, worklogs, marking a Story or Sub-task Done, RFT / Ready For Testing handoff, the Comment for QA Testing template, reopening or closing issues, removing redundant Story-Subtask links, or sprint actions."
---

# jira-workflow

Full operational rules live in **`reference.md`** next to this file. **Read `reference.md` before taking any action** — it is the authoritative source and this page is only a map of it.

## Sections in `reference.md`

- (line 15) 1. Issue Creation
- (line 240) 1a. Implementation plan comment — post to Jira before code changes start; §1a.1 is the general Story Point evaluation rule (complexity-based, Fibonacci only) — applies to ANY requested SP evaluation, not just this comment
- (line 302) 2. Original Estimate (OE)
- (line 367) 3. Marking Done and Worklogs
- (line 529) 4. Status and Permissions — §4.1 is the Jira write-resilience rule: one write path failing isn't "no access," try the other path before reporting failure
- (line 564) 5. Sprint Lifecycle
- (line 601) 6. Finding issues by summary and updating subtasks
- (line 615) 7. Comment for QA Testing (Ready For Testing / RFT)
- (line 760) 8. Skill maintenance
- (line 766) 9. Session notes file (scratch, not agent training)
- (line 778) 10. Output Format

> Ported from `.cursor/skill-library/jira-workflow.skill.md` (canonical Cursor/Copilot copy). Keep both in sync — see the `krishnaaigen-skill-evolution` skill.
