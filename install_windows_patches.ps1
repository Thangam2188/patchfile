param(
  [string]$InstanceId
)

$PatchDir   = "C:\Windows\System32\Patch"
$PatchFile  = Join-Path $PatchDir "$InstanceId`_patchscan.txt"
$LogFile    = Join-Path $PatchDir "patch_install_log.txt"

function Log {
  param([string]$msg)
  $time = Get-Date -Format "[yyyy-MM-dd HH:mm:ss]"
  "$time $msg" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

Log "=== Starting patch install for $InstanceId ==="

if (-not (Test-Path $PatchFile)) {
  Log "No patch file found at $PatchFile; skipping install."
  exit 0
}

# Example: install all missing Windows updates
# Requires PSWindowsUpdate module
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
  Log "PSWindowsUpdate module missing; cannot auto-install."
  exit 1
}

Import-Module PSWindowsUpdate
try {
  Log "Installing updates..."
  $results = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -AutoReboot
  Log ($results | Out-String)
  Log "=== Installation completed successfully ==="
} catch {
  Log "ERROR during installation: $_"
  exit 1
}
