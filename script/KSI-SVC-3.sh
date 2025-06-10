#!/bin/bash

# Configuration
SCRIPT_BASENAME=$(basename "$0" .sh)
OUTPUT_DIR="./evidence"
OUTPUT_FILE="${OUTPUT_DIR}/${SCRIPT_BASENAME}.txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "Encryption at-rest Check Results" >> "$OUTPUT_FILE"
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

  entry=$(cat <<EOF
{
  "RedisCacheName": "$group_id",
  "EncryptionAtRest": $encrypted,
  "EncryptionKey": "$keyid",
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

echo "True"