#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

#no fips endpoint
AWS_USE_FIPS_ENDPOINT=false

############################################
# 1. Reliability High Risk Check
############################################
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

############################################
# 2. Security High Risk Check
############################################
CHECK_NAME_SEC="AWS Well-Architected high risk issues for security"
CHECK_ID_SEC=$(aws support describe-trusted-advisor-checks --language en \
  | jq -r --arg name "$CHECK_NAME_SEC" '.checks[] | select(.name == $name) | .id')

if [ -z "$CHECK_ID_SEC" ]; then
  echo "Unable to find Trusted Advisor check ID for: $CHECK_NAME_SEC" >> "$OUTPUT_FILE"
  echo "False"
  exit 1
fi

RESULT_SEC=$(aws support describe-trusted-advisor-check-result --check-id "$CHECK_ID_SEC" --language en)
STATUS_SEC=$(echo "$RESULT_SEC" | jq -r '.result.status')

############################################
# 3. Performance Efficiency High Risk Check
############################################
CHECK_NAME_PER="AWS Well-Architected high risk issues for performance efficiency"
CHECK_ID_PER=$(aws support describe-trusted-advisor-checks --language en \
  | jq -r --arg name "$CHECK_NAME_PER" '.checks[] | select(.name == $name) | .id')

if [ -z "$CHECK_ID_PER" ]; then
  echo "Unable to find Trusted Advisor check ID for: $CHECK_NAME_PER" >> "$OUTPUT_FILE"
  echo "False"
  exit 1
fi

RESULT_PER=$(aws support describe-trusted-advisor-check-result --check-id "$CHECK_ID_PER" --language en)
STATUS_PER=$(echo "$RESULT_PER" | jq -r '.result.status')

############################################
# Final Evaluation
############################################

echo "Trusted Advisor AWS Well-Architected Check Summary" > "$OUTPUT_FILE"
echo "Date: $(date -u)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Trusted Advisor Check: $CHECK_NAME" >> "$OUTPUT_FILE"
echo "ID: $CHECK_ID" >> "$OUTPUT_FILE"
echo "Result: $RESULT" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Trusted Advisor Check: $CHECK_NAME_SEC" >> "$OUTPUT_FILE"
echo "ID: $CHECK_ID_SEC" >> "$OUTPUT_FILE"
echo "Result: $RESULT_SEC" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Trusted Advisor Check: $CHECK_NAME_PER" >> "$OUTPUT_FILE"
echo "ID: $CHECK_ID_PER" >> "$OUTPUT_FILE"
echo "Result: $RESULT_PER" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

if [[ "$STATUS" == "ok" && "$STATUS_SEC" == "ok" && "$STATUS_PER" == "ok" ]]; then
  echo "True"
  exit 0
else
  echo "False"
  exit 1
fi
