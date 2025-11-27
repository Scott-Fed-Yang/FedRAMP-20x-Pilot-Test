#!/bin/bash

# Configuration
SCRIPT_BASENAME=$(basename "$0" .sh)
OUTPUT_DIR="./evidence"
OUTPUT_FILE="${OUTPUT_DIR}/${SCRIPT_BASENAME}.txt"
RESULT="True" # Tentative result, fails if any check fails
AUDIT_LOG="" # Variable to capture all raw data and check details

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Function: Capture and append to AUDIT_LOG
log_audit() {
  AUDIT_LOG+="$1"$'\n'
}

log_audit "Encryption in-transit Check Results"
log_audit "Generated at: $(date -u)"
log_audit ""
log_audit "=================================================="

# --- 1. ALB Listener In-Transit Encryption Check ---
log_audit "--- 1. ALB Listener Check (HTTPS & Certificate) ---"
ALB_PASS=true
ALB_LISTENERS_JSON="[]" # Stores the JSON data of all listeners

# Iterate through all Application Load Balancers
for lb_arn in $(aws elbv2 describe-load-balancers --query 'LoadBalancers[?Type==`application`].LoadBalancerArn' --output text); do
  lb_name=$(aws elbv2 describe-load-balancers --load-balancer-arns "$lb_arn" --query 'LoadBalancers[0].LoadBalancerName' --output text)
  listeners=$(aws elbv2 describe-listeners --load-balancer-arn "$lb_arn" --output json)
  
  # Iterate and check each Listener
  CHECKED_LISTENERS=$(echo "$listeners" | jq --arg name "$lb_name" -c '.Listeners[] | {
    LoadBalancerName: $name,
    Protocol: .Protocol,
    Port: .Port,
    SslPolicy: (.SslPolicy // "N/A"),
    Certificates: (.Certificates // []) | map(.CertificateArn)
  }')

  while IFS= read -r line; do
    ALB_LISTENERS_JSON=$(echo "$ALB_LISTENERS_JSON" | jq ". + [ $line ]")
    
    protocol=$(echo "$line" | jq -r '.Protocol')
    certificates_count=$(echo "$line" | jq '.Certificates | length')
    port=$(echo "$line" | jq -r '.Port')

    # Perform validation
    if [ "$protocol" == "HTTPS" ] && [ "$certificates_count" -ge 1 ]; then
      log_audit "  [PASS] ALB Listener $lb_name:$port is HTTPS and has $certificates_count certificates."
    elif [ "$protocol" == "HTTP" ]; then
      log_audit "  [INFO] ALB Listener $lb_name:$port is HTTP (Ignored for this check)."
    else
      # Any non-HTTPS listener without a certificate results in a failure
      if [ "$protocol" != "HTTP" ]; then
        ALB_PASS=false
        log_audit "  [FAIL] ALB Listener $lb_name:$port FAILED: Protocol is $protocol, Certificates count: $certificates_count."
      fi
    fi
  done <<< "$CHECKED_LISTENERS"
done

log_audit "ALB Listeners RAW JSON Data:"
log_audit "$ALB_LISTENERS_JSON"
log_audit ""

# Checkpoint 1 result determination
if ! $ALB_PASS; then
    RESULT="False"
fi


# --- 2. Aurora In-Transit Encryption Check ---
log_audit "--- 2. Aurora require_secure_transport Check ---"
AURORA_PASS=true
AURORA_DATA="[]"

for cluster_id in $(aws rds describe-db-clusters --query 'DBClusters[*].DBClusterIdentifier' --output text); do
  engine=$(aws rds describe-db-clusters --db-cluster-identifier "$cluster_id" --query 'DBClusters[0].Engine' --output text)
  param_group=$(aws rds describe-db-clusters --db-cluster-identifier "$cluster_id" --query 'DBClusters[0].DBClusterParameterGroup' --output text)

  # Determine engine type and target parameter
  TARGET_KEY=""
  REQUIRED_VALUES=""

  if [[ "$engine" == *"aurora-mysql"* ]]; then
    TARGET_KEY="require_secure_transport"
    REQUIRED_VALUES="ON"
  elif [[ "$engine" == *"aurora-postgresql"* ]]; then
    TARGET_KEY="rds.force_ssl"
    REQUIRED_VALUES=("1" "true")
  else
    continue
  fi

  param_json=$(aws rds describe-db-cluster-parameters --db-cluster-parameter-group-name "$param_group" --output json)
  
  # Extract parameter value
  val=$(echo "$param_json" | jq -r --arg key "$TARGET_KEY" '.Parameters[] | select(.ParameterName==$key) | .ParameterValue' | head -n1)
  
  # Format the output data
  entry=$(jq -n --arg cluster "$cluster_id" --arg engine "$engine" --arg group "$param_group" --arg key "$TARGET
