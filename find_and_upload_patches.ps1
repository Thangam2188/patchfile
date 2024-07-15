param (
    [string]$InstanceId = "i-01a7d5d948f6b49c9",
    [string]$BucketArn = "arn:aws:s3:::mybuckettest2188",
    [string]$AWSRegion = "us-east-1",
    [string]$GitHubToken = "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",
    [string]$repo = "your-username/your-repo-name",
    [string]$branch = "main"
)

# Function to get patch information for the instance
function Get-PatchInfo {
    param (
        [string]$InstanceId,
        [string]$AWSRegion
    )
    Write-Output "Retrieving patch information for critical and important security patches on instance $InstanceId in region $AWSRegion"

    $patchInfoCommand = "aws ssm describe-instance-patches --instance-id $InstanceId --filters Key=Classification,Values=Security Key=Severity,Values=Critical,Important --region $AWSRegion"
    try {
        $result = Invoke-Expression $patchInfoCommand
        $patchInfo = ($result | ConvertFrom-Json).Patches
        return $patchInfo
    } catch {
        Write-Error "Failed to retrieve patch information: $_"
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
        [string]$GitHubToken,
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
        Authorization = "Bearer $GitHubToken"
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
    # Retrieve patch information
    $patchInfo = Get-PatchInfo -InstanceId $InstanceId -AWSRegion $AWSRegion

    # Save the output to a file
    $fileName = "${InstanceId}_patch_info_output.json"
    $patchInfo | ConvertTo-Json -Compress | Set-Content -Path $fileName

    # Upload JSON file to S3
    Upload-ToS3 -BucketArn $BucketArn -FilePath $fileName -AWSRegion $AWSRegion

    # Push the JSON file to GitHub
    $commitMessage = "Add patch info output JSON file"
    Push-ToGitHub -GitHubToken $GitHubToken -repo $repo -branch $branch -filePath $fileName -commitMessage $commitMessage
} catch {
    Write-Error "An error occurred during script execution: $_"
    exit 1
}
