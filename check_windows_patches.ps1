<#
.SYNOPSIS
  Scans for available Windows updates and writes a report.

.DESCRIPTION
  Installs PSWindowsUpdate module if missing, then lists all available updates
  (including Microsoft Update catalog) and writes them to a file.

.NOTES
  Requires administrative privileges.
#>

# Parameters
$ScriptDir = "C:\Scripts"
$OutputFile = Join-Path $ScriptDir "available_updates.txt"

# Ensure output directory exists
if (-not (Test-Path $ScriptDir)) {
    New-Item -Path $ScriptDir -ItemType Directory | Out-Null
}

# Install PSWindowsUpdate module if not present
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
}
Import-Module PSWindowsUpdate

# Start scan
"=== Windows Update Scan Report ===" | Out-File $OutputFile
"Generated at: $(Get-Date)"    | Out-File $OutputFile -Append
""                              | Out-File $OutputFile -Append

# List available updates
$updates = Get-WindowsUpdate -MicrosoftUpdate -IgnoreReboot -AcceptAll -ListOnly
if (-not $updates) {
    "No updates available." | Out-File $OutputFile -Append
} else {
    $updates | ForEach-Object {
        "{0} | {1} | {2}" -f $_.KBArticleID, $_.Title, $_.Size | Out-File $OutputFile -Append
    }
}
