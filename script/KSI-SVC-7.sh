#!/bin/bash

# Configuration
OUTPUT_FILE="./evidence/$(basename "$0" .sh).txt"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

TARGET_TOPIC="arn:aws:sns:us-east-1:137112412989:amazon-linux-2023-ami-updates"

echo "Verifying SNS subscription to: $TARGET_TOPIC" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

SUBSCRIPTIONS=$(aws sns list-subscriptions --region us-east-1)

echo "$SUBSCRIPTIONS" | jq -r --arg topic "$TARGET_TOPIC" '
  .Subscriptions[]
  | select(.TopicArn == $topic)
  | "- Protocol: \(.Protocol)\n  Endpoint: \(.Endpoint)\n  SubscriptionArn: \(.SubscriptionArn)\n"
' >> "$OUTPUT_FILE"

MATCH_COUNT=$(echo "$SUBSCRIPTIONS" | jq -r --arg topic "$TARGET_TOPIC" '
  [.Subscriptions[] | select(.TopicArn == $topic)] | length
')


if [ "$MATCH_COUNT" -gt 0 ]; then
  echo "" >> "$OUTPUT_FILE"
  echo "✅ Subscription(s) found for $TARGET_TOPIC." >> "$OUTPUT_FILE"
  echo "True"
  exit 0
else
  echo "❌ No subscriptions found for $TARGET_TOPIC." >> "$OUTPUT_FILE"
  echo "False"
  exit 1
fi