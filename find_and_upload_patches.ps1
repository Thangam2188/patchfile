# check_security_patches.ps1

# Define variables
$instanceId = "i-01a7d5d948f6b49c9"
$bucketArn = "arn:aws:s3:::mybuckettest2188"
$region = "us-east-1"
$patchFile = "C:\temp\security_patches.txt"

# Ensure the output directory exists
if (-Not (Test-Path "C:\temp")) {
    New-Item -ItemType Directory -Path "C:\temp"
}

# Function to get available updates
function Get-AvailableUpdates {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
    return $searchResult.Updates
}

# Get available updates
$updates = Get-AvailableUpdates
#check
# Filter security updates that are important or critical
$securityUpdates = $updates | Where-Object {
    ($_.IsSecurityUpdate -eq $true) -and
    ($_.MsrcSeverity -eq 'Critical' -or $_.MsrcSeverity -eq 'Important')
}

# Output the list of important and critical security updates to a file
$securityUpdates | ForEach-Object {
    "$($_.Title) - $($_.MsrcSeverity)" 
} | Out-File -FilePath $patchFile

# Upload the file to S3
aws s3 cp $patchFile "s3://mybuckettest2188/$instanceId/security_patches.txt" --region $region

Write-Host "Security patches have been listed and uploaded to S3."
