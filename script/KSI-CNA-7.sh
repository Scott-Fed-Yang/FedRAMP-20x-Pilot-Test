#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

#no fips endpoint
AWS_USE_FIPS_ENDPOINT=false

CHECK_NAME="AWS Well-Architected high risk issues for reliability"
CHECK_ID=$(aws support describe-trusted-advisor-checks --language en \
  | jq -r --arg name "$CHECK_NAME" '.checks[] | select(.name == $name) | .id')

if [ -z "$CHECK_ID" ]; then
  echo "Unable to find Trusted Advisor check ID for: $CHECK_NAME" >> "$OUTPUT_FILE"
  echo "False"
  exit 1
fi

RESULT=$(aws support describe-trusted-advisor-check-result --check-id "$CHECK_ID" --language en)
STATUS=$(echo "$RESULT" | jq -r '.result.status')

echo "Trusted Advisor Check: AWS Well-Architected high risk issues for reliability" > "$OUTPUT_FILE"
echo "ID: $CHECK_ID" >> "$OUTPUT_FILE"
echo "Result: $RESULT" >> "$OUTPUT_FILE"

if [[ "$STATUS" == "ok" || "$STATUS" == "not_available" ]]; then
  echo "True"
  exit 0
else
  echo "False"
  exit 1
fi
