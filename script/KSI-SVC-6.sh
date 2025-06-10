#!/bin/bash

SCRIPT_BASENAME=$(basename "$0" .sh)
OUTPUT_FILE="./evidence/${SCRIPT_BASENAME}.txt"
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "KMS Key Rotation Status Check" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "------------------------" >> "$OUTPUT_FILE"

ALL_ROTATION_ENABLED=true

# List all key IDs
KEY_IDS=$(aws kms list-keys --query 'Keys[*].KeyId' --output text)

for KEY_ID in $KEY_IDS; do
  METADATA=$(aws kms describe-key --key-id "$KEY_ID" --query 'KeyMetadata' --output json)
  KEY_MANAGER=$(echo "$METADATA" | jq -r '.KeyManager')
  KEY_SPEC=$(echo "$METADATA" | jq -r '.KeySpec')

  if [[ "$KEY_MANAGER" == "CUSTOMER" && "$KEY_SPEC" == "SYMMETRIC_DEFAULT" ]]; then
    ROTATION_ENABLED=$(aws kms get-key-rotation-status --key-id "$KEY_ID" --query 'KeyRotationEnabled' --output text | tr '[:upper:]' '[:lower:]')

    echo "KeyId: $KEY_ID" >> "$OUTPUT_FILE"
    echo "KeyManager: $KEY_MANAGER" >> "$OUTPUT_FILE"
    echo "KeySpec: $KEY_SPEC" >> "$OUTPUT_FILE"
    echo "KeyRotationEnabled: $ROTATION_ENABLED" >> "$OUTPUT_FILE"
    echo "------------------------" >> "$OUTPUT_FILE"

    if [ "$ROTATION_ENABLED" != "true" ]; then
      echo "KeyId $KEY_ID does NOT have rotation enabled" >> "$OUTPUT_FILE"
      ALL_ROTATION_ENABLED=false
    fi
  fi
done

# Final result
if [ "$ALL_ROTATION_ENABLED" = true ]; then
  echo "Result: All customer symmetric keys have rotation enabled" >> "$OUTPUT_FILE"
  echo "True"
else
  echo "Result: Some customer symmetric keys do NOT have rotation enabled" >> "$OUTPUT_FILE"
  echo "False"
fi
