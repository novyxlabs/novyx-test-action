#!/usr/bin/env bash
set -euo pipefail

# Novyx Memory Integrity Check — GitHub Action runner
# =====================================================

API_KEY="${NOVYX_API_KEY:?NOVYX_API_KEY is required}"
BASE_URL="${NOVYX_BASE_URL:-https://novyx-ram-api.fly.dev}"
CHECKS="${NOVYX_CHECKS:-audit_health,stats}"
FAIL_ON_ERROR="${NOVYX_FAIL_ON_ERROR:-true}"

AUTH_HEADER="Authorization: Bearer ${API_KEY}"
ERRORS=0
SUMMARY="{}"

echo "::group::Novyx Memory Integrity Check"
echo "Base URL: ${BASE_URL}"
echo "Checks:  ${CHECKS}"
echo ""

# ---------- audit_health ----------
if echo "${CHECKS}" | grep -q "audit_health"; then
  echo "--- Audit Health ---"
  RESP=$(curl -sf -H "${AUTH_HEADER}" "${BASE_URL}/v1/audit/summary" 2>&1) || {
    echo "::warning::Audit health check failed to connect"
    ERRORS=$((ERRORS + 1))
    RESP="{}"
  }
  TOTAL_OPS=$(echo "${RESP}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total_operations', 0))" 2>/dev/null || echo "0")
  ANOMALIES=$(echo "${RESP}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('anomaly_count', 0))" 2>/dev/null || echo "0")

  echo "Total operations: ${TOTAL_OPS}"
  echo "Anomalies: ${ANOMALIES}"

  if [ "${ANOMALIES}" -gt 0 ]; then
    echo "::warning::${ANOMALIES} audit anomalies detected"
  fi

  AUDIT_HEALTHY="true"
  if [ "${ANOMALIES}" -gt 0 ]; then
    AUDIT_HEALTHY="false"
  fi
  echo "audit-healthy=${AUDIT_HEALTHY}" >> "${GITHUB_OUTPUT:-/dev/null}"
  SUMMARY=$(echo "${SUMMARY}" | python3 -c "import sys,json; d=json.load(sys.stdin); d['audit']={'total_operations':${TOTAL_OPS},'anomalies':${ANOMALIES},'healthy':${AUDIT_HEALTHY}}; print(json.dumps(d))" 2>/dev/null || echo "${SUMMARY}")
  echo ""
fi

# ---------- stats ----------
if echo "${CHECKS}" | grep -q "stats"; then
  echo "--- Memory Stats ---"
  RESP=$(curl -sf -H "${AUTH_HEADER}" "${BASE_URL}/v1/memories/stats" 2>&1) || {
    echo "::warning::Stats check failed to connect"
    ERRORS=$((ERRORS + 1))
    RESP="{}"
  }
  MEM_COUNT=$(echo "${RESP}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total_memories', 0))" 2>/dev/null || echo "0")
  echo "Total memories: ${MEM_COUNT}"
  echo "memory-count=${MEM_COUNT}" >> "${GITHUB_OUTPUT:-/dev/null}"
  SUMMARY=$(echo "${SUMMARY}" | python3 -c "import sys,json; d=json.load(sys.stdin); d['stats']={'total_memories':${MEM_COUNT}}; print(json.dumps(d))" 2>/dev/null || echo "${SUMMARY}")
  echo ""
fi

# ---------- integrity ----------
if echo "${CHECKS}" | grep -q "integrity"; then
  echo "--- Integrity Verification (Pro+) ---"
  RESP=$(curl -sf -H "${AUTH_HEADER}" "${BASE_URL}/v1/audit/verify" 2>&1) || {
    echo "::warning::Integrity check failed (may require Pro tier)"
    ERRORS=$((ERRORS + 1))
    RESP="{}"
  }
  VALID=$(echo "${RESP}" | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if d.get('valid') or d.get('all_valid') else 'false')" 2>/dev/null || echo "false")
  echo "Integrity valid: ${VALID}"
  echo "integrity-valid=${VALID}" >> "${GITHUB_OUTPUT:-/dev/null}"
  SUMMARY=$(echo "${SUMMARY}" | python3 -c "import sys,json; d=json.load(sys.stdin); d['integrity']={'valid':${VALID}}; print(json.dumps(d))" 2>/dev/null || echo "${SUMMARY}")

  if [ "${VALID}" = "false" ]; then
    echo "::error::Memory integrity check FAILED"
    ERRORS=$((ERRORS + 1))
  fi
  echo ""
fi

echo "summary=${SUMMARY}" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "::endgroup::"

# ---------- Result ----------
if [ "${ERRORS}" -gt 0 ] && [ "${FAIL_ON_ERROR}" = "true" ]; then
  echo "::error::${ERRORS} check(s) failed"
  exit 1
fi

echo "All checks passed."
