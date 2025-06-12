<#
.SYNOPSIS
  Scans Windows updates via PSWindowsUpdate v2.1.1.2 (skipping publisher check) and writes results to disk.

.PARAMETER InstanceId
  The EC2 Instance ID passed in by your workflow.

#>
param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceId
)

# prepare drop-folder and output file
$PatchDir   = 'C:\Windows\System32\Patch'
$outputFile = Join-Path $PatchDir ("{0}_patchscan.txt" -f $InstanceId)

if (-not (Test-Path $PatchDir)) {
    New-Item -Path $PatchDir -ItemType Directory -Force | Out-Null
}

# start fresh
"" | Out-File -FilePath $outputFile -Encoding UTF8

function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts $msg" | Add-Content -Path $outputFile
}

Log "=== Windows Patches Scan for $InstanceId ==="

# ensure PSGallery trusted
if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
    Register-PSRepository -Default
}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

# install exactly v2.1.1.2 if missing (skip publisher check)
$required = '2.1.1.2'
$found    = Get-Module -ListAvailable -Name PSWindowsUpdate | Select-Object -First 1

if (-not $found -or $found.Version.ToString() -ne $required) {
    Log "[INFO] Installing PSWindowsUpdate v$required (skipping publisher check)..."
    if ($found) {
        try { Uninstall-Module PSWindowsUpdate -AllVersions -Force } catch {}
    }
    Install-Module `
      -Name PSWindowsUpdate `
      -RequiredVersion $required `
      -Scope AllUsers `
      -Force `
      -SkipPublisherCheck `
      -ErrorAction Stop
}

Import-Module PSWindowsUpdate -ErrorAction Stop

# run the scan
Log "[INFO] Scanning for available updates..."
try {
    $updates = Get-WUList -MicrosoftUpdate -ErrorAction Stop
} catch {
    Log "[ERROR] Scan failed: $_"
    exit 1
}

# keep only security fixes of Critical or Important severity
$secfixes = $updates |
  Where-Object { $_.Title -match 'Security Update' -and (
        $_.Title -match 'Critical' -or
        $_.Title -match 'Important'
    )
  } |
  Select-Object @{n='KB';e={$_.KB}}, @{n='Title';e={$_.Title}}

if ($secfixes.Count -gt 0) {
    Log "[INFO] Found $($secfixes.Count) security updates:"
    $secfixes | ForEach-Object {
        "{0} - {1}" -f $_.KB, $_.Title | Add-Content -Path $outputFile
    }
} else {
    Log "[INFO] No important or critical security updates available."
}

exit 0
