<#
  finish-rename.ps1  -  final step of the AskAI -> KrishnaAiGen rename

  Everything inside the repo is already renamed and committed-ready: the solution,
  the three projects, all C# namespaces, and every path reference in the docs, the
  plugin marketplace and the scripts. The build and all 36 tests pass.

  The only thing left is the folder itself, which Windows refuses to rename while a
  process has it as its working directory (typically the VS Code window that has
  C:\WG-Agentic open, or a terminal sitting inside AskAI).

  RUN THIS AFTER CLOSING VS CODE / CURSOR / any terminal inside the folder.
  Run it from somewhere else entirely, e.g. C:\  -  not from inside WG-Agentic.

      powershell -ExecutionPolicy Bypass -File "C:\WG-Agentic\AskAI\.claude\scripts\finish-rename.ps1"

  Safe to re-run: every step checks whether it is already done.
  Add -WhatIf to see what it would do without touching anything.

  Add -UpdateRemote only AFTER you have renamed the repo on GitHub
  (github.com -> AskAI -> Settings -> Repository name -> KrishnaAiGen).
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [switch]$UpdateRemote
)

$ErrorActionPreference = 'Stop'

$OldName = 'AskAI'
$NewName = 'KrishnaAiGen'
$Trees   = @('C:\WG-Agentic', 'C:\WG-Agentic 2')
$NewUrl  = 'https://github.com/krishnabankar-webgility/KrishnaAiGen.git'

function Step($msg) { Write-Host "  $msg" }
function Ok($msg)   { Write-Host "  $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  $msg" -ForegroundColor Yellow }

$problems = @()

foreach ($tree in $Trees) {
  Write-Host ''
  Write-Host $tree -ForegroundColor Cyan

  if (-not (Test-Path -LiteralPath $tree)) { Warn 'tree not present, skipped'; continue }

  $old = Join-Path $tree $OldName
  $new = Join-Path $tree $NewName

  # ---- 1. rename the folder -------------------------------------------------
  if (Test-Path -LiteralPath $new) {
    Ok "$NewName already exists"
    if (Test-Path -LiteralPath $old) {
      Warn "BOTH $OldName and $NewName exist - resolve by hand, nothing was changed"
      $problems += "$tree has both folders"
      continue
    }
  }
  elseif (Test-Path -LiteralPath $old) {
    if ($PSCmdlet.ShouldProcess($old, "rename to $NewName")) {
      try {
        Rename-Item -LiteralPath $old -NewName $NewName -ErrorAction Stop
        Ok "renamed $OldName -> $NewName"
      } catch {
        Warn "STILL LOCKED: $($_.Exception.Message)"
        Warn 'Close every editor and terminal with that folder open, then re-run.'
        $problems += "$tree folder still locked"
        continue
      }
    }
  }
  else {
    Warn "neither $OldName nor $NewName found, skipped"
    continue
  }

  # ---- 2. workspace-root repo: move the submodule gitlink --------------------
  if (Test-Path -LiteralPath (Join-Path $tree '.git')) {
    Push-Location $tree
    try {
      $tracked = (& git ls-files --error-unmatch $OldName 2>$null)
      if ($tracked -and $PSCmdlet.ShouldProcess("$tree\$OldName", 'git mv gitlink')) {
        & git rm --cached -q $OldName 2>$null
        & git add $NewName 2>$null
        Ok "workspace repo: gitlink $OldName -> $NewName staged"
      } else {
        Step 'workspace repo: gitlink already correct or not tracked'
      }
    } catch { Step 'workspace repo: nothing to do' }
    finally { Pop-Location }
  }

  # ---- 3. the clone's own remote --------------------------------------------
  if (Test-Path -LiteralPath (Join-Path $new '.git')) {
    Push-Location $new
    try {
      $cur = (& git remote get-url origin 2>$null)
      if ($UpdateRemote) {
        if ($cur -eq $NewUrl) { Ok 'origin already points at KrishnaAiGen' }
        elseif ($PSCmdlet.ShouldProcess('origin', "set-url $NewUrl")) {
          & git remote set-url origin $NewUrl
          Ok "origin -> $NewUrl"
        }
      } else {
        Step "origin left as: $cur"
        Step '(re-run with -UpdateRemote after renaming the repo on GitHub)'
      }
    } finally { Pop-Location }
  }
}

# ---- 4. report ---------------------------------------------------------------
Write-Host ''
if ($problems.Count -eq 0) {
  Write-Host 'Rename complete.' -ForegroundColor Green
  Write-Host ''
  Write-Host 'Next:' -ForegroundColor Cyan
  Write-Host '  1. Reopen your editor on C:\WG-Agentic (the old path no longer exists).'
  Write-Host '  2. Install the plugins - see KrishnaAiGen\plugins\README.md:'
  Write-Host '       /plugin marketplace add C:\WG-Agentic\KrishnaAiGen'
  Write-Host '       /plugin install krishna-core@krishnaaigen'
  Write-Host '       /plugin install wd-core@krishnaaigen'
  Write-Host '  3. In C:\WG-Agentic 2\KrishnaAiGen the FILES are still named AskAI.'
  Write-Host '     Commit and push tree 1 first, then run git pull there.'
} else {
  Write-Host 'Finished with problems:' -ForegroundColor Yellow
  $problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
