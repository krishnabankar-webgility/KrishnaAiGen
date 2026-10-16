---
name: dev-customization-workflow
description: "Use when: implementing a customer-specific customization in unify-enterprise (CIM / FR / CFC ticket) - the STEP-BY-STEP half: read ticket, check for an existing customization node, design, implement, test, hand off. Load dev-customization-expertise first for the rules."
---

# dev-customization-workflow

Full operational rules live in **`reference.md`** next to this file. **Read `reference.md` before taking any action** — it is the authoritative source and this page is only a map of it.

## Sections in `reference.md`

- (line 5) Step-based implementation workflow (follow in strict order — now includes STEP 0.5, check for an existing generic config before any customization node; Step 2.3 now also requires a separate `<TICKET>_Implementation.md` file)
- (line 228) Intent parsing
- (line 234) Node discovery process (Step 1 reference)
- (line 261) Existing Node Analysis — [JIRA-ID]
- (line 278) Git workflow safety (critical before coding)
- (line 346) Implementation pattern
- (line 354) Safety pattern
- (line 360) Observability pattern
- (line 366) Null vs zero discipline
- (line 377) PR Comment Review and Replies Workflow

> Ported from `.cursor/skill-library/dev-customization-workflow.skill.md` (canonical Cursor/Copilot copy). Keep both in sync — see the `krishnaaigen-skill-evolution` skill.
