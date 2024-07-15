param (
    [string]$InstanceId = "i-01a7d5d948f6b49c9",
    [string]$BucketArn = "arn:aws:s3:::mybuckettest2188",
    [string]$AWSRegion = "us-east-1"
)

# Function to scan for patches
function Scan-Patches {
    param (
        [string]$InstanceId,
        [string]$AWSRegion
    )
    Write-Output "Scanning patches for instance $InstanceId in region $AWSRegion"

    $scanCommand = "aws ssm send-command --instance-ids $InstanceId --document-name 'AWS-RunPatchBaseline' --parameters 'Operation=Scan' --region $AWSRegion"
    Invoke-Expression $scanCommand
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
    aws s3 cp $FilePath s3://$bucketName/ --region $AWSRegion
}

# Scan for patches
Scan-Patches -InstanceId $InstanceId -AWSRegion $AWSRegion

# Assume the output will be stored in a file named after the instance
$fileName = "${InstanceId}_patch_scan_output.json"

# Simulate saving scan output to a file (for demonstration purposes)
# In reality, you might need to retrieve the actual output from SSM
$jsonOutput = @"
{
    "InstanceId": "$InstanceId",
    "ScanTime": "$(Get-Date)",
    "Patches": []
}
"@
$jsonOutput | Set-Content -Path $fileName

# Upload JSON file to S3
Upload-ToS3 -BucketArn $BucketArn -FilePath $fileName -AWSRegion $AWSRegion

# Define GitHub parameters
$token = $env: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  # Set this as a GitHub Secret in your repository
$repo = "your-username/your-repo-name"
$branch = "main"
$commitMessage = "Add patch scan output JSON file"

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
        "User-Agent" = "PowerShell"
        "Content-Type" = "application/json"
    }

    Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
}

# Push the JSON file to GitHub
Push-ToGitHub -token $token -repo $repo -branch $branch -filePath $fileName -commitMessage $commitMessage
