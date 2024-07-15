param (
    [string]$InstanceId = "i-01a7d5d948f6b49c9",
    [string]$BucketArn = "arn:aws:s3:::mybuckettest2188",
    [string]$AWSRegion = "us-east-1"
)

# Function to get patch states for the instance
function Get-PatchState {
    param (
        [string]$InstanceId,
        [string]$AWSRegion
    )
    Write-Output "Retrieving patch states for instance $InstanceId in region $AWSRegion"

    $patchStateCommand = "aws ssm describe-instance-patch-states --instance-ids $InstanceId --region $AWSRegion"
    try {
        $result = Invoke-Expression $patchStateCommand
        $patchState = ($result | ConvertFrom-Json).InstancePatchStates[0]
        return $patchState
    } catch {
        Write-Error "Failed to retrieve patch state: $_"
        exit 1
    }
}

# Function to upload file to S3
function Upload-ToS3 {
    param (
        [string]$BucketArn,
        [string]$FilePath,
        [string]$AWSRegion
    )
    Write-Output "Uploading $FilePath to S3 bucket $BucketArn"
    $bucketName = $BucketArn -replace "arn:aws:s3:::",""
    $s3Command = "aws s3 cp $FilePath s3://$bucketName/ --region $AWSRegion"
    try {
        Invoke-Expression $s3Command
    } catch {
        Write-Error "Failed to upload to S3: $_"
        exit 1
    }
}

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
        Authorization = "Bearer $token"
        Accept = "application/vnd.github.v3+json"
        "User-Agent" = "PowerShell"
        "Content-Type" = "application/json"
    }

    try {
        $response = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
        Write-Output "File pushed to GitHub successfully."
    } catch {
        Write-Error "Failed to push to GitHub: $_. Response: $($response | ConvertTo-Json -Compress)"
        exit 1
    }
}

# Main script execution
try {
    # Check if GITHUB_TOKEN environment variable is set
    $token = $env:GITHUB_TOKEN
    if (-not $token) {
        Write-Error "GitHub token not set. Please set the GITHUB_TOKEN environment variable."
        exit 1
    }

    # Retrieve patch state
    $patchState = Get-PatchState -InstanceId $InstanceId -AWSRegion $AWSRegion

    # Save the output to a file
    $fileName = "${InstanceId}_patch_state_output.json"
    $patchState | ConvertTo-Json -Compress | Set-Content -Path $fileName

    # Upload JSON file to S3
    Upload-ToS3 -BucketArn $BucketArn -FilePath $fileName -AWSRegion $AWSRegion

    # Push the JSON file to GitHub
    $repo = "your-username/your-repo-name"
    $branch = "main"
    $commitMessage = "Add patch state output JSON file"
    Push-ToGitHub -token $token -repo $repo -branch $branch -filePath $fileName -commitMessage $commitMessage
} catch {
    Write-Error "An error occurred during script execution: $_"
    exit 1
}
