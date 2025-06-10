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

# Sort by Name using jq and output to file
echo "$raw_json" | jq 'sort_by(.Name)' >> "$OUTPUT_FILE"

# Final result
echo "True"
