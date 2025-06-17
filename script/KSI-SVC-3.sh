#!/bin/bash

# Configuration
SCRIPT_BASENAME=$(basename "$0" .sh)
OUTPUT_DIR="./evidence"
OUTPUT_FILE="${OUTPUT_DIR}/${SCRIPT_BASENAME}.txt"
ALL_ENCRYPTED=1  # Track if all encryption checks are true (1=true, 0=false)

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "Encryption at-rest Check Results" > "$OUTPUT_FILE"
echo "Generated at: $(date -u)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

#no fips endpoint for s3api
AWS_USE_FIPS_ENDPOINT=false

# ---------------------------
# S3 Encryption At-Rest
# ---------------------------
echo "S3 Encryption At-Rest Check" >> "$OUTPUT_FILE"
echo "[" >> "$OUTPUT_FILE"
first=1
for bucket in $(aws s3api list-buckets --query 'Buckets[*].Name' --output text); do
  encryption=$(aws s3api get-bucket-encryption --bucket "$bucket" 2>/dev/null || echo "")
  if [ -n "$encryption" ]; then
    type=$(echo "$encryption" | jq -r '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm')
    arn=$(echo "$encryption" | jq -r '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.KMSMasterKeyID // "N/A"')
  else
    type="None"
    arn="N/A"
    ALL_ENCRYPTED=0  # Mark as false if any bucket is unencrypted
  fi

  entry=$(cat <<EOF
{
  "BucketName": "$bucket",
  "EncryptionType": "$type",
  "EncryptionKey": "$arn"
}
EOF
)
  if [ $first -eq 1 ]; then
    echo "$entry" >> "$OUTPUT_FILE"
    first=0
  else
    echo ",$entry" >> "$OUTPUT_FILE"
  fi
done
echo "]" >> "$OUTPUT_FILE"

AWS_USE_FIPS_ENDPOINT=true

# ---------------------------
# Aurora Encryption At-Rest
# ---------------------------
echo "" >> "$OUTPUT_FILE"
echo "Aurora Encryption At-Rest Check" >> "$OUTPUT_FILE"
echo "[" >> "$OUTPUT_FILE"
first=1
for cluster_id in $(aws rds describe-db-clusters --query 'DBClusters[*].DBClusterIdentifier' --output text); do
  info=$(aws rds describe-db-clusters --db-cluster-identifier "$cluster_id" --query 'DBClusters[0]' --output json)
  encrypted=$(echo "$info" | jq -r '.StorageEncrypted')
  kmskey=$(echo "$info" | jq -r '.KmsKeyId // "N/A"')

  if [ "$encrypted" != "true" ]; then
    ALL_ENCRYPTED=0  # Mark as false if any cluster is unencrypted
  fi

  entry=$(cat <<EOF
{
  "AuroraClusterName": "$cluster_id",
  "StorageEncryption": $encrypted,
  "EncryptionKey": "$kmskey"
}
EOF
)
  if [ $first -eq 1 ]; then
    echo "$entry" >> "$OUTPUT_FILE"
    first=0
  else
    echo ",$entry" >> "$OUTPUT_FILE"
  fi
done
echo "]" >> "$OUTPUT_FILE"

# ---------------------------
# Redis Encryption At-Rest
# ---------------------------
echo "" >> "$OUTPUT_FILE"
echo "Elasticache Redis Encryption At-Rest Check" >> "$OUTPUT_FILE"
echo "[" >> "$OUTPUT_FILE"
first=1
for group_id in $(aws elasticache describe-replication-groups --query 'ReplicationGroups[*].ReplicationGroupId' --output text); do
  info=$(aws elasticache describe-replication-groups --replication-group-id "$group_id" --query 'ReplicationGroups[0]' --output json)
  encrypted=$(echo "$info" | jq -r '.AtRestEncryptionEnabled')
  keyid=$(echo "$info" | jq -r '.KmsKeyId // "N/A"')

  if [ "$encrypted" != "true" ]; then
    ALL_ENCRYPTED=0  # Mark as false if any Redis cache is unencrypted
  fi

  entry=$(cat <<EOF
{
  "RedisCacheName": "$group_id",
  "EncryptionAtRest": $encrypted,
  "EncryptionKey": "$keyid"
}
EOF
)
  if [ $first -eq 1 ]; then
    echo "$entry" >> "$OUTPUT_FILE"
    first=0
  else
    echo ",$entry" >> "$OUTPUT_FILE"
  fi
done
echo "]" >> "$OUTPUT_FILE"

# ---------------------------
# EC2 AMI Encryption Check
# ---------------------------
echo "" >> "$OUTPUT_FILE"
echo "EC2 AMI Encryption Check" >> "$OUTPUT_FILE"
ami_output=$(aws ec2 describe-images --query 'Images[*].{ImageId:ImageId, DeviceName:BlockDeviceMappings[*].{DeviceName:DeviceName, Encrypted:Ebs.Encrypted}}' --filters 'Name=is-public,Values=false' --output json)
echo "$ami_output" >> "$OUTPUT_FILE"

# Check if all EBS volumes in AMIs are encrypted
ami_encrypted=$(echo "$ami_output" | jq -r '.[] | .DeviceName[] | .Encrypted' | grep -v "true")
if [ -n "$ami_encrypted" ]; then
  ALL_ENCRYPTED=0  # Mark as false if any EBS volume is unencrypted
fi

# ---------------------------
# RDS DB Cluster Snapshot Encryption Check
# ---------------------------
echo "" >> "$OUTPUT_FILE"
echo "RDS DB Cluster Snapshot Encryption Check" >> "$OUTPUT_FILE"
snapshot_output=$(aws rds describe-db-cluster-snapshots --query 'DBClusterSnapshots[*].{DBClusterSnapshotIdentifier:DBClusterSnapshotIdentifier, StorageEncrypted:StorageEncrypted}' --output json)
echo "$snapshot_output" >> "$OUTPUT_FILE"

# Check if all snapshots are encrypted
snapshot_encrypted=$(echo "$snapshot_output" | jq -r '.[] | .StorageEncrypted' | grep -v "true")
if [ -n "$snapshot_encrypted" ]; then
  ALL_ENCRYPTED=0  # Mark as false if any snapshot is unencrypted
fi

# ---------------------------
# Final Encryption Status
# ---------------------------
if [ $ALL_ENCRYPTED -eq 1 ]; then
  echo "True"
else
  echo "False"
fi