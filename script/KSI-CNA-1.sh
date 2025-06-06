#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Run AWS CLI command and capture output
aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,Description:Description,VpcId:VpcId,InboundRules:IpPermissions,OutboundRules:IpPermissionsEgress}' \
    --output json > "$OUTPUT_FILE"

# Final result
echo "True"