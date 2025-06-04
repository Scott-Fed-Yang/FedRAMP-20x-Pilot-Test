#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/KSI-CNA-4.txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Initialize output file
echo "IAM Policy Check Results" > "$OUTPUT_FILE"
echo "-----------------------" >> "$OUTPUT_FILE"

# Flag to track if any policy grants full admin privileges
has_full_admin=false

# Get list of attached IAM policies
policies=$(aws iam list-policies --only-attached --output text --query 'Policies[*].[Arn,DefaultVersionId]' 2>> "$OUTPUT_FILE")
if [ $? -ne 0 ]; then
  echo "Error: Failed to list IAM policies. See $OUTPUT_FILE for details." >&2
  echo "False"
  exit 1
fi

# Check if policies list is empty
if [ -z "$policies" ]; then
  echo "No attached IAM policies found." >> "$OUTPUT_FILE"
  echo "True"
  exit 0
fi

# Process each policy
while read -r policy_arn version_id; do
  echo "Checking policy: $policy_arn (Version: $version_id)" >> "$OUTPUT_FILE"
  # Get policy version document
  policy_doc=$(aws iam get-policy-version --policy-arn "$policy_arn" --version-id "$version_id" --query 'PolicyVersion.Document' --output json 2>> "$OUTPUT_FILE")
  if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve policy document for $policy_arn. See $OUTPUT_FILE for details." >> "$OUTPUT_FILE"
    continue
  fi

  # Check for full admin privileges (Effect:Allow, Action:*, Resource:*)
  has_admin=$(echo "$policy_doc" | jq -r '.Statement[] | select(.Effect == "Allow" and .Action == "*" and .Resource == "*") | "true"' 2>/dev/null)
  if [ "$has_admin" = "true" ]; then
    has_full_admin=true
    echo "Found full admin privileges in $policy_arn" >> "$OUTPUT_FILE"
  else
    echo "No full admin privileges in $policy_arn" >> "$OUTPUT_FILE"
  fi
  echo "Policy Document:" >> "$OUTPUT_FILE"
  echo "$policy_doc" | jq . >> "$OUTPUT_FILE" 2>/dev/null || echo "Invalid JSON policy document" >> "$OUTPUT_FILE"
  echo "-----------------------" >> "$OUTPUT_FILE"
done <<< "$policies"

# Return result based on findings
if [ "$has_full_admin" = "true" ]; then
  echo "False"
else
  echo "True"
fi
exit 0
