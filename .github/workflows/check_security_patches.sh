#!/bin/bash

# Generate the MFA code using oathtool
MFA_CODE=$(oathtool --base32 --totp "$MFA_SECRET")
echo "Generated MFA Code: $MFA_CODE"

# Print environment variables for debugging
echo "MFA_SERIAL_ARN: $MFA_SERIAL_ARN"
echo "AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID"
echo "AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY"

# Attempt to get temporary credentials with debug information using sudo
TEMP_CREDS=$(sudo aws sts get-session-token --serial-number $MFA_SERIAL_ARN --token-code $MFA_CODE --duration-seconds 3600 --output json --debug 2>&1)
STATUS=$?

# Check if the command was successful
if [ $STATUS -ne 0 ]; then
  echo "Error obtaining temporary credentials: $TEMP_CREDS"
  exit $STATUS
fi

# Parse and set temporary credentials
echo "::set-output name=aws_access_key_id::$(echo $TEMP_CREDS | jq -r '.Credentials.AccessKeyId')"
echo "::set-output name=aws_secret_access_key::$(echo $TEMP_CREDS | jq -r '.Credentials.SecretAccessKey')"
echo "::set-output name=aws_session_token::$(echo $TEMP_CREDS | jq -r '.Credentials.SessionToken')"

# Define variables
BUCKET_NAME="testpatchscript"
REGION="us-east-1"  # Adjust if needed
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
OUTPUT_FILE="/tmp/security_patches.txt"

# Check for critical and important security patches and save the output
if command -v yum &> /dev/null; then
    sudo yum updateinfo list security | grep -E 'Critical|Important' > $OUTPUT_FILE
elif command -v dnf &> /dev/null; then
    sudo dnf updateinfo list security | grep -E 'Critical|Important' > $OUTPUT_FILE
else
    echo "Neither yum nor dnf are installed." > $OUTPUT_FILE
fi

# Upload the file to S3
aws s3 cp $OUTPUT_FILE s3://$BUCKET_NAME/$INSTANCE_ID/security_patches.txt --region $REGION
