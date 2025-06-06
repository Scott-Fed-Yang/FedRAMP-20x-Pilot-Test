#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "Listing owned AMIs in current AWS account" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

aws ec2 describe-images --owners self \
  --query 'Images[*].{ImageId:ImageId,Name:Name,CreationDate:CreationDate}' \
  --output json \
  | jq -r 'sort_by(.CreationDate) | reverse | .[] | [.ImageId, .Name, .CreationDate] | @tsv' \
  | column -t >> "$OUTPUT_FILE"

echo "True"