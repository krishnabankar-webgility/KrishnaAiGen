---
name: ship-to-qa
description: 'Use when: an implementation is done and ready to hand off to QA, triggering a Jenkins build for unify-enterprise, deploying a build to the QA share, uploading the installer to Dropbox, posting the QA Testing Jira comment, sending a Slack build notification, checking Jenkins build status, copying WebgilityInstaller to the network share, or changing Jira assignee/status to RFT. The whole 10-step build-to-QA-handoff pipeline, end to end — say "ship to QA" (or /ship-to-qa) and it collects whatever details are still missing.'
---

# ship-to-qa

Full operational rules live in **`reference.md`** next to this file. **Read `reference.md` before taking any action** — it is the authoritative source and this page is only a map of it.

## Sections in `reference.md`

- (line 35) ⚡ Preferred: Autonomous Script (97% Token Reduction)
- (line 64) §0 Pre-flight: Extract Jira Ticket ID from Branch
- (line 81) §0.5 Jira Subtask Transition Helper (TEMPORARY — testing phase only)
- (line 107) §1.0 Pre-Build Check: Is a Jenkins Build Already Running?
- (line 158) §1a (MANDATORY BLOCKING STEP) Pre-Build Slack Notification
- (line 175) §1a Pre-Build Slack Notification (Updated)
- (line 208) §1 Jenkins Build Trigger
- (line 252) §2 Build Status Polling
- (line 309) §3 Verify Network Share & Locate Artifact
- (line 418) §4 Copy Installer to QA Network Share
- (line 447) §5 Upload to Dropbox + Get Shareable Link (OPTIONAL)
- (line 640) §6 Change Jira Assignee + Transition to RFT — if the RFT transition isn't found via raw REST, fall back to the Atlassian MCP connector directly rather than silently skipping (jira-workflow §4.1)
- (line 712) §7 Slack Notification
- (line 785) §8 Structured QA Testing Jira Comment (LAST STEP)
- (line 930) §9 Environment Variables — Complete Reference
- (line 951) §10 Quick Reference
- (line 976) §11 Related Agents / Delegation
- (line 986) §12 Subtask → Pipeline Map (TEMPORARY — testing only)

> Ported from `.cursor/skill-library/wd-jenkins-build.skill.md` (canonical Cursor/Copilot copy, still named `wd-jenkins-build` there — historical only). Renamed to `ship-to-qa` in the live plugin copy — see the `krishnaaigen-skill-evolution` skill.
