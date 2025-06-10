#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

#no fips endpoint
AWS_USE_FIPS_ENDPOINT=false

# Target Trusted Advisor check names
CHECK_NAMES=(
  "Security Groups - Unrestricted Access"
  "Security Groups - Specific Ports Unrestricted"
)

ALL_OK=true

# Loop through each check name
for CHECK_NAME in "${CHECK_NAMES[@]}"; do
  CHECK_ID=$(aws support describe-trusted-advisor-checks --language en \
    | jq -r --arg name "$CHECK_NAME" '.checks[] | select(.name == $name) | .id')

  if [ -z "$CHECK_ID" ]; then
    echo "Unable to find Trusted Advisor check ID for: $CHECK_NAME" >> "$OUTPUT_FILE"
    ALL_OK=false
    continue
  fi

  RESULT=$(aws support describe-trusted-advisor-check-result --check-id "$CHECK_ID" --language en)
  STATUS=$(echo "$RESULT" | jq -r '.result.status')


  echo "Trusted Advisor Check: $CHECK_NAME" >> "$OUTPUT_FILE"
  echo "Date: $(date -u)" >> "$OUTPUT_FILE"
  echo "ID: $CHECK_ID" >> "$OUTPUT_FILE"
  echo "Result: $RESULT" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  if [[ "$STATUS" != "ok" && "$STATUS" != "not_available" ]]; then
    ALL_OK=false
  fi
done

# Final result
if [ "$ALL_OK" = true ]; then
  echo "All security group checks passed (no unrestricted exposure)." >> "$OUTPUT_FILE"
  echo "True"
else
  echo "One or more security group checks reported issues." >> "$OUTPUT_FILE"
  echo "False"
fi
