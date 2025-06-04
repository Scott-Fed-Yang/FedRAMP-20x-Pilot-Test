#!/bin/bash

# Define output file for evidence
EVIDENCE_FILE="./evidence/KSI-CNA-1.txt"

# Ensure evidence directory exists
mkdir -p ./evidence

# Run AWS CLI command and capture output
RESULT=$(aws ec2 describe-security-groups --filters Name=group-name,Values=default --query 'SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,InboundRules:IpPermissions[*],OutboundRules:IpPermissionsEgress[*]}' --output json)

# Save result to evidence file
echo "$RESULT" > "$EVIDENCE_FILE"

# Parse result to check if InboundRules and OutboundRules are empty
INBOUND_EMPTY=$(echo "$RESULT" | jq '.[] | .InboundRules | length == 0')
OUTBOUND_EMPTY=$(echo "$RESULT" | jq '.[] | .OutboundRules | length == 0')

# Check if both are empty
if [ "$INBOUND_EMPTY" = "true" ] && [ "$OUTBOUND_EMPTY" = "true" ]; then
    echo "True"
else
    echo "False"
fi