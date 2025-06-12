param(
  [string]$InstanceId
)

$OutputDir  = "C:\Windows\System32\Patch"
$OutputFile = Join-Path $OutputDir "$InstanceId`_patchscan.txt"

"=== Windows Patches Scan for $InstanceId ($(Get-Date)) ===" |
  Out-File -FilePath $OutputFile -Encoding UTF8

# Use the SSM patch baseline scan results or custom logic here.
# For demonstration, we’ll list pending updates via PSWindowsUpdate module:
if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
  Import-Module PSWindowsUpdate
  Get-WindowsUpdate -MicrosoftUpdate -AcceptAll |
    Select-Object -Property Title,KB,Size |
    Out-File -FilePath $OutputFile -Append -Encoding UTF8
} else {
  "PSWindowsUpdate module not installed; no detailed scan performed." |
    Out-File -FilePath $OutputFile -Append -Encoding UTF8
}
