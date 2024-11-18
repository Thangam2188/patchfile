#!/bin/bash

# Define variables
BUCKET_NAME="testpatchscript"
REGION="us-east-1"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
OUTPUT_FILE="/tmp/security_patches.txt"

echo "Starting security patch check script..." | tee -a /tmp/debug.log

# Check for critical and important security patches and save the output
echo "Checking for critical and important security patches..." | tee -a /tmp/debug.log
if command -v yum &> /dev/null; then
    sudo yum updateinfo list security | grep -E 'Critical|Important' > $OUTPUT_FILE
    echo "Patch check completed with yum." | tee -a /tmp/debug.log
elif command -v dnf &> /dev/null; then
    sudo dnf updateinfo list security | grep -E 'Critical|Important' > $OUTPUT_FILE
    echo "Patch check completed with dnf." | tee -a /tmp/debug.log
else
    echo "Neither yum nor dnf are installed. Cannot perform patch check." > $OUTPUT_FILE
    echo "Error: No suitable package manager found." | tee -a /tmp/debug.log
fi

# Display contents of the output file for verification
echo "Contents of $OUTPUT_FILE:" | tee -a /tmp/debug.log
cat $OUTPUT_FILE | tee -a /tmp/debug.log

# Upload the file to S3
echo "Attempting to upload the patch report to S3..." | tee -a /tmp/debug.log
aws s3 cp $OUTPUT_FILE s3://$BUCKET_NAME/$INSTANCE_ID/security_patches.txt --region $REGION | tee -a /tmp/debug.log

# Check if the upload was successful
if [ $? -eq 0 ]; then
    echo "File successfully uploaded to S3." | tee -a /tmp/debug.log
else
    echo "Failed to upload the file to S3." | tee -a /tmp/debug.log
fi
