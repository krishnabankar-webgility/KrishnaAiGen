---
name: wd-ui-automation
description: "Use ONLY when Krishna explicitly asks for the UI path (not the default — see §-1) for driving the real, installed Webgility Desktop (Unify.exe) app directly: launching it, logging in, navigating screens, or exercising a function (e.g. download an order by OnlineOrderID) the same way a human would, via Windows UI Automation. Not for internal/headless code calls — this drives the actual UI window. Covers reading the source before touching the UI, verifying via UIA text properties instead of screenshots, the critical focus-verification safety rule, the proven order-by-ID download recipe, and the existing UiStepRunner/WG-UIDiscovery.ps1 infrastructure this reuses."
---

# wd-ui-automation

## -1. Opt-in only — not the default path (standing rule, 2026-10-19)

**Default to the backend/API path, not this skill.** Fetch Shopify order data via the `shopify`
MCP; read/write QuickBooks Desktop via the `quickbooks-desktop` MCP's `ExecuteQbxml` directly —
neither needs any UI open. Driving WD's or QBD's actual UI is slow, geometry-fragile, and
token-expensive by comparison. Reach for this skill **only when Krishna explicitly asks for the UI
path** — typically because the point of the task is to exercise WD's own download/posting business
logic itself (store-profile matching, item/tax mapping, customer resolution), not merely to move
data from one system to another. If a request is ambiguous, ask rather than defaulting to UI.

Driving the real, already-installed Webgility Desktop app via **Windows UI Automation**
(`System.Windows.Automation`, same engine as Selenium-for-a-browser but for a native Win32/WinForms
window) — not internal reflection, not a reimplemented bootstrap of WD's static state. This reuses
infrastructure WD's own team already built for a different purpose; see §6.

## 0. Standing rule: read the source first, verify via text — screenshots are a last resort

**Screenshots cost real tokens (image content) every time they're read back; UIA text properties
cost almost nothing.** Krishna's correction (2026-10-16): most of the screenshots taken building
§5 below were unnecessary — the information was already available more cheaply.

- **Before touching any new screen, find and read its `.Designer.cs`** (plus the `.cs` for click
  handlers) in `unify-enterprise`. This gives the full control map (`AutomationId`s, button/menu
  item text, which handler fires), the exact sequencing (e.g. "Add" must run before "Get Orders"),
  and dropdown-menu item names — all in one read, before writing a single line of PowerShell. This
  is how the split-button's click zone and the Add-before-Get-Orders requirement in §5 were *really*
  found, after screenshots alone had already failed to explain the problem.
- **Verify state and results via UIA element properties (`.Current.Name`, `.Current.Value` through
  `ValuePattern`), not by capturing and visually reading an image.** A dialog opening = checking
  `FindFirst(...)` returns non-null and reading its title's `.Current.Name` in `Write-Host` — not a
  screenshot. A result grid's rows = `GridPattern`/`TablePattern` (`GetItem(row, col).Current.Name`
  for each cell) printed as text — not a screenshot of the grid.
  ```powershell
  $gridPat = $gridEl.GetCurrentPattern([System.Windows.Automation.GridPattern]::Pattern)
  $rows = $gridPat.Current.RowCount; $cols = $gridPat.Current.ColumnCount
  for ($r=0; $r -lt $rows; $r++) {
      $cells = for ($c=0; $c -lt $cols; $c++) { $gridPat.GetItem($r,$c).Current.Name }
      Write-Host ($cells -join " | ")
  }
  ```
- **Screenshots are still fine when there's genuinely no text-based alternative** — a truly
  custom-drawn/non-UIA-exposed region, or a brand-new unmapped screen with no accessible source to
  read first. Reach for `WG-UIDiscovery.ps1`-style enumeration before a screenshot even then; a
  screenshot is the last tool, not the first.
- This also means doing the source read *before* the first PowerShell attempt, not reactively
  after a few failed guesses — read once, act correctly, verify in text.

