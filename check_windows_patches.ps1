<#
.SYNOPSIS
  Scans Windows updates via PSWindowsUpdate.

.PARAMETER InstanceId
  The EC2 Instance ID (passed in from your workflow).

#>
param(
  [Parameter(Mandatory=$true)]
  [string]$InstanceId
)

# Where we’ll drop our log
$PatchDir = 'C:\Windows\System32\Patch'
if (!(Test-Path $PatchDir)) {
  New-Item -Path $PatchDir -ItemType Directory -Force | Out-Null
}

# Timestamp header
$now = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
Write-Output "=== Windows Patches Scan for $InstanceId ($now) ==="

# 1) Ensure PSWindowsUpdate is available
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
  Write-Output "[INFO] PSWindowsUpdate module not found; installing from PSGallery..."
  # Trust the gallery if necessary
  if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
    Register-PSRepository -Default
  }
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

  Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -ErrorAction Stop
}

Import-Module PSWindowsUpdate -ErrorAction Stop

# 2) Perform a scan
Write-Output "[INFO] Scanning for available updates..."
try {
  $updates = Get-WUList -MicrosoftUpdate -ErrorAction Stop
} catch {
  Write-Error "Failed to scan updates: $_"
  exit 1
}

# 3) Output results
if ($updates.Count -gt 0) {
  $updates | ForEach-Object {
    # e.g. KB description and title
    Write-Output ("{0} - {1}" -f $_.KB, $_.Title)
  }
} else {
  Write-Output "No updates available."
}

exit 0
