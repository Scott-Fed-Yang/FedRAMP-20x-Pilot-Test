#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/KSI-CNA-4.txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Execute AWS CLI command and save output
aws ec2 describe-instances --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,VpcId:VpcId}' --output table > "$OUTPUT_FILE" 2>&1

# Check if output contains instances
if [ ! -s "$OUTPUT_FILE" ] || grep -q "No instances found" "$OUTPUT_FILE"; then
  echo "True"
  exit 0
fi

# Check if any instance lacks VpcId
# Extract VpcId column from table output, ignoring header and separator lines
vpc_ids=$(awk '/^[|]/ && !/[-+]/ && !/InstanceId/ {print $NF}' "$OUTPUT_FILE" | tr -d '[:space:]')

# If vpc_ids is empty, assume no instances (True)
if [ -z "$vpc_ids" ]; then
  echo "True"
  exit 0
fi

# Check each VpcId
all_have_vpcid=true
while IFS= read -r vpc_id; do
  if [ -z "$vpc_id" ]; then
    all_have_vpcid=false
    break
  fi
done <<< "$vpc_ids"

# Return result
if [ "$all_have_vpcid" = "true" ]; then
  echo "True"
else
  echo "False"
fi
exit 0
