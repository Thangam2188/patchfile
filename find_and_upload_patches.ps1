# Define GitHub parameters
$token = $env:GITHUB_TOKEN  # Set this as a GitHub Secret in your repository
$repo = "your-username/your-repo-name"
$branch = "main"
$commitMessage = "Add missing patches JSON file"

# Function to push file to GitHub
function Push-ToGitHub {
    param (
        [string]$token,
        [string]$repo,
        [string]$branch,
        [string]$filePath,
        [string]$commitMessage
    )
    
    $fileName = Split-Path $filePath -Leaf
    $fileContent = [System.IO.File]::ReadAllText($filePath)
    $fileContentBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($fileContent))

    $uri = "https://api.github.com/repos/$repo/contents/$fileName"
    $body = @{
        message = $commitMessage
        content = $fileContentBase64
        branch = $branch
    } | ConvertTo-Json

    $headers = @{
        Authorization = "token $token"
        Accept = "application/vnd.github.v3+json"
        User-Agent = "PowerShell"
    }

    Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
}

# Save the JSON file as before
$machineName = $env:COMPUTERNAME
$fileName = "${machineName}_missing_patches.json"

$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()

$searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")

$securityUpdates = $searchResult.Updates | Where-Object {
    $_.MsrcSeverity -eq 'Critical' -or $_.MsrcSeverity -eq 'Important'
}

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

$jsonPatches = $patches | ConvertTo-Json -Depth 4
$jsonPatches | Set-Content -Path $fileName

# Push the JSON file to GitHub
Push-ToGitHub -token $token -repo $repo -branch $branch -filePath $fileName -commitMessage $commitMessage
#final
