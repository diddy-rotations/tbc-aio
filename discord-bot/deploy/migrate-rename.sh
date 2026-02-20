#!/usr/bin/env bash
set -euo pipefail

# ─── Flux AIO Discord Bot — One-time Migration Script ───
# Migrates from diddy-bot → flux-bot after the rebrand.
# Run once on the VPS, then delete this script.

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${CYAN}→${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
err()   { echo -e "${RED}✗${NC} $*" >&2; }
header() { echo -e "\n${BOLD}$*${NC}"; }

OLD_SERVICE="diddy-bot"
NEW_SERVICE="flux-bot"

# Load nvm if present
export NVM_DIR="${HOME}/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$BOT_DIR/.." && pwd)"

header "Flux AIO — Rebrand Migration"

# ─── 1. Stop old service ───
header "[1/5] Stopping old service"
if systemctl is-active --quiet "$OLD_SERVICE" 2>/dev/null; then
    sudo systemctl stop "$OLD_SERVICE"
    sudo systemctl disable "$OLD_SERVICE"
    ok "Stopped and disabled $OLD_SERVICE"
else
    info "$OLD_SERVICE not running (skipping)"
fi

# Remove old service file
if [ -f "/etc/systemd/system/${OLD_SERVICE}.service" ]; then
    sudo rm "/etc/systemd/system/${OLD_SERVICE}.service"
    sudo systemctl daemon-reload
    ok "Removed old service file"
fi

# ─── 2. Update git remote ───
header "[2/5] Updating git remote"
cd "$REPO_DIR"
git remote set-url origin git@github.com:flux-rotations/tbc.git
ok "Remote updated to flux-rotations/tbc"

# ─── 3. Pull latest ───
header "[3/5] Pulling latest code"
git pull
ok "Code updated"

# ─── 4. Install deps & rebuild ───
header "[4/5] Installing dependencies & rebuilding"
npm install
cd "$REPO_DIR/rotation"
node build.js
ok "Dependencies installed, rotation built"

# ─── 5. Install new service & start ───
header "[5/5] Installing flux-bot service"
cd "$REPO_DIR"
bash discord-bot/deploy/setup.sh

header "Migration complete!"
echo ""
echo "Old service ($OLD_SERVICE) removed."
echo "New service ($NEW_SERVICE) is running."
echo ""
echo "You can delete this script now:"
echo "  rm $SCRIPT_DIR/migrate-rename.sh"
