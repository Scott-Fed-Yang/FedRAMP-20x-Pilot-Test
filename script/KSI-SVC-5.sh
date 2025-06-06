#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"
SCRIPT_BASENAME=$(basename "$0" .sh)
TEMP_FILE="./evidence/${SCRIPT_BASENAME}-tmp-$$.txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Initialize output file
echo "EBS Encryption Check Results" > "$OUTPUT_FILE"
echo "---------------------------" >> "$OUTPUT_FILE"

# Flag to track encryption status
all_encrypted=true

# List all private AMI image IDs
echo "Checking Private AMIs" >> "$OUTPUT_FILE"
aws ec2 describe-images --query 'Images[*].ImageId' --filters 'Name=is-public,Values=false' --output json > "$TEMP_FILE" 2>&1
cat "$TEMP_FILE" >> "$OUTPUT_FILE"
if [ $? -ne 0 ]; then
  echo "Error: Failed to list private AMIs" >> "$OUTPUT_FILE"
  all_encrypted=false
fi

# Extract image IDs from JSON output
image_ids=$(jq -r '.[]' "$TEMP_FILE" 2>/dev/null)

# Check EBS encryption for each AMI
if [ -n "$image_ids" ]; then
  while IFS= read -r image_id; do
    echo "Checking AMI: $image_id" >> "$OUTPUT_FILE"
    # Get EBS encryption status
    aws ec2 describe-images --image-ids "$image_id" --query 'Images[*].BlockDeviceMappings[*].{DeviceName:DeviceName, Encrypted:Ebs.Encrypted}' --output json > "$TEMP_FILE" 2>&1
    cat "$TEMP_FILE" >> "$OUTPUT_FILE"
    if [ $? -eq 0 ]; then
      # Check if all EBS volumes are encrypted
      unencrypted=$(jq -r '.[][] | select(.Encrypted == false) | .DeviceName' "$TEMP_FILE" 2>/dev/null)
      if [ -z "$unencrypted" ]; then
        echo "All EBS volumes encrypted for $image_id" >> "$OUTPUT_FILE"
      else
        echo "Unencrypted EBS volume(s) found for $image_id on device(s): $unencrypted" >> "$OUTPUT_FILE"
        all_encrypted=false
      fi
    else
      echo "Failed to retrieve EBS encryption status for $image_id" >> "$OUTPUT_FILE"
      all_encrypted=false
    fi
    echo "---------------------------" >> "$OUTPUT_FILE"
  done <<< "$image_ids"
else
  echo "No private AMIs found." >> "$OUTPUT_FILE"
fi

# Clean up temporary file
rm -f "$TEMP_FILE"

# Return result
if [ "$all_encrypted" = "true" ]; then
  echo "True"
else
  echo "False"
fi
exit 0
