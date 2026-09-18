---
name: wd-jenkins-build
description: 'Use when: triggering Jenkins build for unify-enterprise, deploying build to QA share, uploading installer to Dropbox, posting QA Testing Jira comment, sending Slack build notification, checking Jenkins build status, copying WebgilityInstaller to network share, changing Jira assignee/status to RFT.'
---

# wd-jenkins-build

Full operational rules live in **`reference.md`** next to this file. **Read `reference.md` before taking any action** — it is the authoritative source and this page is only a map of it.

## Sections in `reference.md`

- (line 12) ⚡ Preferred: Autonomous Script (97% Token Reduction)
- (line 41) §0 Pre-flight: Extract Jira Ticket ID from Branch
- (line 58) §0.5 Jira Subtask Transition Helper (TEMPORARY — testing phase only)
- (line 84) §1.0 Pre-Build Check: Is a Jenkins Build Already Running?
- (line 135) §1a (MANDATORY BLOCKING STEP) Pre-Build Slack Notification
- (line 152) §1a Pre-Build Slack Notification (Updated)
- (line 185) §1 Jenkins Build Trigger
- (line 229) §2 Build Status Polling
- (line 286) §3 Verify Network Share & Locate Artifact
- (line 395) §4 Copy Installer to QA Network Share
- (line 424) §5 Upload to Dropbox + Get Shareable Link (OPTIONAL)
- (line 617) §6 Change Jira Assignee + Transition to RFT
- (line 678) §7 Slack Notification
- (line 751) §8 Structured QA Testing Jira Comment (LAST STEP)
- (line 896) §9 Environment Variables — Complete Reference
- (line 917) §10 Quick Reference
- (line 942) §11 Related Agents / Delegation
- (line 952) §12 Subtask → Pipeline Map (TEMPORARY — testing only)

> Ported from `.cursor/skill-library/wd-jenkins-build.skill.md` (canonical Cursor/Copilot copy). Keep both in sync — see the `krishnaaigen-skill-evolution` skill.
