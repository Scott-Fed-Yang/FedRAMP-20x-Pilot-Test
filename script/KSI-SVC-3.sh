#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/KSI-SVC-3.txt"
TEMP_FILE="./evidence/KSI-SVC-3-tmp-$$.txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Initialize output file
echo "S3 and RDS Encryption Check Results" > "$OUTPUT_FILE"
echo "-----------------------------------" >> "$OUTPUT_FILE"

# Flag to track encryption status
all_encrypted=true

# --- S3 Buckets ---
echo "Checking S3 Buckets" >> "$OUTPUT_FILE"
# List all S3 buckets
aws s3api list-buckets --query 'Buckets[*].Name' --output json > "$TEMP_FILE" 2>&1
cat "$TEMP_FILE" >> "$OUTPUT_FILE"
if [ $? -ne 0 ]; then
  echo "Error: Failed to list S3 buckets" >> "$OUTPUT_FILE"
  all_encrypted=false
fi

# Extract bucket names from JSON output
buckets=$(jq -r '.[]' "$TEMP_FILE" 2>/dev/null)

# Check encryption for each bucket
if [ -n "$buckets" ]; then
  while IFS= read -r bucket; do
    echo "Checking bucket: $bucket" >> "$OUTPUT_FILE"
    # Get bucket encryption
    aws s3api get-bucket-encryption --bucket "$bucket" --output json > "$TEMP_FILE" 2>&1
    cat "$TEMP_FILE" >> "$OUTPUT_FILE"
    if [ $? -eq 0 ]; then
      encryption=$(jq -r '.ServerSideEncryptionConfiguration.Rules[].ApplyServerSideEncryptionByDefault.SSEAlgorithm' "$TEMP_FILE" 2>/dev/null)
      if [ -n "$encryption" ] && [ "$encryption" = "AES256" ] || [ "$encryption" = "aws:kms" ]; then
        echo "Encryption: $encryption" >> "$OUTPUT_FILE"
      else
        echo "No valid encryption configured for $bucket" >> "$OUTPUT_FILE"
        all_encrypted=false
      fi
    else
      echo "No encryption configured for $bucket" >> "$OUTPUT_FILE"
      all_encrypted=false
    fi
    echo "-----------------------------------" >> "$OUTPUT_FILE"
  done <<< "$buckets"
else
  echo "No S3 buckets found." >> "$OUTPUT_FILE"
fi

# --- RDS Instances ---
echo "Checking RDS Instances" >> "$OUTPUT_FILE"
# List all RDS instances
aws rds describe-db-instances --query 'DBInstances[*].DBInstanceIdentifier' --output json > "$TEMP_FILE" 2>&1
cat "$TEMP_FILE" >> "$OUTPUT_FILE"
if [ $? -ne 0 ]; then
  echo "Error: Failed to list RDS instances" >> "$OUTPUT_FILE"
  all_encrypted=false
fi

# Extract RDS instance identifiers from JSON output
rds_instances=$(jq -r '.[]' "$TEMP_FILE" 2>/dev/null)

# Check encryption for each RDS instance
if [ -n "$rds_instances" ]; then
  while IFS= read -r db_instance; do
    echo "Checking RDS instance: $db_instance" >> "$OUTPUT_FILE"
    # Get encryption status
    aws rds describe-db-instances --db-instance-identifier "$db_instance" --query 'DBInstances[*].StorageEncrypted' --output json > "$TEMP_FILE" 2>&1
    cat "$TEMP_FILE" >> "$OUTPUT_FILE"
    if [ $? -eq 0 ]; then
      encrypted=$(jq -r '.[0]' "$TEMP_FILE" 2>/dev/null)
      if [ "$encrypted" = "true" ]; then
        echo "Storage Encrypted: True" >> "$OUTPUT_FILE"
      else
        echo "Storage Encrypted: False for $db_instance" >> "$OUTPUT_FILE"
        all_encrypted=false
      fi
    else
      echo "Storage Encrypted: False or not configured for $db_instance" >> "$OUTPUT_FILE"
      all_encrypted=false
    fi
    echo "-----------------------------------" >> "$OUTPUT_FILE"
  done <<< "$rds_instances"
else
  echo "No RDS instances found." >> "$OUTPUT_FILE"
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
