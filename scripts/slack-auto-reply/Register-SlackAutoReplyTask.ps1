<#
.SYNOPSIS
  Registers the "Slack Auto-Reply" Windows scheduled task: one cycle every 15 minutes, only while the
  user is logged on (the Claude CLI login lives in the user profile). Reading Slack costs nothing; Claude runs
  only for a DM that has waited 30 minutes (config dm_due_minutes). Everything starts as a proposal until you reply `live`.
  Run this yourself, once, from your own PowerShell. It is a standing automation, so it is your call to enable it.

.EXAMPLE
  pwsh -File Register-SlackAutoReplyTask.ps1                  # local PC
  pwsh -File Register-SlackAutoReplyTask.ps1 -Runner vm       # on the VM
  Unregister-ScheduledTask -TaskName 'Slack Auto-Reply' -Confirm:$false   # remove it
#>
param(
  [ValidateSet('local', 'vm')] [string]$Runner = 'local',
  [int]$EveryMinutes = 15
)
$script = Join-Path $PSScriptRoot 'Invoke-SlackAutoReply.ps1'
$pwsh   = (Get-Command pwsh -ErrorAction Stop).Source

$action    = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Runner $Runner"
$trigger   = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 45) `
               -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName 'Slack Auto-Reply' -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
  -Description 'Slack DM auto-reply on Krishna''s behalf (KrishnaAiGen slack-auto-reply skill)' -Force | Out-Null
Write-Host "Registered 'Slack Auto-Reply' ($Runner, every $EveryMinutes min). Logs: $env:USERPROFILE\.claude\slack-auto-reply\logs"
