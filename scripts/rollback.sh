#!/usr/bin/env bash
# =============================================================
# Rollback Script
# Reverts production to the previously active slot.
# Usage: bash scripts/rollback.sh
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_DIR/app"
LOG_DIR="$PROJECT_DIR/logs"
PID_DIR="$SCRIPT_DIR/pids"

BLUE_PORT=3001
GREEN_PORT=3002
PROD_PORT=3000

log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { log "ERROR: $*"; exit 1; }

is_alive() {
  local pid="$1"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

stop_pid_file() {
  local file="$1"
  local label="$2"
  if [ -s "$file" ]; then
    local pid
    pid=$(cat "$file")
    if is_alive "$pid"; then
      log "Stopping $label (PID $pid)..."
      kill "$pid" 2>/dev/null || true
      sleep 1
    fi
  fi
  echo "" > "$file"
}

wait_for_health() {
  local port="$1"
  local retries=10
  local i=0
  while [ $i -lt $retries ]; do
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}/health" 2>/dev/null || echo "000")
    if [ "$code" = "200" ]; then return 0; fi
    i=$((i + 1))
    sleep 1
  done
  return 1
}

CURRENT_SLOT=$(cat "$SCRIPT_DIR/.current_slot"  2>/dev/null || echo "blue")
PREVIOUS_SLOT=$(cat "$SCRIPT_DIR/.previous_slot" 2>/dev/null || echo "none")

echo ""
echo "================================================="
echo "  Rollback"
echo "================================================="
log "Current  : $CURRENT_SLOT"
log "Rollback : $PREVIOUS_SLOT"
echo ""

if [ "$PREVIOUS_SLOT" = "none" ] || [ "$PREVIOUS_SLOT" = "$CURRENT_SLOT" ]; then
  die "No previous slot recorded. Cannot roll back."
fi

# Determine the port the previous slot is already running on
if [ "$PREVIOUS_SLOT" = "blue" ]; then
  PREV_PORT=$BLUE_PORT
  PREV_VERSION="1.0.0"
else
  PREV_PORT=$GREEN_PORT
  PREV_VERSION="1.0.0"
fi

# ── Stop current production ───────────────────────────────────
stop_pid_file "$PID_DIR/prod.pid" "prod"

# ── Check if previous slot process is still alive ─────────────
PREV_PID_FILE="$PID_DIR/${PREVIOUS_SLOT}.pid"
if [ -s "$PREV_PID_FILE" ]; then
  PREV_PID=$(cat "$PREV_PID_FILE")
  if is_alive "$PREV_PID"; then
    log "Previous slot still running on port $PREV_PORT — reusing"
  else
    # Restart it
    log "Restarting $PREVIOUS_SLOT on port $PREV_PORT..."
    cd "$APP_DIR"
    APP_VERSION="$PREV_VERSION" SLOT="$PREVIOUS_SLOT" PORT="$PREV_PORT" \
      node server.js >> "$LOG_DIR/rollback-${PREVIOUS_SLOT}.log" 2>&1 &
    PREV_PID=$!
    echo "$PREV_PID" > "$PREV_PID_FILE"
  fi
else
  log "Starting $PREVIOUS_SLOT on port $PREV_PORT..."
  cd "$APP_DIR"
  APP_VERSION="$PREV_VERSION" SLOT="$PREVIOUS_SLOT" PORT="$PREV_PORT" \
    node server.js >> "$LOG_DIR/rollback-${PREVIOUS_SLOT}.log" 2>&1 &
  PREV_PID=$!
  echo "$PREV_PID" > "$PREV_PID_FILE"
fi

# ── Start on production port ──────────────────────────────────
log "Promoting $PREVIOUS_SLOT to production port $PROD_PORT..."
cd "$APP_DIR"
APP_VERSION="$PREV_VERSION" SLOT="$PREVIOUS_SLOT" PORT="$PROD_PORT" \
  node server.js >> "$LOG_DIR/rollback-prod.log" 2>&1 &
ROLLBACK_PID=$!
echo "$ROLLBACK_PID" > "$PID_DIR/prod.pid"

sleep 2

if ! wait_for_health "$PROD_PORT"; then
  die "Rollback health check failed on port $PROD_PORT."
fi

# ── Update state ──────────────────────────────────────────────
echo "$PREVIOUS_SLOT" > "$SCRIPT_DIR/.current_slot"
echo "$CURRENT_SLOT"  > "$SCRIPT_DIR/.previous_slot"

{
  echo "$(date '+%Y-%m-%d %H:%M:%S') ROLLBACK slot=$PREVIOUS_SLOT version=$PREV_VERSION pid=$ROLLBACK_PID"
} >> "$LOG_DIR/deployments.log"

echo ""
echo "================================================="
echo "  Rollback Successful!"
echo "================================================="
log "Active slot : $PREVIOUS_SLOT -> http://localhost:$PROD_PORT"
echo ""
