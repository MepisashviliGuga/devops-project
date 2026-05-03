#!/usr/bin/env bash
# =============================================================
# IaC Setup Script — run once to fully prepare the environment.
# Usage: bash scripts/setup.sh
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_DIR/app"

print_header() {
  echo ""
  echo "================================================="
  echo "  $1"
  echo "================================================="
}

print_ok()   { echo "  [OK]  $1"; }
print_err()  { echo "  [ERR] $1"; }
print_info() { echo "  [--]  $1"; }

print_header "DevOps Project — Environment Setup"
echo ""

# ── 1. Prerequisite checks ──────────────────────────────────
print_info "Checking prerequisites..."

if ! command -v node &>/dev/null; then
  print_err "Node.js is not installed."
  echo ""
  echo "  Install it from: https://nodejs.org/"
  exit 1
fi
print_ok "Node.js $(node --version)"

if ! command -v npm &>/dev/null; then
  print_err "npm is not installed (it ships with Node.js)."
  exit 1
fi
print_ok "npm $(npm --version)"

if ! command -v curl &>/dev/null; then
  print_err "curl is not found. Install Git for Windows (includes curl) or add it to PATH."
  exit 1
fi
print_ok "curl $(curl --version | head -1)"

if ! command -v git &>/dev/null; then
  print_err "git is not installed."
  exit 1
fi
print_ok "git $(git --version)"

# ── 2. Create directory structure ───────────────────────────
print_header "Creating Directory Structure"

mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$SCRIPT_DIR/pids"
print_ok "logs/           — application & health-check logs"
print_ok "scripts/pids/   — PID files for process tracking"

# ── 3. Install Node.js dependencies ─────────────────────────
print_header "Installing Application Dependencies"

cd "$APP_DIR"
npm install
print_ok "node_modules installed in app/"

# ── 4. Initialise deployment state ──────────────────────────
print_header "Initialising Deployment State"

echo "blue"  > "$SCRIPT_DIR/.current_slot"
echo ""      > "$SCRIPT_DIR/pids/blue.pid"
echo ""      > "$SCRIPT_DIR/pids/green.pid"
echo ""      > "$SCRIPT_DIR/pids/prod.pid"
echo "none"  > "$SCRIPT_DIR/.previous_slot"
print_ok "Current slot set to: blue"
print_ok "PID files initialised"

# ── 5. Create .env if absent ────────────────────────────────
ENV_FILE="$PROJECT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  cat > "$ENV_FILE" <<'EOF'
APP_VERSION=1.0.0
PROD_PORT=3000
BLUE_PORT=3001
GREEN_PORT=3002
EOF
  print_ok ".env created with default port configuration"
else
  print_info ".env already exists — skipping"
fi

# ── 6. Verify tests pass ─────────────────────────────────────
print_header "Running Tests to Verify Setup"

cd "$APP_DIR"
npm test
print_ok "All tests passed"

# ── Done ─────────────────────────────────────────────────────
print_header "Setup Complete"
echo ""
echo "  Available commands:"
echo ""
echo "  Start app (dev)     : cd app && npm start"
echo "  Blue-Green deploy   : bash scripts/blue-green-deploy.sh"
echo "  Rollback            : bash scripts/rollback.sh"
echo "  Health monitor      : bash scripts/health-check.sh"
echo ""
echo "  App will run on     : http://localhost:3000"
echo ""
