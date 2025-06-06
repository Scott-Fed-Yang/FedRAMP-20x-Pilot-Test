#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"
TEMP_FILE="./evidence/KSI-RPL-3-tmp-$$.txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Initialize output file
> "$OUTPUT_FILE"

# Flag to track if all commands succeed
all_success=true

# Section 1: System Backup stored in the Backup Site (US-West-2)
echo "System Backup stored in the Backup Site (US-West-2, RTO is 8 hours)" >> "$OUTPUT_FILE"
echo "-------------------------------------------------" >> "$OUTPUT_FILE"
aws ec2 describe-images --query 'reverse(sort_by(Images[].{ImageName:Name, CreationDate:CreationDate}, &CreationDate))[0:4].[ImageName, CreationDate]' --filters 'Name=is-public,Values=false' --region 'us-west-2' --output table > "$TEMP_FILE" 2>&1
if [ $? -eq 0 ] && [ -s "$TEMP_FILE" ] && ! grep -q "Error" "$TEMP_FILE"; then
  cat "$TEMP_FILE" >> "$OUTPUT_FILE"
else
  echo "Error: Failed to retrieve EC2 AMI backups" >> "$OUTPUT_FILE"
  all_success=false
fi
echo "" >> "$OUTPUT_FILE"

# Section 2: Data Backup stored in the Backup Site (US-West-2)
echo "Data Backup stored in the Backup Site (US-West-2, RPO is 24 hours)" >> "$OUTPUT_FILE"
echo "-----------------------------------------------" >> "$OUTPUT_FILE"
aws rds describe-db-cluster-snapshots --snapshot-type 'manual' --query 'reverse(sort_by(DBClusterSnapshots[].{DBIdentifier:DBClusterIdentifier, DBSnapshotIdentifier:DBClusterSnapshotIdentifier, SnapshotCreateTime:SnapshotCreateTime}, &SnapshotCreateTime))[0:4].[DBIdentifier, DBSnapshotIdentifier]' --region 'us-west-2' --output table > "$TEMP_FILE" 2>&1
if [ $? -eq 0 ] && [ -s "$TEMP_FILE" ] && ! grep -q "Error" "$TEMP_FILE"; then
  cat "$TEMP_FILE" >> "$OUTPUT_FILE"
else
  echo "Error: Failed to retrieve RDS manual snapshots" >> "$OUTPUT_FILE"
  all_success=false
fi
echo "" >> "$OUTPUT_FILE"

# Clean up temporary file
rm -f "$TEMP_FILE"

# Return result
if [ "$all_success" = "true" ]; then
  echo "True"
else
  echo "False"
fi
exit 0
