#!/usr/bin/env bash
# =============================================================
# Blue-Green Deployment Script
# Deploys to the inactive slot, health-checks it, then cuts
# traffic over.  Rolls back automatically on failure.
# Usage: bash scripts/blue-green-deploy.sh [version]
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
NEW_VERSION="${1:-2.0.0}"

# ── Helpers ──────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
die()  { log "ERROR: $*"; exit 1; }

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
    if [ "$code" = "200" ]; then
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  return 1
}

# ── Read current state ───────────────────────────────────────
CURRENT_SLOT=$(cat "$SCRIPT_DIR/.current_slot" 2>/dev/null || echo "blue")

if [ "$CURRENT_SLOT" = "blue" ]; then
  NEW_SLOT="green"
  NEW_PORT=$GREEN_PORT
else
  NEW_SLOT="blue"
  NEW_PORT=$BLUE_PORT
fi

NEW_PID_FILE="$PID_DIR/${NEW_SLOT}.pid"
PROD_PID_FILE="$PID_DIR/prod.pid"

mkdir -p "$LOG_DIR" "$PID_DIR"

echo ""
echo "================================================="
echo "  Blue-Green Deployment"
echo "================================================="
log "Current active slot : $CURRENT_SLOT"
log "Deploying to        : $NEW_SLOT  (port $NEW_PORT)"
log "New version         : $NEW_VERSION"
echo ""

# ── Step 1: Stop any stale process in the new slot ──────────
stop_pid_file "$NEW_PID_FILE" "$NEW_SLOT"

# ── Step 2: Start new slot ───────────────────────────────────
log "Starting $NEW_SLOT on port $NEW_PORT..."
cd "$APP_DIR"
APP_VERSION="$NEW_VERSION" SLOT="$NEW_SLOT" PORT="$NEW_PORT" \
  node server.js >> "$LOG_DIR/deploy-${NEW_SLOT}.log" 2>&1 &
NEW_PID=$!
echo "$NEW_PID" > "$NEW_PID_FILE"
log "$NEW_SLOT started (PID $NEW_PID)"

# ── Step 3: Health check new slot ────────────────────────────
log "Health-checking $NEW_SLOT..."
if ! wait_for_health "$NEW_PORT"; then
  log "HEALTH CHECK FAILED — rolling back"
  stop_pid_file "$NEW_PID_FILE" "$NEW_SLOT"
  die "Deployment aborted. $CURRENT_SLOT remains active."
fi
log "Health check PASSED on port $NEW_PORT"

# ── Step 4: Switch production traffic ────────────────────────
log "Switching production to $NEW_SLOT..."

stop_pid_file "$PROD_PID_FILE" "prod"

APP_VERSION="$NEW_VERSION" SLOT="$NEW_SLOT" PORT="$PROD_PORT" \
  node server.js >> "$LOG_DIR/deploy-prod.log" 2>&1 &
PROD_PID=$!
echo "$PROD_PID" > "$PROD_PID_FILE"
log "Production started on port $PROD_PORT (PID $PROD_PID)"

sleep 2
if ! wait_for_health "$PROD_PORT"; then
  log "Production health check FAILED — reverting"
  stop_pid_file "$PROD_PID_FILE" "prod"
  die "Switch failed. Re-run rollback.sh to restore $CURRENT_SLOT."
fi

# ── Step 5: Save state ───────────────────────────────────────
echo "$CURRENT_SLOT" > "$SCRIPT_DIR/.previous_slot"
echo "$NEW_SLOT"     > "$SCRIPT_DIR/.current_slot"

# Append to deployment log
{
  echo "$(date '+%Y-%m-%d %H:%M:%S') DEPLOY  slot=$NEW_SLOT version=$NEW_VERSION pid=$PROD_PID"
} >> "$LOG_DIR/deployments.log"

echo ""
echo "================================================="
echo "  Deployment Successful!"
echo "================================================="
log "Active slot : $NEW_SLOT -> http://localhost:$PROD_PORT"
log "Version     : $NEW_VERSION"
log "Previous    : $CURRENT_SLOT (still on port $NEW_PORT for quick rollback)"
echo ""
echo "  To rollback:   bash scripts/rollback.sh"
echo ""
