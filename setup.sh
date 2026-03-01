#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Pantri – one-command project setup
# Run from the repo root:  bash setup.sh
# ─────────────────────────────────────────────────────────────
set -euo pipefail

API_URL="http://127.0.0.1:3000"
BACKEND_DIR="src/python"

echo "──────────────────────────────────────────"
echo "  Pantri Setup  •  API → $API_URL"
echo "──────────────────────────────────────────"

# ── 1. Python virtual-env ────────────────────────────────────
echo ""
echo "▸ Creating Python virtual environment …"
python3 -m venv "$BACKEND_DIR/venv"
# shellcheck disable=SC1091
source "$BACKEND_DIR/venv/bin/activate"

echo "▸ Installing Python dependencies …"
pip install --quiet --upgrade pip
pip install --quiet -r "$BACKEND_DIR/requirements.txt"

# ── 2. .env (only if missing) ────────────────────────────────
if [ ! -f "$BACKEND_DIR/.env" ]; then
    echo "▸ Writing default .env (SQLite for local dev) …"
    cat > "$BACKEND_DIR/.env" <<EOF
# Pantri – local development environment
# For SQLite (zero-config):
DATABASE_URL=sqlite:///pantri.db

# For PostgreSQL, uncomment and fill in:
# POSTGRES_USER=pantri
# POSTGRES_PASSWORD=
# POSTGRES_HOST=localhost
# POSTGRES_DB=pantri
EOF
else
    echo "▸ .env already exists – skipping."
fi

# ── 3. Verify the backend starts on port 3000 ────────────────
echo ""
echo "▸ Starting Pantri backend on $API_URL …"
echo "  (Press Ctrl-C to stop the server)"
echo ""
python "$BACKEND_DIR/main.py"
