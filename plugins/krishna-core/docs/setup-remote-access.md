# Remote VM / jump box access (RDP, PSRemoting) — setup and workflow

## What this gives Claude

Diagnosing and fixing RDP/VPN/WinRM failures to a remote Windows VM, running a command on it,
or restarting it — via the `sys-troubleshoot` agent (`/sys-fix`), backed by the
`remote-vm-management` and `vpn-smb-access` skills. This is real PowerShell execution (WinRM /
`Invoke-Command` / `cmdkey`) on this machine, not an MCP server — there is no MCP protocol for
driving a remote GUI/RDP session, so this works by scripting the same command-line tools you'd
run by hand, not by "seeing" the VM's screen.

## One-time setup

1. **VPN**: Sophos Connect must already be installed and enrolled (`sccli.exe` at
   `C:\Program Files (x86)\Sophos\Connect\sccli.exe`) — that's an IT-provisioned client, not
   something this repo installs.
2. **Store the VM account credentials as Windows *user*-level env vars** — not in any repo file:
   ```powershell
   [System.Environment]::SetEnvironmentVariable("RDP_UN", "<vm-ip>\<account>", "User")
   [System.Environment]::SetEnvironmentVariable("RDP_PWD", (Read-Host -AsSecureString "VM password" | ConvertFrom-SecureString -AsPlainText), "User")
   ```
   Run this once, at a real prompt, so the password only ever exists in your typed input and the
   protected env-var store — never paste it into a file, a chat message, or a script argument.
3. **First-time WinRM enablement on the target VM** needs one RDP/console session to run
   `Enable-PSRemoting` and the registry/firewall fixes in the `remote-vm-management` skill —
   after that, WinRM works without console access again.
4. On this machine, `TrustedHosts` needs the VM's IP added (also in that skill, Step 2) — one
   elevated command, persists afterward.

## A real secret was found and fixed while writing this doc

`remote-vm-management/SKILL.md` (and its historical `.cursor/` copy) had the VM account's
**actual plaintext password hardcoded** in several example commands — and that file was already
pushed to GitHub (`origin/Krishna_Dev`, commits `48a22ca`/`39c658d`). Both files are now fixed to
read `RDP_PWD` from the environment instead of embedding the literal value. **The password
itself should still be rotated on the VM** — editing the file doesn't remove it from git
history, so anyone with read access to that repo (or a future fork/clone of it) could still
recover the old value from an earlier commit. This wasn't something I could safely decide to
fix by rewriting pushed history myself (that needs a force-push and can break other clones) —
flagging it here for you to action; say if you want the history itself cleaned up too.

## Verify

`sys-troubleshoot` (`/sys-fix`), asked to run `.\scripts\vm-manager.ps1 status` — a clean VPN +
VM + WinRM status table back confirms the setup end to end.

## Workflow in short

`sys-troubleshoot` loads `vpn-smb-access` first for anything network/VPN-shaped (MTU is the #1
recurring cause of RDP/Jenkins/SMB failures over this VPN), then `remote-vm-management` for
anything VM-specific (WinRM setup, `Invoke-Command`, restart). It diagnoses read-only first,
states the root cause, then fixes — requesting elevation only when a step needs it.

## Adding another VM or jump box

Add a row to the Infrastructure Reference table in `remote-vm-management/SKILL.md` (IP, DNS,
OS, purpose) and, if it's a different account, a differently-named pair of user env vars (don't
reuse `RDP_UN`/`RDP_PWD` for a second machine with different credentials — name them for the
machine, e.g. `RDP_UN_JUMPBOX2`).

## Changing behavior

| To change | Edit |
|---|---|
| VM inventory, root-cause table, diagnostic commands | `plugins/krishna-core/skills/remote-vm-management/SKILL.md` |
| MTU/Kerberos/SMB fixes (VPN-layer, not VM-specific) | `plugins/krishna-core/skills/vpn-smb-access/SKILL.md` |
| Credentials | Windows **user** environment variables (`RDP_UN`, `RDP_PWD`) — never `.env`, never a repo file |
| The `vm-manager.ps1` toolkit itself | `KrishnaAiGen/scripts/vm-manager.ps1` |
