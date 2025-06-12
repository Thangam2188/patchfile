<#
.SYNOPSIS
  Installs Windows updates from the scan report.

.DESCRIPTION
  Reads the list of KB IDs from available_updates.txt, installs them,
  and logs output and errors to a log file.

.NOTES
  Requires administrative privileges and PSWindowsUpdate module.
#>

param (
    [string]$ScriptDir = "C:\Scripts"
)

$PatchList   = Join-Path $ScriptDir "available_updates.txt"
$LogFile     = Join-Path $ScriptDir "install_log.txt"

function Log($msg) {
    $ts = Get-Date -Format "[yyyy-MM-dd HH:mm:ss]"
    "$ts $msg" | Out-File $LogFile -Append
}

# Ensure script directory exists
if (-not (Test-Path $ScriptDir)) {
    New-Item -Path $ScriptDir -ItemType Directory | Out-Null
}

Log "=== Starting patch installation ==="

if (-not (Test-Path $PatchList)) {
    Log "WARN: Patch list not found at $PatchList"
    exit 0
}

# Read KB IDs
$kbIDs = Get-Content $PatchList | ForEach-Object {
    if ($_ -match "^KB\d+") { $matches[0] }
}

if (-not $kbIDs) {
    Log "INFO: No patches to install."
    exit 0
}

# Ensure PSWindowsUpdate module
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
}
Import-Module PSWindowsUpdate

# Install updates
foreach ($kb in $kbIDs) {
    Log "Installing $kb..."
    try {
        Install-WindowsUpdate -KBArticleID $kb -AcceptAll -IgnoreReboot -ErrorAction Stop -Verbose |
          Out-File $LogFile -Append
        Log "SUCCESS: Installed $kb"
    } catch {
        Log "ERROR: Failed to install $kb - $($_.Exception.Message)"
    }
}

Log "=== Patch installation completed ==="
