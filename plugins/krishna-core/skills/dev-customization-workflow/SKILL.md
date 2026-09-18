---
name: dev-customization-workflow
description: "Use when: implementing a customer-specific customization in unify-enterprise (CIM / FR / CFC ticket) - the STEP-BY-STEP half: read ticket, check for an existing customization node, design, implement, test, hand off. Load dev-customization-expertise first for the rules."
---

# dev-customization-workflow

Full operational rules live in **`reference.md`** next to this file. **Read `reference.md` before taking any action** — it is the authoritative source and this page is only a map of it.

## Sections in `reference.md`

- (line 5) Step-based implementation workflow (follow in strict order)
- (line 196) Intent parsing
- (line 202) Node discovery process (Step 1 reference)
- (line 229) Existing Node Analysis — [JIRA-ID]
- (line 246) Git workflow safety (critical before coding)
- (line 314) Implementation pattern
- (line 322) Safety pattern
- (line 328) Observability pattern
- (line 334) Null vs zero discipline
- (line 345) PR Comment Review and Replies Workflow

> Ported from `.cursor/skill-library/dev-customization-workflow.skill.md` (canonical Cursor/Copilot copy). Keep both in sync — see the `krishnaaigen-skill-evolution` skill.
