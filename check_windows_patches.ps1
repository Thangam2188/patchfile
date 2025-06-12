<#
.SYNOPSIS
  Scans Windows updates via PSWindowsUpdate (auto-installs exactly v2.1.1.2 if needed, skipping publisher check).

.PARAMETER InstanceId
  The EC2 Instance ID (passed in from your workflow).

#>
param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceId
)

# Drop-folder
$PatchDir = 'C:\Windows\System32\Patch'
if (-not (Test-Path $PatchDir)) {
    New-Item -Path $PatchDir -ItemType Directory -Force | Out-Null
}

# Header
$now = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
Write-Output "=== Windows Patches Scan for $InstanceId ($now) ==="

# Ensure PSGallery trusted
if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
    Register-PSRepository -Default
}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

# Desired version
$required = '2.1.1.2'
$found = Get-Module -ListAvailable -Name PSWindowsUpdate | Select-Object -First 1

if (-not $found -or $found.Version.ToString() -ne $required) {
    Write-Output "[INFO] Installing PSWindowsUpdate v$required (skipping publisher check)..."
    # Remove any other version
    if ($found) {
        try {
            Uninstall-Module -Name PSWindowsUpdate -AllVersions -Force -ErrorAction Stop
        } catch {
            Write-Warning "[WARN] Could not uninstall existing PSWindowsUpdate: $_"
        }
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

# Scan
Write-Output "[INFO] Scanning for available updates..."
try {
    $updates = Get-WUList -MicrosoftUpdate -ErrorAction Stop
} catch {
    Write-Error "❌ Scan failed: $_"
    exit 1
}

# Filter Critical/Important security fixes
$secfixes = $updates |
    Where-Object { $_.Title -match 'Security Update' -and ($_.Title -match 'Critical' -or $_.Title -match 'Important') } |
    Select-Object @{Name='KB';Expression={$_.KB}}, @{Name='Title';Expression={$_.Title}}

if ($secfixes.Count -gt 0) {
    $secfixes | ForEach-Object { "{0} - {1}" -f $_.KB, $_.Title }
} else {
    Write-Output "No important or critical security updates available."
}

exit 0
