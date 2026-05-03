#!/usr/bin/env bash
# =============================================================
# Health Check Monitoring Script
# Polls the app's /health endpoint every INTERVAL seconds and
# appends results to logs/health-check.log.
# Usage: bash scripts/health-check.sh [interval_seconds]
# =============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/health-check.log"
APP_URL="http://localhost:3000/health"
INTERVAL="${1:-30}"

mkdir -p "$LOG_DIR"

stamp() { date '+%Y-%m-%d %H:%M:%S'; }

log() {
  local msg="[$(stamp)] $*"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE"
}

echo ""
echo "================================================="
echo "  Health Check Monitor"
echo "================================================="
echo "  URL      : $APP_URL"
echo "  Interval : ${INTERVAL}s"
echo "  Log file : $LOG_FILE"
echo ""
echo "  Press Ctrl+C to stop."
echo ""

log "=== Monitor started (interval=${INTERVAL}s) ==="

consecutive_failures=0

while true; do
  # Capture HTTP status code and response body
  BODY_FILE="$LOG_DIR/.health_response_tmp"
  HTTP_CODE=$(curl -s -o "$BODY_FILE" -w "%{http_code}" \
    --max-time 5 "$APP_URL" 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "200" ]; then
    BODY=$(cat "$BODY_FILE" 2>/dev/null | tr -d '\n' || echo "{}")
    log "OK      | HTTP $HTTP_CODE | $BODY"
    consecutive_failures=0
  else
    log "FAIL    | HTTP $HTTP_CODE | App unreachable at $APP_URL"
    consecutive_failures=$((consecutive_failures + 1))

    if [ "$consecutive_failures" -ge 3 ]; then
      log "ALERT   | $consecutive_failures consecutive failures — app may be down!"
    fi
  fi

  sleep "$INTERVAL"
done
