---
description: 'Windows / VPN / SMB / network / VM diagnostics and fixes'
argument-hint: '[the symptom, e.g. "cannot reach the QA share over VPN"]'
---

Delegate this request to the **`sys-troubleshoot`** subagent using the Agent tool.

The subagent must load these skills before acting: `vpn-smb-access`, `network-profile-fix`, `remote-vm-management`, `sys-cleanup-optimization` (load per symptom).

If the request below is empty, ask what is needed rather than guessing.

## Request

$ARGUMENTS
