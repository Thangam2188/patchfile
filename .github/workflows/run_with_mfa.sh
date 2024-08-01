#!/bin/bash

# Define variables
MFA_ARN="arn:aws:iam::472598590798:mfa/dev_mfa"
DURATION=3600
PROFILE="sycdevlongterm"
POWER_SHELL_SCRIPT="C:\\path\\to\\your\\script\\find_and_upload_patches.ps1"

# Prompt for MFA code
read -p "Enter MFA code: " MFA_CODE

# Obtain temporary credentials
CREDS=$(aws sts get-session-token --profile $PROFILE --serial-number $MFA_ARN --token-code $MFA_CODE --duration-seconds $DURATION --output json)

# Extract temporary credentials
AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r '.Credentials.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r '.Credentials.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo $CREDS | jq -r '.Credentials.SessionToken')

# Run the PowerShell script with temporary credentials
pwsh -File $POWER_SHELL_SCRIPT -BucketArn "arn:aws:s3:::sycdel-test2" -AWSRegion "us-east-1" -AWSAccessKeyId $AWS_ACCESS_KEY_ID -AWSSecretAccessKey $AWS_SECRET_ACCESS_KEY -AWSSessionToken $AWS_SESSION_TOKEN
