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

    $parameters = @{
        Operation = @("Scan")
        SeverityLevels = @("Critical", "Important")
    }
    $parametersJson = $parameters | ConvertTo-Json -Compress

    $scanCommand = "aws ssm send-command --instance-ids $InstanceId --document-name 'AWS-RunPatchBaseline' --parameters '$parametersJson' --region $AWSRegion"
    try {
        $result = Invoke-Expression $scanCommand
        $commandId = ($result | ConvertFrom-Json).Command.CommandId
        Write-Output "Command ID: $commandId"
        return $commandId
    } catch {
        Write-Error "Failed to send SSM command: $_"
        exit 1
    }
}

# Function to retrieve SSM command output
function Get-SSMCommandOutput {
    param (
        [string]$CommandId,
        [string]$InstanceId,
        [string]$AWSRegion
    )
    Write-Output "Retrieving output for SSM command ID $CommandId on instance $InstanceId"

    try {
        while ($true) {
            $statusCommand = "aws ssm list-command-invocations --command-id $CommandId --details --region $AWSRegion"
            $statusResult = Invoke-Expression $statusCommand
            $invocations = ($statusResult | ConvertFrom-Json).CommandInvocations

            if ($null -eq $invocations -or $invocations.Count -eq 0) {
                Write-Error "No command invocations found for command ID $CommandId"
                exit 1
            }

            $invocation = $invocations[0]

            if ($invocation.Status -eq "InProgress" -or $invocation.Status -eq "Pending") {
                Start-Sleep -Seconds 10
            } elseif ($invocation.Status -eq "Success") {
                $output = $invocation.CommandPlugins[0].Output
                return $output
            } else {
                Write-Error "SSM command failed with status $($invocation.Status)"
                exit 1
            }
        }
    } catch {
        Write-Error "Failed to retrieve SSM command output: $_"
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
    # Scan for patches
    $commandId = Scan-Patches -InstanceId $InstanceId -AWSRegion $AWSRegion

    # Retrieve SSM command output
    $ssmOutput = Get-SSMCommandOutput -CommandId $commandId -InstanceId $InstanceId -AWSRegion $AWSRegion

    # Save the output to a file
    $fileName = "${InstanceId}_patch_scan_output.json"
    $ssmOutput | Set-Content -Path $fileName

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
