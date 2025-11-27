#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

#no fips endpoint
AWS_USE_FIPS_ENDPOINT=false

# ------------------------------
# Defined Whitelist (check_id → reason)
# ------------------------------
declare -A WHITELIST
WHITELIST["R365s2Qddf"]="V4G only enable S3 Bucket Versioning for customer data. the remaining S3 buckets are deployment/log buckets and has limited access from AWS service only. "
WHITELIST["c18d2gz119"]="V4G only enable S3 Bucket Replication for customer data. The remaining S3 buckets are deployment/log buckets and do not require cross-region replication."
WHITELIST["H7IgTzjTYb"]="V4G is serverless architecture. No need EBS Snapshots for fault tolerance"
WHITELIST["wuy7G1zxql"]="V4G workload is stateless and instances can be recreated rapidly if needed. Multi-AZ balancing is not required"

echo "Trusted Advisor - Fault Tolerance Checks Summary" > "$OUTPUT_FILE"
echo "Date: $(date -u)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# List Trusted Advisor checks category = fault_tolerance
all_checks=$(aws support describe-trusted-advisor-checks --language en)
fault_checks=$(echo "$all_checks" | jq -c '.checks[] | select(.category == "fault_tolerance")')

issue_count=0
whitelist_count=0
pass_count=0
total_checks=$(echo "$all_checks" | jq '[.checks[] | select(.category == "fault_tolerance")] | length')

while read -r check; do
  check_name=$(echo "$check" | jq -r '.name')
  check_id=$(echo "$check" | jq -r '.id')

  echo "Check: $check_name" >> "$OUTPUT_FILE"
  echo "Check ID: $check_id" >> "$OUTPUT_FILE"

  result=$(aws support describe-trusted-advisor-check-result --check-id "$check_id" --language en)
  status=$(echo "$result" | jq -r '.result.status')

  echo "Status: $status" >> "$OUTPUT_FILE"

  if [[ "$status" == "error" || "$status" == "warning" ]]; then
    if [[ -n "${WHITELIST[$check_id]}" ]]; then
      whitelist_count=$((whitelist_count + 1))
      echo "Whitelist: YES" >> "$OUTPUT_FILE"
      echo "Whitelist Reason: ${WHITELIST[$check_id]}" >> "$OUTPUT_FILE"
    else
      issue_count=$((issue_count + 1))
    fi
  else
    pass_count=$((pass_count + 1))
  fi

  echo "" >> "$OUTPUT_FILE"
done < <(echo "$fault_checks")

echo "----------------------------------------" >> "$OUTPUT_FILE"
echo "Total Fault Tolerance Checks: $total_checks" >> "$OUTPUT_FILE"
echo "Total Passed Checks (Including not_available): $pass_count" >> "$OUTPUT_FILE"
echo "Total Failed Checks: $issue_count" >> "$OUTPUT_FILE"
echo "Total Whitelisted Checks: $whitelist_count" >> "$OUTPUT_FILE"
echo "----------------------------------------" >> "$OUTPUT_FILE"

if [ "$issue_count" -gt 0 ]; then
  echo "False"
  exit 1
else
  echo "True"
  exit 0
fi