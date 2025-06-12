<#
.SYNOPSIS
  Scans Windows for available Critical and Security updates.
.PARAMETER InstanceId
  (Optional) EC2 Instance ID for logging.
#>

param(
  [string]$InstanceId = $(Throw "Please supply -InstanceId")
)

# 1) Make sure TLS1.2 is used (required for PowerShell Gallery)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2) Trust PSGallery and install NuGet provider if needed
if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
    Register-PSRepository -Default
}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

# 3) Auto-install PSWindowsUpdate if missing
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Output "[INFO] Installing PSWindowsUpdate module..."
    Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -ErrorAction Stop
}

# 4) Import it (or fall back)
try {
    Import-Module PSWindowsUpdate -ErrorAction Stop
    $usePSWU = $true
} catch {
    Write-Warning "[WARN] PSWindowsUpdate import failed: $_"
    $usePSWU = $false
}

# 5) Header
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Output "=== Windows Patch Scan for $InstanceId at $now ==="

if ($usePSWU) {
    # Use PSWindowsUpdate to list only Security & Critical updates
    Get-WUList -MicrosoftUpdate -Classification SecurityUpdates,CriticalUpdates |
      Select-Object KB, Title, Size, @{n='Severity';e={$_.MsrcSeverity}}
} else {
    # Fall back to COM-based search for Security category
    $session  = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $secCat   = '0fa1201d-4330-4fa8-8ae9-b877473b6441'  # Security Updates GUID
    $query    = "IsInstalled=0 and IsHidden=0 and CategoryIDs contains '$secCat'"
    $result   = $searcher.Search($query)
    foreach ($u in $result.Updates) {
        "{0}  {1}" -f $u.KBArticleIDs[0], $u.Title
    }
}
