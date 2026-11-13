---
name: vpn-smb-access
description: 'Use when: cannot access UNC path over VPN, network share not accessible from home, net use hangs, SMB share access denied, \\server\share not opening, file share works at office but not remote, VPN connected but cannot browse shares, Kerberos authentication failed, MTU issue VPN, SMB negotiation timeout, net use hangs forever.'
---

# VPN + SMB Network Share Access Fix

## Before anything else: is VPN even connected? Check and self-heal first

**Any time a task fails because VPN looks disconnected — a DB/ES/proxy host unreachable, a UNC
share timing out, `ping`/`Test-NetConnection` failing to an internal host — check and reconnect
it yourself before stopping to ask the user.** The credentials and the script to do this already
exist:

```powershell
C:\WG-Agentic\KrishnaAiGen\scripts\vm-manager.ps1 vpn-check    # reports Connected / Disconnected
C:\WG-Agentic\KrishnaAiGen\scripts\vm-manager.ps1 vpn-connect  # connects if needed, no-ops if already up
```

This uses Sophos Connect (`sccli.exe`) with the **`VPN_UN`/`VPN_PWD`** Windows *user* env vars
(the corp domain account — a separate credential from `RDP_UN`/`RDP_PWD`, which is the VM-local
RDP account; don't conflate them). Only stop and ask the user if `vpn-connect` itself reports
**FAILED** — that means the credential or the Sophos profile itself needs attention, which isn't
something to guess around. A silent "VPN not connected" stop without having tried this first is
the bug to avoid, not the correct caution.

**Found and fixed 2026-10-09:** `Connect-Vpn` in `vm-manager.ps1` was actually reading
`RDP_UN`/`RDP_PWD` instead of `VPN_UN`/`VPN_PWD` — the two were wrongly assumed to be the same
credential (the script's own comment said "VPN uses same creds"). That's why self-reconnecting
wasn't working even when it was attempted: wrong account was being sent to `sccli enable`. Fixed
by adding a dedicated `Get-VpnCreds` reading the correct pair.

**Found and fixed 2026-11-03:** `Test-VpnConnected` matched `"Connected: \d+ \("`, which also
matches Sophos's own `"Connected: 0 (not connected)"` line — so `vpn-check` falsely reported
"Connected" while actually disconnected. Fixed to `"Connected: [1-9]\d* \("`. **Don't trust
`vpn-check`/`vpn-connect`'s own "Connected" line as sufficient** even after this fix — a result
that disagrees with observed symptoms (no Sophos tray icon, Jenkins/SMB still unreachable) means
re-verify with the raw command: `& "C:\Program Files (x86)\Sophos\Connect\sccli.exe" get -n
111.118.255.21 -t endpoints` / `-t dynamic`.

**Distinguish AUTH_FAILED from network-unreachable before retrying — check the logs, don't
guess.** `C:\Program Files (x86)\Sophos\Connect\openvpn.log` and `scvpn.log` are authoritative.
If TLS handshake + certificate verify succeed and then the gateway replies `AUTH_FAILED` /
`"user authentication failed - clearing any stored credentials"`, that is a **rejected
credential** (expired `VPN_PWD`, an MFA/push step only the interactive Sophos Connect GUI can
satisfy, or account lockout) — not a reachability problem, and `vpn-connect` retries will not fix
it. **Stop after 1–2 failed attempts** — repeated failed auth risks locking the account — and
escalate to Krishna to verify/rotate the credential rather than looping. Sophos Connect's tunnel
is OpenVPN under the hood (it bundles its own `openvpn.exe`), so "try OpenVPN GUI instead" or a
dedicated VPN MCP server doesn't route around a rejected credential — same auth path either way.

## Skill Purpose
Fix issues accessing Windows network shares (UNC paths like `\\server\share`) over VPN connections when standard authentication fails or hangs.

## When to Use This Skill

- Connected to VPN (Sophos, OpenVPN, Cisco AnyConnect, etc.)
- Can **ping** the file server but `net use \\server\share` **hangs or fails**
- The share works from the office network but not from home/remote location
- Errors: `The password is invalid`, `System error 53/64/67`, or command freezes forever
- Kerberos authentication failures over VPN
- Cannot access internal web services (Jenkins, web apps) over VPN
- RDP/Remote Desktop fails to connect to VMs over VPN

### Real-World Success Examples

This skill has successfully fixed:

1. **Jenkins access** — http://jenkins.webgility.com:8080 not loading (MTU 1200 + Private profile fixed HTTP over VPN)
2. **RDP to VMs** — Remote Desktop connection failing over VPN (network profile + Kerberos refresh)
3. **Multiple UNC paths** — `\\inwsfs02\UDInstaller` and other shares inaccessible from home (MTU + NTLM auth)

**Pattern**: Same MTU fix resolves HTTP, RDP, and SMB issues simultaneously.

---

## Root Causes (Ordered by Frequency)

| # | Root Cause | Symptom | Fix Priority |
|---|---|---|---|
| 1 | **MTU too high on VPN adapter** | `net use` hangs forever; TCP port 445 open but SMB never completes | **HIGH** |
| 2 | **No Kerberos tickets** (logged in before VPN connected) | `klist` shows 0 tickets; auth fails silently | **HIGH** |
| 3 | **Network adapter on Public profile** | File sharing / NTLM blocked by Windows firewall | **MEDIUM** |
| 4 | **Stale credentials in Credential Manager** | Wrong password cached for server | **MEDIUM** |
| 5 | **Wrong VPN split-tunnel route** | Traffic to server subnet not going through VPN | **LOW** |

---

## STEP 1: Full Diagnostic Scan

Run all commands to gather complete picture before making changes:

```powershell
# 1. Network adapters & profiles
Get-NetConnectionProfile | Format-Table Name, InterfaceAlias, NetworkCategory, IPv4Connectivity

# 2. VPN adapter IP configuration
Get-NetIPAddress | Where-Object AddressFamily -eq 'IPv4' | Format-Table InterfaceAlias, IPAddress, PrefixLength

# 3. DNS resolution test
[System.Net.Dns]::GetHostAddresses("inwsfs02")   # replace with actual server hostname

# 4. SMB port connectivity (TCP 445)
Test-NetConnection -ComputerName <server-ip> -Port 445 -WarningAction SilentlyContinue

# 5. Kerberos tickets status
$r = & cmd /c "klist 2>&1"; $r | ForEach-Object { $_ }

# 6. Routing to server subnet
route print | Select-String "192.168."   # adjust to match your subnet

# 7. Current MTU on all adapters
netsh interface ipv4 show subinterface

# 8. Stored credentials
cmdkey /list | Select-String -Pattern "Target:|User:" -Context 0,1
```

**Key diagnostic signals:**
- ✅ DNS resolves + Port 445 open + `net use` hangs = **MTU issue**
- ✅ `klist` shows 0 tickets + auth fails = **Kerberos issue**
- ✅ VPN adapter = Public profile = **Firewall blocking SMB**

---

## STEP 2: Fix MTU Issue (Most Common)

### Diagnosis
`net use` hangs forever, BUT `Test-NetConnection -Port 445` returns `TcpTestSucceeded = True`.

**Why**: TCP 3-way handshake uses small packets (succeeds), but SMB negotiation packets are large and get silently dropped by the VPN tunnel due to MTU mismatch.

### Find the Working MTU Boundary

```powershell
# Test with Don't-Fragment flag — binary search to find max working size
cmd /c "ping -n 1 -f -l 1200 <server-ip>"   # reply = good
cmd /c "ping -n 1 -f -l 1300 <server-ip>"   # timeout = too large
cmd /c "ping -n 1 -f -l 1250 <server-ip>"   # narrow down...

# Keep halving/narrowing until you find the highest value that gets a reply
# Actual MTU = highest working payload + 28 (IP + ICMP headers)
```

### Apply MTU Fix (Requires Admin/UAC)

```powershell
# 1. Get VPN adapter name
Get-NetAdapter | Where-Object Status -eq 'Up'

# 2. Set MTU — replace adapter name and value as needed
# Common safe values: 1200 (conservative), 1350 (moderate), 1400 (optimistic)
Start-Process -FilePath "netsh" `
  -ArgumentList 'interface ipv4 set subinterface "OpenVPN TAP-Windows6" mtu=1200 store=persistent' `
  -Verb RunAs -Wait

# 3. Verify the change
netsh interface ipv4 show subinterface | Select-String "OpenVPN"
```

**Environment-Specific Values (corp.webgility.com):**
- VPN Adapter: `OpenVPN TAP-Windows6`
- Working MTU: **1200** (anything above 1228 total is silently dropped)
- Server: `inwsfs02` @ `192.168.0.95`

---

## STEP 3: Fix Kerberos Authentication (No Tickets)

### Diagnosis
`klist` shows `Cached Tickets: (0)` AND `klist get krbtgt/CORP` fails with `No authority could be contacted`.

**Why**: You logged into Windows with cached credentials (offline/home), then connected VPN afterward. Your logon session has no live Kerberos tokens to authenticate to file servers.

### Option A: Use Explicit Credentials (NTLM Fallback) ⭐ FASTEST

```powershell
# Works immediately — uses NTLM instead of Kerberos
net use \\<server>\<share> /user:<DOMAIN>\<username> "<password>"

# Example for this environment:
net use \\inwsfs02\UDInstaller /user:CORP\krishna.bankar "YourPassword"
```

### Option B: Lock & Unlock Workstation (Gets Fresh Kerberos TGT)

```powershell
# Lock the workstation
rundll32.exe user32.dll,LockWorkStation

# Unlock with your domain password while VPN is still connected
# Windows will authenticate against the DC and get fresh Kerberos tickets

# After unlocking, verify tickets:
klist
# Should now show TGT and service tickets
```

---

## STEP 4: Fix Network Profile (VPN on Public)

### Diagnosis
`Get-NetConnectionProfile` shows VPN adapter with `NetworkCategory = Public`.

**Why**: Windows firewall blocks file sharing, NTLM, and SMB protocols on Public networks.

### Fix

```powershell
# Change VPN adapter to Private network profile
Set-NetConnectionProfile -InterfaceAlias "OpenVPN TAP-Windows6" -NetworkCategory Private

# Verify
Get-NetConnectionProfile | Format-Table InterfaceAlias, NetworkCategory
```

**Effect**: Immediate — no reboot needed. File sharing firewall rules now allow SMB traffic.

---

## STEP 5: Fix Stale Credentials

### Diagnosis
`cmdkey /list` shows an old entry for the server with incorrect/expired credentials.

### Fix

```powershell
# Remove stale entries
cmdkey /delete:<servername>         # e.g. cmdkey /delete:inwsfs02
cmdkey /delete:<server-ip>          # also try by IP: cmdkey /delete:192.168.0.95

# Re-add correct credentials
cmdkey /add:<servername> /user:<DOMAIN>\<username> /pass:<password>
```

---

## STEP 6: Verify & Clean Up

```powershell
# Test share access — should complete immediately
net use \\inwsfs02\UDInstaller /user:CORP\krishna.bankar "<password>"

# List directory contents to confirm
dir \\inwsfs02\UDInstaller | Select-Object -First 10

# Open in File Explorer for visual confirmation
explorer.exe "\\inwsfs02\UDInstaller"

# Show all active network connections
net use

# Clean up temporary stored credentials (security best practice)
cmdkey /delete:inwsfs02
```

---

## Environment Reference (corp.webgility.com)

| Item | Value |
|---|---|
| **Domain** | `CORP` / `corp.webgility.com` |
| **Domain Controller** | `INWSDC01` @ `192.168.0.51` |
| **File Server** | `inwsfs02` @ `192.168.0.95` |
| **VPN Adapter** | `OpenVPN TAP-Windows6` |
| **VPN Client IP Range** | `192.168.100.x` subnet |
| **Route to Office** | `192.168.0.0/16` → `192.168.100.1` (gateway) |
| **Working MTU** | **1200** (above this causes silent packet drop) |
| **DNS Servers (VPN)** | `192.168.0.51`, `192.168.0.70` |
| **Test User** | `CORP\krishna.bankar` |

---

## Automated Fix Script

Complete PowerShell script for hands-free fixing:

```powershell
param(
    [string]$Share      = "\\inwsfs02\UDInstaller",
    [string]$User       = "CORP\krishna.bankar",
    [string]$Pass       = "",           # pass at runtime for security
    [string]$VPNAdapter = "OpenVPN TAP-Windows6",
    [int]$MTU           = 1200
)

Write-Host "`n=== STEP 1: Set VPN to Private Profile ===" -ForegroundColor Cyan
Set-NetConnectionProfile -InterfaceAlias $VPNAdapter -NetworkCategory Private -ErrorAction SilentlyContinue

Write-Host "`n=== STEP 2: Fix MTU (requires admin UAC) ===" -ForegroundColor Cyan
Start-Process -FilePath "netsh" `
  -ArgumentList "interface ipv4 set subinterface `"$VPNAdapter`" mtu=$MTU store=persistent" `
  -Verb RunAs -Wait

Write-Host "`n=== STEP 3: Clear stale connections ===" -ForegroundColor Cyan
net use * /delete /y 2>$null

Write-Host "`n=== STEP 4: Map the share ===" -ForegroundColor Cyan
if ($Pass) {
    net use $Share /user:$User $Pass
} else {
    $cred = Get-Credential -UserName $User -Message "Enter your domain password"
    net use $Share /user:$User $cred.GetNetworkCredential().Password
}

Write-Host "`n=== STEP 5: Verify Success ===" -ForegroundColor Cyan
net use
Write-Host "`nContents of share:" -ForegroundColor Green
dir $Share | Select-Object -First 5

Write-Host "`n✅ Done! Share should now be accessible." -ForegroundColor Green
```

---

## Success Indicators

✅ `net use \\server\share` completes in < 2 seconds
✅ Directory listing works: `dir \\server\share`
✅ File Explorer opens the share successfully
✅ `net use` shows connection as `OK` status
✅ MTU setting persists after reboot (`store=persistent`)

## Common Pitfalls to Avoid

❌ **Don't** set MTU too high (test first with ping -f)
❌ **Don't** hardcode passwords in scripts (use `Get-Credential`)
❌ **Don't** forget to clean up temporary stored credentials
❌ **Don't** skip the diagnostic phase — fix the actual root cause, not symptoms

---
> Ported from `.cursor/skill-library/vpn-smb-access.skill.md` (canonical Cursor/Copilot copy). Keep both in sync — see the `krishnaaigen-skill-evolution` skill.
