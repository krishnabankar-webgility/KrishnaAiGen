<#
  sync-workspace.ps1

  Distributes the generated workspace config from this repo (the source of truth)
  into both working trees. Safe to re-run; it only writes files it owns.

  What it writes:
    <tree>\<repo>\.mcp.json   from KrishnaAiGen\.claude\mcp\wg-mcp.json
    <tree>\CLAUDE.md          from C:\WG-Agentic\CLAUDE.md (tree 2 gets a marked copy)

  What it never touches:
    wg-ai-workspace\.mcp.json  - the team's own config, still used when you open
                                 Claude directly in that repo
    any CLAUDE.md inside a team repo

  Usage:
    powershell -ExecutionPolicy Bypass -File KrishnaAiGen\.claude\scripts\sync-workspace.ps1
    ... -WhatIf     show what would change without writing
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

$Source   = 'C:\WG-Agentic\KrishnaAiGen\.claude\mcp\wg-mcp.json'
$RootDoc  = 'C:\WG-Agentic\CLAUDE.md'
$Trees    = @('C:\WG-Agentic', 'C:\WG-Agentic 2')
$Repos    = @('KrishnaAiGen', 'unify-enterprise', 'cloud-integration-systems')
$Skip     = @('wg-ai-workspace')

if (-not (Test-Path -LiteralPath $Source)) {
  throw "Source MCP config not found: $Source"
}

# Fail fast on malformed JSON rather than distributing a broken config.
try { Get-Content -LiteralPath $Source -Raw | ConvertFrom-Json | Out-Null }
catch { throw "Source MCP config is not valid JSON: $Source`n$($_.Exception.Message)" }

$written = 0
$skipped = 0

foreach ($tree in $Trees) {
  if (-not (Test-Path -LiteralPath $tree)) {
    Write-Host "skip tree (not present): $tree" -ForegroundColor DarkGray
    continue
  }

  foreach ($repo in $Repos) {
    $dir = Join-Path $tree $repo
    if (-not (Test-Path -LiteralPath $dir)) { $skipped++; continue }
    if ($Skip -contains $repo) { $skipped++; continue }

    $dest = Join-Path $dir '.mcp.json'
    $new  = Get-Content -LiteralPath $Source -Raw
    $old  = if (Test-Path -LiteralPath $dest) { Get-Content -LiteralPath $dest -Raw } else { $null }

    if ($old -eq $new) {
      Write-Host "up to date  $dest" -ForegroundColor DarkGray
      continue
    }
    if ($PSCmdlet.ShouldProcess($dest, 'write .mcp.json')) {
      [System.IO.File]::WriteAllText($dest, $new, [System.Text.UTF8Encoding]::new($false))
      Write-Host "wrote       $dest" -ForegroundColor Green
      $written++
    }
  }

  # Workspace-root CLAUDE.md
  if ($tree -ne 'C:\WG-Agentic') {
    $dest = Join-Path $tree 'CLAUDE.md'
    if (Test-Path -LiteralPath $RootDoc) {
      $body = Get-Content -LiteralPath $RootDoc -Raw
      $note = "> **Second working tree.** Same clones as ``C:\WG-Agentic``, usually on a different branch.`r`n" +
              "> Generated from ``C:\WG-Agentic\CLAUDE.md`` - edit that one, then re-run ``sync-workspace.ps1``.`r`n`r`n"
      $new  = $body -replace '(?s)^(# WG-Agentic workspace\r?\n\r?\n)', "`$1$note"
      $old  = if (Test-Path -LiteralPath $dest) { Get-Content -LiteralPath $dest -Raw } else { $null }
      if ($old -ne $new -and $PSCmdlet.ShouldProcess($dest, 'write CLAUDE.md')) {
        [System.IO.File]::WriteAllText($dest, $new, [System.Text.UTF8Encoding]::new($false))
        Write-Host "wrote       $dest" -ForegroundColor Green
        $written++
      }
    }
  }
}

Write-Host ''
Write-Host "$written file(s) written, $skipped target(s) skipped." -ForegroundColor Cyan
Write-Host 'Restart Claude Code (or run /mcp) for MCP changes to take effect.' -ForegroundColor Cyan
