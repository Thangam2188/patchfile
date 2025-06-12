<#
.SYNOPSIS
  Scans only Critical & Security Windows updates via PSWindowsUpdate 
  (auto-installs module if needed).

.PARAMETER InstanceId
  The EC2 Instance ID (passed in from your workflow).

#>
param(
  [Parameter(Mandatory=$true)]
  [string]$InstanceId
)

#  ——————————————————————————————————————————————————————————————
#  Setup
#  ——————————————————————————————————————————————————————————————
$PatchDir = 'C:\Windows\System32\Patch'
if (-not (Test-Path $PatchDir)) {
    New-Item -Path $PatchDir -ItemType Directory -Force | Out-Null
}

$now = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
Write-Output "=== Windows Security Scan for $InstanceId at $now ==="

#  ——————————————————————————————————————————————————————————————
#  Ensure PSWindowsUpdate is available
#  ——————————————————————————————————————————————————————————————
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Output "[INFO] PSWindowsUpdate not found; installing..."
    if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
        Register-PSRepository -Default
    }
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -ErrorAction Stop
}
Import-Module PSWindowsUpdate -ErrorAction Stop

#  ——————————————————————————————————————————————————————————————
#  Perform the scan, filtering to Critical + Security updates only
#  ——————————————————————————————————————————————————————————————
Write-Output "[INFO] Scanning for Critical & Security updates..."
try {
    $updates = Get-WUList `
        -MicrosoftUpdate `
        -Classification CriticalUpdates,SecurityUpdates `
        -ErrorAction Stop
} catch {
    Write-Error "❌ Scan failed: $_"
    exit 1
}

#  ——————————————————————————————————————————————————————————————
#  Emit results
#  ——————————————————————————————————————————————————————————————
if ($updates.Count -gt 0) {
    $updates | ForEach-Object {
        # Each update object has KB and Title
        "{0}  {1}" -f $_.KB, $_.Title
    }
} else {
    Write-Output "No Critical or Security updates available."
}

exit 0
