#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Execute AWS CLI command and save output
aws ec2 describe-instances --filters Name=instance-state-name,Values=running,stopped --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,SecurityGroups:length(SecurityGroups)}' --output table > "$OUTPUT_FILE" 2>&1

# Check if output contains instances
if [ ! -s "$OUTPUT_FILE" ] || grep -q "No instances found" "$OUTPUT_FILE"; then
  echo "True"
  exit 0
fi

# Check if any instance has no Security Groups (SecurityGroups count = 0)
# Extract SecurityGroups column from table output, ignoring header and separator lines
sg_counts=$(awk '/^[|]/ && !/[-+]/ && !/InstanceId/ {print $NF}' "$OUTPUT_FILE" | tr -d '[:space:]')

# If sg_counts is empty, assume no instances (True)
if [ -z "$sg_counts" ]; then
  echo "True"
  exit 0
fi

# Check each SecurityGroups count
all_have_sg=true
while IFS= read -r sg_count; do
  if [ "$sg_count" = "0" ]; then
    all_have_sg=false
    break
  fi
done <<< "$sg_counts"

# Return result
if [ "$all_have_sg" = "true" ]; then
  echo "True"
else
  echo "False"
fi
exit 0
