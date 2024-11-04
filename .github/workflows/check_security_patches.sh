#!/bin/bash

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
