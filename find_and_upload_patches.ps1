param (
    [string]$InstanceId = "i-01a7d5d948f6b49c9",
    [string]$BucketArn = "arn:aws:s3:::mybuckettest2188",
    [string]$AWSRegion = "us-east-1"
)

# Function to scan for critical and important patches
function Scan-Patches {
    param (
        [string]$InstanceId,
        [string]$AWSRegion
    )
    Write-Output "Scanning for critical and important security patches on instance $InstanceId in region $AWSRegion"

    $scanCommand = "aws ssm send-command --instance-ids $InstanceId --document-name 'AWS-RunPatchBaseline' --parameters '{`"Operation`":[`"Scan`"],`"SeverityLevels`":[`"Critical`",`"Important`"]}' --region $AWSRegion"
    try {
        $result = Invoke-Expression $scanCommand
        return $result
    } catch {
        Write-Error "Failed to send SSM command: $_"
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
        Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
    } catch {
        Write-Error "Failed to push to GitHub: $_"
        exit 1
    }
}

# Main script execution
try {
    # Scan for patches
    $scanResult = Scan-Patches -InstanceId $InstanceId -AWSRegion $AWSRegion

    # Assume the output will be stored in a file named after the instance
    $fileName = "${InstanceId}_patch_scan_output.json"

    # Simulate saving scan output to a file (for demonstration purposes)
    # In reality, you might need to retrieve the actual output from SSM
    $jsonOutput = @"
{
    "InstanceId": "$InstanceId",
    "ScanTime": "$(Get-Date)",
    "Patches": [
        {
            "Title": "Example Patch 1",
            "Severity": "Critical"
        },
        {
            "Title": "Example Patch 2",
            "Severity": "Important"
        }
    ]
}
"@
    $jsonOutput | Set-Content -Path $fileName

    # Upload JSON file to S3
    Upload-ToS3 -BucketArn $BucketArn -FilePath $fileName -AWSRegion $AWSRegion

    # Push the JSON file to GitHub
    $token = $env:GITHUB_TOKEN  # Ensure this is set as a GitHub Secret in your repository
    if (-not $token) {
        Write-Error "GitHub token not set. Please set the GITHUB_TOKEN environment variable."
        exit 1
    }
    $repo = "your-username/your-repo-name"
    $branch = "main"
    $commitMessage = "Add patch scan output JSON file"
    Push-ToGitHub -token $token -repo $repo -branch $branch -filePath $fileName -commitMessage $commitMessage
} catch {
    Write-Error "An error occurred during script execution: $_"
    exit 1
}