## 1. What's installed, where

- **App:** `C:\Webgility\UnifyEnterprise\Unify.exe` — Webgility v9.10 (confirmed running as
  `9.10.8`), the real installed build, not a repo-clone debug session. Desktop shortcut:
  `Webgility v9.10.lnk`.
- **Credentials:** Windows user env var **`WD_CREDS`**, format `un:<email>, pwd:<password>` (same
  convention as `QBD_CREDS` — see `wd-local-diagnostics` §4). Reference by name only, never print
  the value — parse it in-script and confirm only lengths, as done below.
- **DB this installed instance actually uses** (confirmed by reading `C:\Webgility\UnifyEnterprise\XML\apiConfig.xml`
  directly rather than assuming): `UnifyDB` on `WGIN-NTB-276\SQLEXPRESS` — the same safe local
  sandbox the rest of this system already treats as full-read/write (`wd-local-diagnostics` §3).
  **Still confirm this on any other machine/instance** before writing — don't assume every install
  points at the sandbox.

## 2. Proven login recipe (confirmed working 2026-10-16)

```powershell
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Start-Process "C:\Webgility\UnifyEnterprise\Unify.exe"
# The Login window can take ~8-10s to appear - don't poll too early (a check at 3s found nothing).
Start-Sleep -Seconds 9

$desktop = [System.Windows.Automation.AutomationElement]::RootElement
$all = $desktop.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
$loginWin = $all | Where-Object {
    $proc = try { (Get-Process -Id $_.Current.ProcessId -ErrorAction Stop).ProcessName } catch { "" }
    $proc -eq "Unify" -and $_.Current.Name -eq "Login"
} | Select-Object -First 1

$creds = [System.Environment]::GetEnvironmentVariable("WD_CREDS","User")
if ($creds -match "un:\s*([^,]+)\s*,\s*pwd:\s*(.+)$") { $un = $matches[1].Trim(); $pwd = $matches[2].Trim() }

function Get-ById($root, $id) {
    $c = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $id)
    return $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $c)
}
function Set-Val($el, $val) {
    $pat = ($el.GetSupportedPatterns() | Where-Object { $_.ProgrammaticName -match "ValuePattern" })
    if ($pat) { ($el.GetCurrentPattern($pat[0])).SetValue($val) }
}
function Invoke-El($el) {
    $pat = ($el.GetSupportedPatterns() | Where-Object { $_.ProgrammaticName -match "InvokePattern" })
    if ($pat) { ($el.GetCurrentPattern($pat[0])).Invoke() }
}

Set-Val (Get-ById $loginWin "txtUserName") $un
Set-Val (Get-ById $loginWin "txtPassword") $pwd
Start-Sleep -Milliseconds 500
Invoke-El (Get-ById $loginWin "btnLogin")
Start-Sleep -Seconds 10   # main dashboard takes a few seconds to render after Login
```

**Confirmed login window element `AutomationId`s** (the `Name` property on the two text fields is
misleadingly "Forgot password?" — a UIA quirk; target by `AutomationId`, not `Name`):
`txtUserName`, `txtPassword`, `btnLogin`, `chkRemember` (Remember me), `Btn_CancelLogin`,
`lnkForgotPassword`.

