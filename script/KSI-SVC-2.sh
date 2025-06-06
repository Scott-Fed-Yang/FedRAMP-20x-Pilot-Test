#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Initialize JSON output
echo '{"EncryptionStatus": {' > "$OUTPUT_FILE"

# Check ELB listeners for HTTPS/TLS
echo -n '"ELBListeners": ' >> "$OUTPUT_FILE"
elb_output=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' --output text --region "$REGION" 2>/dev/null)
if [ -n "$elb_output" ]; then
  echo "$elb_output" | while read -r lb_arn; do
    aws elbv2 describe-listeners --load-balancer-arn "$lb_arn" --query 'Listeners[*].{Protocol:Protocol,Port:Port,SslPolicy:SslPolicy,Encrypted:Protocol==\"HTTPS\" or Protocol==\"TLS\"}' --output json --region "$REGION"
  done | jq -s '{Encrypted: length == 0 or all(.[]; .Encrypted), Details: .}'
else
  echo '{"Encrypted": true, "Details": []}'
fi >> "$OUTPUT_FILE"
echo ',' >> "$OUTPUT_FILE"

# Check S3 bucket policies for SecureTransport
echo -n '"S3Buckets": ' >> "$OUTPUT_FILE"
buckets=$(aws s3api list-buckets --query 'Buckets[*].Name' --output text --region "$REGION" 2>/dev/null)
if [ -n "$buckets" ]; then
  echo "$buckets" | while read -r bucket; do
    policy=$(aws s3api get-bucket-policy --bucket "$bucket" --query 'Policy' --output text --region "$REGION" 2>/dev/null)
    if [ -n "$policy" ]; then
      echo "$policy" | jq -r '{Bucket: "'"$bucket"'", Encrypted: (.Statement // [] | any(.Effect == "Deny" and .Condition.Bool."aws:SecureTransport" == "false"))}'
    else
      echo '{"Bucket": "'"$bucket"'", "Encrypted": true}'
    fi
  done | jq -s '{Encrypted: length == 0 or all(.[]; .Encrypted), Details: .}'
else
  echo '{"Encrypted": true, "Details": []}'
fi >> "$OUTPUT_FILE"

# Close JSON
echo '}}' >> "$OUTPUT_FILE"

# Check if all services are encrypted
all_encrypted=$(cat "$OUTPUT_FILE" | jq '.EncryptionStatus | all(.[]; .Encrypted)')
if [ "$all_encrypted" = "true" ]; then
  echo "True"
else
  cat "$OUTPUT_FILE" | jq . || echo "Error: Failed to parse JSON output. Check $OUTPUT_FILE for details."
fi

# Display result
# cat "$OUTPUT_FILE" | jq . || echo "Error: Failed to parse JSON output. Check $OUTPUT_FILE for details."
