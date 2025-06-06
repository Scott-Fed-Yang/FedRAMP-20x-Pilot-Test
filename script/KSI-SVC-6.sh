#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Skipped key ID
SKIPPED_KEY="ac5934d9-6d65-405d-9826-e185079d1ceb"

# Initialize evidence file
echo "KMS Key Rotation Status Check" > "$EVIDENCE_FILE"
echo "Date: $(date)" >> "$EVIDENCE_FILE"
echo "------------------------" >> "$EVIDENCE_FILE"

# Flag to track if all symmetric keys have rotation enabled
ALL_ROTATION_ENABLED=true

# Get list of KMS keys
KEY_LIST=$(aws kms list-keys --output json)

# Check if command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to list KMS keys" >> "$EVIDENCE_FILE"
    echo "False"
    exit 1
fi

# Extract KeyIds
KEY_IDS=$(echo "$KEY_LIST" | jq -r '.Keys[].KeyId')

# Check if there are any keys
if [ -z "$KEY_IDS" ]; then
    echo "No KMS keys found" >> "$EVIDENCE_FILE"
    echo "True"  # No keys means no symmetric keys to check, so return True
    exit 0
fi

# Iterate through each KeyId
for KEY_ID in $KEY_IDS; do
    # Skip the specified key
    if [ "$KEY_ID" = "$SKIPPED_KEY" ]; then
        echo "KeyId: $KEY_ID" >> "$EVIDENCE_FILE"
        echo "Status: Skipped (Ruled by AWS, cannot be managed)" >> "$EVIDENCE_FILE"
        echo "------------------------" >> "$EVIDENCE_FILE"
        continue
    fi

    # Get key metadata
    KEY_METADATA=$(aws kms describe-key --key-id "$KEY_ID" --query 'KeyMetadata.{KeyManager:KeyManager,KeySpec:KeySpec}' --output json)

    if [ $? -ne 0 ]; then
        echo "KeyId: $KEY_ID - Error: Failed to describe key" >> "$EVIDENCE_FILE"
        ALL_ROTATION_ENABLED=false
        continue
    fi

    # Check if key is symmetric (KeySpec: SYMMETRIC_DEFAULT)
    KEY_SPEC=$(echo "$KEY_METADATA" | jq -r '.KeySpec')
    KEY_MANAGER=$(echo "$KEY_METADATA" | jq -r '.KeyManager')

    if [ "$KEY_SPEC" = "SYMMETRIC_DEFAULT" ]; then
        # Get key rotation status
        ROTATION_STATUS=$(aws kms get-key-rotation-status --key-id "$KEY_ID" --output json)

        if [ $? -ne 0 ]; then
            echo "KeyId: $KEY_ID - Error: Failed to get rotation status" >> "$EVIDENCE_FILE"
            ALL_ROTATION_ENABLED=false
            continue
        fi

        # Extract rotation status
        ROTATION_ENABLED=$(echo "$ROTATION_STATUS" | jq -r '.KeyRotationEnabled')

        # Log result to evidence file
        echo "KeyId: $KEY_ID" >> "$EVIDENCE_FILE"
        echo "KeySpec: $KEY_SPEC" >> "$EVIDENCE_FILE"
        echo "KeyManager: $KEY_MANAGER" >> "$EVIDENCE_FILE"
        echo "KeyRotationEnabled: $ROTATION_ENABLED" >> "$EVIDENCE_FILE"
        echo "------------------------" >> "$EVIDENCE_FILE"

        # Update flag if rotation is not enabled
        if [ "$ROTATION_ENABLED" != "true" ]; then
            ALL_ROTATION_ENABLED=false
        fi
    else
        # Log non-symmetric keys (not counted in result)
        echo "KeyId: $KEY_ID" >> "$EVIDENCE_FILE"
        echo "KeySpec: $KEY_SPEC" >> "$EVIDENCE_FILE"
        echo "KeyManager: $KEY_MANAGER" >> "$EVIDENCE_FILE"
        echo "Status: Skipped (Not a symmetric key)" >> "$EVIDENCE_FILE"
        echo "------------------------" >> "$EVIDENCE_FILE"
    fi
done

# Output final result
if [ "$ALL_ROTATION_ENABLED" = true ]; then
    echo "Result: All symmetric keys have key rotation enabled" >> "$EVIDENCE_FILE"
    echo "True"
else
    echo "Result: Not all symmetric keys have key rotation enabled" >> "$EVIDENCE_FILE"
    echo "False"
fi
