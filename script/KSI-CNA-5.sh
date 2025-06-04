#!/bin/bash

# Configuration
URL="https://app.vyond-fedramp.com"
OUTPUT_FILE="./evidence/KSI-CNA-5.txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Execute curl command and save output
curl -I "$URL" > "$OUTPUT_FILE" 2>&1

# Check for CloudFront headers (case-insensitive)
if grep -i -E 'X-Cache:.*cloudfront|Via:.*cloudfront|X-Amz-Cf-Id:' "$OUTPUT_FILE" >/dev/null; then
  echo "True"
else
  echo "False"
fi
exit 0
