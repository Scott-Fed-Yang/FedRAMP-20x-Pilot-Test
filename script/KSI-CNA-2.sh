#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "V4G has logically segmented subnets to isolate public-facing, management, and operational components in accordance with SC-7(b) and SC-7(13) controls" > "$OUTPUT_FILE"
echo "Date: $(date -u)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Fetch subnet data from AWS
raw_json=$(aws ec2 describe-subnets \
  --query 'Subnets[*].{
    SubnetId: SubnetId,
    VpcId: VpcId,
    Name: (Tags[?Key==`Name`]|[0].Value),
    AvailabilityZone: AvailabilityZone,
    State: State
  }' \
  --output json)

# 1. Sort by Name using jq and output the raw data to the file
echo "$raw_json" | jq 'sort_by(.Name)' >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 2. Count the total number of Subnet IDs (which represents the total quantity of subnets)
#    - Use jq to extract all SubnetId values
#    - Use wc -l to count the number of lines (total subnets found)
SUBNET_QUANTITY=$(echo "$raw_json" | jq -r '.[].SubnetId' | wc -l)

# Log the subnet quantity to the output file for evidence
echo "--- Subnet Quantity Analysis ---" >> "$OUTPUT_FILE"
echo "Total Subnets Found: $SUBNET_QUANTITY" >> "$OUTPUT_FILE"

# 3. Check the condition (if quantity >= 2, return "True", otherwise return "False")
if [ "$SUBNET_QUANTITY" -ge 2 ]; then
    RESULT="True"
else
    RESULT="False"
fi

# Final result output
echo "$RESULT"

# Log the final result to the output file
echo "Final Result (Quantity of Subnets >= 2): $RESULT" >> "$OUTPUT_FILE"