**Confirming login actually succeeded** (don't just assume the click worked):
```powershell
$mainWin = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children,
    (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $loginWin.Current.ProcessId)))
Write-Host "Main window: $($mainWin.Current.Name)"   # "Webgility <version> (<email>)" on success
$homeBtn = $mainWin.FindFirst([System.Windows.Automation.TreeScope]::Descendants,
    (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Home")))
Write-Host "Dashboard ready: $([bool]$homeBtn)"
```
**Gotcha: don't name a variable `$home`** — it's a PowerShell automatic/reserved variable
(`Cannot overwrite variable HOME because it is read-only`); use `$homeBtn`/`$mainWin` etc.
(`UiStepRunner.cs`'s own generated script already gets this right — follow its naming.)

## 3. CRITICAL — focus is not guaranteed; verify before every click

**A real near-miss happened building this (2026-10-16), document this before anything else.**
`SetForegroundWindow(targetHwnd)` can return without error while **silently failing to actually
change the foreground window** — Windows' foreground-lock-timeout restriction blocks a background
process from stealing focus from the user's actually-active app. When this happened here, every
subsequent "click" (screen-coordinate based) landed on **Slack**, which was the real foreground
window, not on WD at all — confirmed by screenshotting and finding a Slack "Forward this private
message" dialog instead of the expected WD dialog. No harm resulted that time (nothing was typed
or submitted into Slack — the dialog was already open from Krishna's own prior use), but this is a
real way to accidentally interact with the wrong application.

**Mandatory sequence before any click, every time:**
1. `AttachThreadInput` the calling thread to the *current* foreground window's thread — this is
   the standard, legitimate way to be allowed to steal focus (plain `SetForegroundWindow` alone is
   not reliable).
2. Call `SetForegroundWindow(targetHwnd)` + `BringWindowToTop(targetHwnd)`.
3. **Verify**: `GetForegroundWindow() -eq $targetHwnd`. If false, retry (up to ~5x with ~400ms
   delays) — do **not** proceed to click on an unverified guess.
4. If it never matches, **abort without clicking** and say so — don't fall back to coordinate
   guessing hoping it'll land right.
5. **Do this focus-force-and-verify inside the *same* script execution as the click that follows
   it.** Each `PowerShell`/`Bash` tool call is a brand-new process — forced foreground state does
   **not** persist across separate tool calls (confirmed: forced focus, returned, then
   screenshotted in a new call — Slack was back in front). Split "focus" and "click" across two
   tool calls and the click is unverified again.

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class WgFocus {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
}
"@
$match = $false
for ($i = 0; $i -lt 5 -and -not $match; $i++) {
    $fgHwnd = [WgFocus]::GetForegroundWindow()
    $fgPid = 0
    $fgTid = [WgFocus]::GetWindowThreadProcessId($fgHwnd, [ref]$fgPid)
    $myTid = [WgFocus]::GetCurrentThreadId()
    [WgFocus]::AttachThreadInput($myTid, $fgTid, $true) | Out-Null
    [WgFocus]::SetForegroundWindow($targetHwnd) | Out-Null
    [WgFocus]::BringWindowToTop($targetHwnd) | Out-Null
    Start-Sleep -Milliseconds 400
    $match = ([WgFocus]::GetForegroundWindow() -eq $targetHwnd)
    [WgFocus]::AttachThreadInput($myTid, $fgTid, $false) | Out-Null
    if (-not $match) { Start-Sleep -Milliseconds 400 }
}
if (-not $match) { Write-Error "Could not focus target - aborting, no click sent"; exit 1 }
# ... click logic goes here, same script ...
```

**Also prefer `InvokePattern` over coordinate clicks whenever the element is reachable via
UIA** (`$el.GetCurrentPattern($invokePattern).Invoke()`) — it worked reliably for menu items and
buttons here and sidesteps pixel-geometry and DPI/window-position guessing entirely. Reserve raw
`mouse_event`/`SetCursorPos` clicks for controls with no Invoke/Value pattern (confirmed needed for
the custom split-button in §5 below).

**If a screenshot is genuinely needed anyway** (see §0 — it should be rare): capture the window's
*current* `BoundingRectangle` fresh each time, not a cached/hardcoded region — a dialog can render
beyond the main window's own bounds (the order-result dialog's buttons were cut off once when
cropping to a stale rect). When in doubt, screenshot the full
`[System.Windows.Forms.Screen]::PrimaryScreen.Bounds` instead of a guessed crop.

## 4. Observing results — don't screen-scrape, verify independently

Once a UI action is driven, confirm the *outcome* via a source independent of the UI's own success
message:
- **The database directly** — the authoritative record. For order data: table is **`Store_Orders`**
  (not `Orders`, not `FlexiOrderMaster` — both looked plausible and were wrong; confirmed by
  querying `INFORMATION_SCHEMA.TABLES`). Useful columns: `OnlineOrderID`, `OrderNo`, `IDProfiles`,
  `StoreName`, `StoreType`, `OrderStatus`, `CreatedDateTime`, and **`OrderHistory`** — a
  human-readable audit log WD itself writes, e.g. `"[10/16/2026 : 08:09:25 PM]
  [krishna.bankar@webgility.com] : Order received with { open } status and Order downloaded
  Manually and IPAddress is ... and system user krishna.bankar."` — this is the single best
  confirmation line: it shows WD itself logged the action as a normal manual download by that user,
  indistinguishable from a human doing it.
  ```sql
  SELECT idOrders, OrderNo, OnlineOrderID, IDProfiles, StoreName, OrderStatus, CreatedDateTime, OrderHistory
  FROM Store_Orders WHERE OnlineOrderID = '<id>'
  ```
  via `mssql-sqlauth`'s `execute_query` tool (`database: "UnifyDB"`).
- **WD's own log files** — `wd-local-diagnostics` §1 has the exact paths/naming (manual
  `_Error`/`_Info`/`_Debug`/`_Warn`, scheduler `ProcessingLog`/`ErrorLog`). Clear the relevant log
  first (§1a) so the run produces an unambiguous trace.

Reading a result grid back via UIA `GridPattern` (text, see §0) is cheap and fine to do as a quick
first check, but prefer DB/log confirmation whenever the outcome is also recorded there — it's what
actually happened, not what the UI merely displayed.

## 5. Proven case: download an order by OnlineOrderID (end to end, 2026-10-16)

Full element map and gotchas, discovered partly from the live app (`WG-UIDiscovery.ps1`-style
enumeration) and partly by reading the actual source when the live behavior didn't match
assumptions (`frmDashboard.Designer.cs`, `TemplateControls/eCCFlatButton.cs`) — **when instructions
and the live UI don't match, read the unify-enterprise source rather than guessing.**

1. **"Get New Orders" is a custom split button**, not a standard WinForms `SplitButton` —
   `AutomationId` `spltBtn_GetNewOrders`, a `TemplateControls.eCCFlatButton` with
   `ButtonStyleType.Split` and `SplitWidth=20`. It exposes only `InvokePattern` via UIA (no
   `ExpandCollapsePattern`), because the split-zone hit-testing is custom code in
   `eCCFlatButton.OnMouseUp`: `splitRect = Rectangle(Width-SplitWidth, 0, SplitWidth, Height)` —
   i.e. the rightmost 20px of a 120px-wide button. **A coordinate click in that exact zone is
   required** (no UIA shortcut exists for opening this dropdown) — click at roughly
   `button.X + 110` (still inside the 100-120 zone, safely clear of the edge), vertical center.
2. Clicking that zone opens a `ToolStripDropDown` with three items (found via `.Designer.cs`):
   `ordersByRangeToolStripMenuItem` ("Orders by Range"), **`ordersByOrderToolStripMenuItem`
   ("Orders by ID", handler `OrdersByIDToolStripMenuItem_Click`)**, `ordersByQuoteToolStripMenuItem`
   ("Orders by Quote ID"). These items *do* support `InvokePattern` once the dropdown is open —
   find by `Name` across the whole `$desktop` (they aren't scoped under the main window in the UIA
   tree while the dropdown is a transient popup) and `.Invoke()` them.
3. This opens **"Get Order by Order #"**, `AutomationId` `frmProcessUsingBarcode` — **not a
   top-level Desktop window**, it's an MDI-child/embedded window reachable only as a *descendant*
   of the main window (`RootElement.Children` won't find it; search `$mainWin.FindAll(...Descendants...)`).
   Controls: `txtOrderNoBarcode` (Edit, the ID input), `btnAddIntoList` ("Add"), `lstOrderNo` (List,
   "Search Criteria:"), `btnGetORder` ("Get Orders"), `BtnRemove` ("Remove").
4. **The ID must go through "Add" before "Get Orders" does anything** — set the value in
   `txtOrderNoBarcode`, invoke `btnAddIntoList`, **verify the id now appears as an item inside
   `lstOrderNo`** (`$listEl.FindAll(...Descendants...)`), *then* invoke `btnGetORder`. Skipping
   straight to "Get Orders" with only the textbox filled (not added to the list) produces an
   info dialog: *"Please select order to proceed further"* — not an error about the order itself,
   just "there's nothing in the list to process."
5. On success, a separate result window (titled with the app version, e.g. `"9.10.8"`) shows a grid
   with columns `ORDER #` / `STATUS` / `MESSAGE`, e.g. `QAS1509 | Success | Order downloaded
   Successfully.` — has a `"Close"` button (`Name="Close"`, searchable from `$desktop` since it's
   its own top-level window this time).
6. **Confirmed independently via the DB** (§4) — the order landed in `Store_Orders` with
   `OnlineOrderID` matching exactly, `OrderHistory` logging it as a manual download by the logged-in
   user, timestamp matching to the second.

## 6. Why this works: existing WD infrastructure, not new R&D

Confirmed in `unify-enterprise` itself — this isn't hypothetical tooling, it's the same mechanism
WD's own team already ships, for a different purpose (the embedded support chatbot's self-service
fixes):
- **`Desktop/eCC/Tools/WG-UIDiscovery.ps1`** — walks the live app's UI tree and dumps every
  control's `Name`/`ControlType`/`AutomationId`/supported patterns to a file. Run this once against
  a real running instance before automating any *new* screen — don't guess element names from the
  `.Designer.cs` source alone (see the login-field `Name` quirk, and the split-button zone in §5,
  which needed the actual control source, not just Designer output).
- **`Desktop/WgUtility/Troubleshoot/UiStepRunner.cs`** — a full declarative step engine
  (`focusApp`/`clickMenu`/`clickTab`/`clickButton`/`selectItem`/`setText`/`checkBox`/`wait`/
  `sendKeys`/`clickById`) that generates and runs a PowerShell script (via a child `powershell.exe`
  process — its own comment explains why: in-process UIAutomation on the UI thread can deadlock)
  against the real Webgility window. Read it for the exact PowerShell patterns (window-finding with
  fallback, closing stray dialogs, returning to the dashboard via "Home" before each sequence).
- **`Desktop/eCC/ChatSupport/errorcode-kb.json`** — 145 support-chatbot KB entries with an
  `automationSteps` schema designed for exactly this (none currently populate it, confirmed via
  grep — this is live infrastructure ahead of its current usage, not dead code).

**Don't reinvent the step engine** — for anything beyond a one-off script, prefer generating a
`UiStep` list and running it through `UiStepRunner`'s own pattern (or literally reusing its
generated-script shape), since it already handles stray-dialog cleanup and returning to a
known-good starting screen. Note `UiStepRunner` itself does **not** yet implement the §3
focus-verification safety gate — add it there too if this engine is driven through that class
rather than hand-written scripts going forward.

## 7. Next steps (not yet done)

- Wire the §3 focus-verification gate into `UiStepRunner.cs` itself (currently only in this skill's
  hand-written scripts).
- Other "Get New Orders" variants (`Orders by Range`, `Orders by Quote ID`) follow the same dialog
  pattern (likely) — not yet individually mapped.
- Decide whether this ever needs wrapping as a formal MCP tool, or stays as PowerShell driven
  directly per-task — the UI-automation technique itself needs no new server (the
  `setup-qbd-sellfromhome.md`-style classifier-blocked handoff doesn't apply here; this is just the
  `PowerShell` tool already available).
