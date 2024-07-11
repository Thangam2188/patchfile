$machineName = $env:COMPUTERNAME
$fileName = "${machineName}_missing_patches.json"

# Create a Windows Update session
$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()

# Search for pending updates
$searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")

# Filter for security updates that are Critical or Important
$securityUpdates = $searchResult.Updates | Where-Object {
    $_.MsrcSeverity -eq 'Critical' -or $_.MsrcSeverity -eq 'Important'
}

# Prepare the data to be saved as JSON
$patches = @()
foreach ($update in $securityUpdates) {
    $patches += [PSCustomObject]@{
        Title       = $update.Title
        Description = $update.Description
        KBArticle   = $update.KBArticleIDs -join ', '
        Severity    = $update.MsrcSeverity
        MoreInfo    = $update.MoreInfoUrls -join ', '
    }
}

# Convert patches list to JSON and save to file
$jsonPatches = $patches | ConvertTo-Json -Depth 4
$jsonPatches | Set-Content -Path $fileName

# Add logic to push the JSON file to GitHub here if required
