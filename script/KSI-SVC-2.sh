#!/bin/bash

# Configuration
SCRIPT_BASENAME="$(basename "$0" .sh)"
OUTPUT_DIR="./evidence"
OUTPUT_FILE="${OUTPUT_DIR}/${SCRIPT_BASENAME}.txt"

mkdir -p "$(dirname "$OUTPUT_FILE")"

# Result: optimistic true, any fail sets to False
RESULT="True"

# Audit log accumulator
AUDIT_LOG=""

# Helper: append line(s) to audit log
log_audit() {
  AUDIT_LOG+="$1"$'\n'
}

# Header
log_audit "Encryption In-Transit Checks"
log_audit "Generated at: $(date -u)"
log_audit "=================================================="
log_audit ""

# -------------------------
# 1) ALB Listener Check
# -------------------------
log_audit "--- 1. ALB Listener Check (HTTPS & Certificate) ---"

ALB_PASS=true
# JSON array of listeners
ALB_LISTENERS_JSON='[]'

# Get application load balancer ARNs (returns empty string if none)
lbs_text=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?Type==`application`].LoadBalancerArn' --output text || true)

if [ -z "${lbs_text:-}" ]; then
  log_audit "No Application Load Balancers found."
else
  # iterate safely over ARNs (space/newline separated)
  while IFS=$'\n' read -r lb_arn; do
    [ -z "$lb_arn" ] && continue

    # Get LB name (safe)
    lb_name=$(aws elbv2 describe-load-balancers --load-balancer-arns "$lb_arn" \
      --query 'LoadBalancers[0].LoadBalancerName' --output text || echo "")

    # Get listeners JSON
    listeners_json=$(aws elbv2 describe-listeners --load-balancer-arn "$lb_arn" --output json 2>/dev/null || echo '{}')

    # Build sanitized list of listeners (if any)
    listener_objs=$(echo "$listeners_json" | jq -c '.Listeners[]? | {
      LoadBalancerName: "'"$lb_name"'",
      Protocol: (.Protocol // "N/A"),
      Port: (.Port // 0),
      SslPolicy: (.SslPolicy // "N/A"),
      Certificates: (.Certificates // []) | map(.CertificateArn // "")
    }' 2>/dev/null || echo "")

    if [ -z "$listener_objs" ]; then
      log_audit "  [INFO] No listeners found for LB: ${lb_name:-$lb_arn}"
      continue
    fi

    while IFS= read -r listener; do
      [ -z "$listener" ] && continue

      # Append to ALB_LISTENERS_JSON array
      ALB_LISTENERS_JSON=$(echo "$ALB_LISTENERS_JSON" | jq --argjson item "$listener" '. + [$item]' 2>/dev/null || echo "$ALB_LISTENERS_JSON")

      protocol=$(echo "$listener" | jq -r '.Protocol // "N/A"')
      port=$(echo "$listener" | jq -r '.Port // 0')
      cert_count=$(echo "$listener" | jq '.Certificates | length' 2>/dev/null || echo 0)

      if [ "$protocol" = "HTTPS" ] && [ "$cert_count" -ge 1 ]; then
        log_audit "  [PASS] ALB Listener ${lb_name}:$port is HTTPS with ${cert_count} certificate(s)."
      elif [ "$protocol" = "HTTP" ]; then
        log_audit "  [INFO] ALB Listener ${lb_name}:$port is HTTP (ignored for this in-transit encryption check)."
      else
        # Non-HTTP/HTTPS protocol (or missing certificate on HTTPS) is considered a fail
        ALB_PASS=false
        log_audit "  [FAIL] ALB Listener ${lb_name}:$port protocol=${protocol} certificates=${cert_count}."
      fi
    done <<< "$listener_objs"
  done <<< "$(printf '%s\n' $lbs_text)"
fi

log_audit ""
log_audit "ALB Listeners Collected (JSON):"
log_audit "$ALB_LISTENERS_JSON"
log_audit ""

if ! $ALB_PASS; then
  RESULT="False"
fi

# -------------------------
# 2) Aurora In-Transit Encryption Check
# -------------------------
log_audit "--- 2. Aurora require_secure_transport / rds.force_ssl Check ---"

AURORA_PASS=true
AURORA_DATA='[]'

cluster_ids=$(aws rds describe-db-clusters --query 'DBClusters[].DBClusterIdentifier' --output text || true)

if [ -z "${cluster_ids:-}" ]; then
  log_audit "No RDS DB clusters found."
else
  # iterate cluster ids safely (space/newline separated)
  while IFS=$'\n' read -r cluster_id; do
    [ -z "$cluster_id" ] && continue

    engine=$(aws rds describe-db-clusters --db-cluster-identifier "$cluster_id" --query 'DBClusters[0].Engine' --output text || echo "")
    param_group=$(aws rds describe-db-clusters --db-cluster-identifier "$cluster_id" --query 'DBClusters[0].DBClusterParameterGroup' --output text || echo "")

    if [ -z "$engine" ] || [ -z "$param_group" ]; then
      log_audit "  [WARN] Could not obtain engine or parameter group for cluster: $cluster_id"
      AURORA_PASS=false
      # still record a minimal entry
      entry=$(jq -n --arg cluster "$cluster_id" --arg engine "${engine:-unknown}" --arg group "${param_group:-unknown}" '{
        ClusterIdentifier: $cluster,
        Engine: $engine,
        ParameterGroup: $group,
        ParameterName: null,
        ParameterValue: null,
        CheckStatus: "unknown"
      }')
      AURORA_DATA=$(echo "$AURORA_DATA" | jq ". + [ $entry ]")
      continue
    fi

    # Choose the checked parameter based on engine
    if [[ "$engine" == *"aurora-mysql"* ]]; then
      TARGET_KEY="require_secure_transport"
      # expected value: ON
      EXPECTED_VALUE_REGEX='^ON$'
    elif [[ "$engine" == *"aurora-postgresql"* ]]; then
      TARGET_KEY="rds.force_ssl"
      # expected values: 1 or true (string)
      EXPECTED_VALUE_REGEX='^(1|true)$'
    else
      log_audit "  [INFO] Cluster $cluster_id engine '$engine' not in scope for this check. Skipping."
      # record skipped entry
      entry=$(jq -n --arg cluster "$cluster_id" --arg engine "$engine" --arg group "$param_group" '{
        ClusterIdentifier: $cluster,
        Engine: $engine,
        ParameterGroup: $group,
        ParameterName: null,
        ParameterValue: null,
        CheckStatus: "skipped"
      }')
      AURORA_DATA=$(echo "$AURORA_DATA" | jq ". + [ $entry ]")
      continue
    fi

    # Fetch parameter values for the parameter group (may page; using aws cli default)
    param_json=$(aws rds describe-db-cluster-parameters --db-cluster-parameter-group-name "$param_group" --output json 2>/dev/null || echo '{}')

    # Extract parameter value (first match)
    val=$(echo "$param_json" | jq -r --arg key "$TARGET_KEY" '.Parameters[]? | select(.ParameterName==$key) | .ParameterValue' | head -n1 || true)
    val="${val:-}"

    # Decide pass/fail for this cluster
    check_status="fail"
    if [[ -n "$val" ]] && [[ "$val" =~ $EXPECTED_VALUE_REGEX ]]; then
      check_status="pass"
      log_audit "  [PASS] Cluster $cluster_id ($engine) parameter $TARGET_KEY = '$val' (expected)."
    else
      check_status="fail"
      AURORA_PASS=false
      log_audit "  [FAIL] Cluster $cluster_id ($engine) parameter $TARGET_KEY = '${val:-<not-set>}' (expected pattern: $EXPECTED_VALUE_REGEX)."
    fi

    # compose entry JSON and append
    entry=$(jq -n \
      --arg cluster "$cluster_id" \
      --arg engine "$engine" \
      --arg group "$param_group" \
      --arg key "$TARGET_KEY" \
      --arg value "${val:-}" \
      --arg status "$check_status" \
      '{
        ClusterIdentifier: $cluster,
        Engine: $engine,
        ParameterGroup: $group,
        ParameterName: $key,
        ParameterValue: $value,
        CheckStatus: $status
      }')

    AURORA_DATA=$(echo "$AURORA_DATA" | jq ". + [ $entry ]")
  done <<< "$(printf '%s\n' $cluster_ids)"
fi

log_audit ""
log_audit "Aurora Check Raw Data:"
log_audit "$AURORA_DATA"
log_audit ""

if ! $AURORA_PASS; then
  RESULT="False"
fi

# -------------------------
# Finalization
# -------------------------
log_audit "=================================================="
log_audit "Overall Result: $RESULT"

# Write AUDIT_LOG to output file
{
  echo "$AUDIT_LOG"
} > "$OUTPUT_FILE"

# Also print the result on stdout for CI consumption
echo "$RESULT"

# Exit with appropriate code
if [ "$RESULT" = "True" ]; then
  exit 0
else
  exit 1
fi
