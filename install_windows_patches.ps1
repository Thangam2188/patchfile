param(
  [string]$InstanceId
)

$PatchDir   = "C:\Windows\System32\Patch\Execution"
$PatchFile  = Join-Path $PatchDir "$InstanceId`_patchscan.txt"
$LogFile    = Join-Path $PatchDir "Execution\patch_install_log.txt"

function Log {
  param([string]$msg)
  $time = Get-Date -Format "[yyyy-MM-dd HH:mm:ss]"
  "$time $msg" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

Log "=== Starting patch install for $InstanceId ==="

if (-not (Test-Path $PatchFile)) {
  Log "❌ No patch file found at $PatchFile; skipping install."
  exit 1
}

# Ensure PSWindowsUpdate module is available
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
  Log "❌ PSWindowsUpdate module is not installed. Cannot proceed."
  exit 1
}

Import-Module PSWindowsUpdate

# Extract KBs from the scan file (even if comma-separated)
$kbList = @()
try {
  Get-Content $PatchFile | ForEach-Object {
    ($_ -split "[, ]") | ForEach-Object {
      if ($_ -match "^KB\d{6,}$") {
        $kbList += $_.Trim()
      }
    }
}
catch {
  Log "❌ Failed to read or parse the patch scan file."
  exit 1
}

if ($kbList.Count -eq 0) {
  Log "⚠️ No valid KBs found in the scan file. Exiting."
  exit 0
}

Log "✔ KBs found in patch file: $($kbList -join ', ')"

# Retrieve available updates
$availableUpdates = Get-WindowsUpdate -MicrosoftUpdate -IgnoreReboot | Where-Object {
  $_.KBArticleIDs -ne $null -and $_.KBArticleIDs.Count -gt 0
}

# Match KBs
$updatesToInstall = $availableUpdates | Where-Object {
  foreach ($kb in $kbList) {
    if ($_.KBArticleIDs -contains $kb) {
      return $true
    }
  }
  return $false
}

if ($updatesToInstall.Count -eq 0) {
  Log "⚠️ None of the requested KBs were found as available updates."
  exit 0
}

# Install filtered updates
try {
  Log "⬇ Installing $($updatesToInstall.Count) filtered updates..."
  $updatesToInstall | Install-WindowsUpdate -AcceptAll -AutoReboot -IgnoreReboot
  Log "✅ Installation complete."
}
catch {
  Log "❌ Error during installation: $_"
  exit 1
}
