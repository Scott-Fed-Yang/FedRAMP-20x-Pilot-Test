#!/bin/bash

# Configuration
SCRIPT_BASENAME=$(basename "$0" .sh)
OUTPUT_DIR="./evidence"
OUTPUT_FILE="${OUTPUT_DIR}/${SCRIPT_BASENAME}.txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "Encryption in-transit Check Results" >> "$OUTPUT_FILE"
echo "Generated at: $(date -u)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "ALB Listener Details: " >> "$OUTPUT_FILE"
echo "[" >> "$OUTPUT_FILE"
first=1

# List ALB listeners
for lb_arn in $(aws elbv2 describe-load-balancers --query 'LoadBalancers[?Type==`application`].LoadBalancerArn' --output text); do
  lb_name=$(aws elbv2 describe-load-balancers --load-balancer-arns "$lb_arn" --query 'LoadBalancers[0].LoadBalancerName' --output text)
  listeners=$(aws elbv2 describe-listeners --load-balancer-arn "$lb_arn" --output json)
  echo "$listeners" | jq --arg name "$lb_name" -c '.Listeners[] | {
    LoadBalancerName: $name,
    Protocol: .Protocol,
    Port: .Port,
    SslPolicy: (.SslPolicy // "N/A"),
    Certificates: (.Certificates // []) | map(.CertificateArn)
  }' | while read -r line; do
    if [ $first -eq 1 ]; then
      echo "  $line" >> "$OUTPUT_FILE"
      first=0
    else
      echo "  ,$line" >> "$OUTPUT_FILE"
    fi
  done
done

echo "]" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Aurora In-Transit Encryption Check
echo "Aurora In-Transit Encryption Parameter: " >> "$OUTPUT_FILE"
echo "[" >> "$OUTPUT_FILE"
first=1

for cluster_id in $(aws rds describe-db-clusters --query 'DBClusters[*].DBClusterIdentifier' --output text); do
  engine=$(aws rds describe-db-clusters --db-cluster-identifier "$cluster_id" --query 'DBClusters[0].Engine' --output text)
  param_group=$(aws rds describe-db-clusters --db-cluster-identifier "$cluster_id" --query 'DBClusters[0].DBClusterParameterGroup' --output text)

  if [[ "$engine" == *"aurora-mysql"* ]]; then
    keys=(require_secure_transport ssl_cipher)
  elif [[ "$engine" == *"aurora-postgresql"* ]]; then
    keys=(rds.force_ssl ssl_min_protocol_version ssl_ciphers)
  else
    continue
  fi

  param_json=$(aws rds describe-db-cluster-parameters --db-cluster-parameter-group-name "$param_group" --output json)
  param_block="{"
  for key in "${keys[@]}"; do
    val=$(echo "$param_json" | jq -r --arg key "$key" '.Parameters[] | select(.ParameterName==$key) | .ParameterValue' | head -n1)
    param_block+="\"$key\": \"$val\","
  done
  param_block="${param_block%,}}"

  entry="{\"AuroraClusterName\": \"$cluster_id\", \"Engine\": \"$engine\", \"ParameterGroup\": $param_block}"

  if [ $first -eq 1 ]; then
    echo "$entry" >> "$OUTPUT_FILE"
    first=0
  else
    echo ",$entry" >> "$OUTPUT_FILE"
  fi
done

echo "]" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Elasticache Redis In-Transit Encryption Check
echo "Elasticache Redis In-Transit Encryption Parameter: " >> "$OUTPUT_FILE"
echo "[" >> "$OUTPUT_FILE"
first=1

for group_id in $(aws elasticache describe-replication-groups --query 'ReplicationGroups[*].ReplicationGroupId' --output text); do
  info=$(aws elasticache describe-replication-groups --replication-group-id "$group_id" --query 'ReplicationGroups[0]' --output json)
  encryption=$(echo "$info" | jq -r '.TransitEncryptionEnabled')
  mode=$(echo "$info" | jq -r '.TransitEncryptionMode // "unknown"')

  entry=$(cat <<EOF
{
  "RedisCacheName": "$group_id",
  "EncryptionInTransit": $encryption,
  "TransitEncryptionMode": "$mode"
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