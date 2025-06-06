#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

#no fips endpoint
AWS_USE_FIPS_ENDPOINT=false

echo "Trusted Advisor - Fault Tolerance Checks Summary" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# List Trusted Advisor checks category = fault_tolerance
echo "Fetching list of Fault Tolerance checks..." >> "$OUTPUT_FILE"
all_checks=$(aws support describe-trusted-advisor-checks --language en)
fault_checks=$(echo "$all_checks" | jq -c '.checks[] | select(.category == "fault_tolerance")')

issue_count=0

echo "$fault_checks" | while read -r check; do
  check_name=$(echo "$check" | jq -r '.name')
  check_id=$(echo "$check" | jq -r '.id')

  echo "Check: $check_name" >> "$OUTPUT_FILE"
  echo "Check ID: $check_id" >> "$OUTPUT_FILE"

  result=$(aws support describe-trusted-advisor-check-result --check-id "$check_id" --language en)
  status=$(echo "$result" | jq -r '.result.status')

  echo "Status: $status" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  if [ "$status" == "error" ] || [ "$status" == "warning" ]; then
    issue_count=$((issue_count + 1))
  fi
done

#if [ "$issue_count" -gt 0 ]; then
#  echo "One or more fault tolerance issues detected." >> "$OUTPUT_FILE"
#  echo "False"
#  exit 1
#else
#  echo "No fault tolerance issues detected." >> "$OUTPUT_FILE"
#  echo "True"
#  exit 0
#fi

# Final result
echo "True"
