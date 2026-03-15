#!/bin/bash
set -e

# ══════════════════════════════════════════════════════════════════
# IronClaw Railway Template — start.sh (NullClaw Edition)
# Automatically writes .env from Railway env vars and starts IronClaw
# ══════════════════════════════════════════════════════════════════

LOCKFILE="/tmp/start.sh.lock"

# Check for stale lockfile and existing process
if [ -f "$LOCKFILE" ]; then
    EXISTING_PID=$(cat "$LOCKFILE" 2>/dev/null)
    if [ -n "$EXISTING_PID" ] && [ "$EXISTING_PID" != "$$" ] && [ "$EXISTING_PID" != "1" ]; then
        if kill -0 "$EXISTING_PID" 2>/dev/null; then
            echo "start.sh already running (PID: $EXISTING_PID). Exiting."
            exit 0
        else
            # Stale lockfile, remove it
            rm -f "$LOCKFILE"
        fi
    fi
fi
echo $$ > "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

# Kill any stale ironclaw process
if pgrep -x ironclaw > /dev/null 2>&1; then
    echo "Cleaning up existing ironclaw process..."
    if ! pkill -x ironclaw 2>/dev/null; then
        echo "Warning: Could not gracefully stop ironclaw, forcing kill..."
        pkill -9 -x ironclaw || true
    fi
    sleep 2
fi

ENV_FILE="/data/.ironclaw/.env"
mkdir -p /data/.ironclaw /data/.ironclaw/logs /data/.npm-global /data/.npm-cache

# npm + Homebrew setup
npm config set prefix '/data/.npm-global'
npm config set cache '/data/.npm-cache'
if [ -x "/data/.linuxbrew/bin/brew" ]; then
    eval "
$('/data/.linuxbrew/bin/brew shellenv)"
else
    echo "Warning: Homebrew not found, continuing without it..."
fi

# ─── Validate required env vars ──────────────────────────────────
if [ -z "$LLM_API_KEY" ]; then
    echo "ERROR: LLM_API_KEY is not set in Railway Variables."
    exit 1
fi
if [ -z "$GATEWAY_AUTH_TOKEN" ]; then
    echo "ERROR: GATEWAY_AUTH_TOKEN is not set in Railway Variables."
    exit 1
fi

# ─── Write .env from Railway env vars ────────────────────────────
echo "Writing IronClaw config..."
cat > "$ENV_FILE" <<EOF
DATABASE_BACKEND=${DATABASE_BACKEND:-libsql}
LLM_BACKEND=${LLM_BACKEND:-anthropic}
LLM_API_KEY=${LLM_API_KEY}
LLM_MODEL=${LLM_MODEL:-claude-sonnet-4-20250514}
AGENT_NAME=ironclaw
CLI_ENABLED=false
GATEWAY_ENABLED=true
GATEWAY_HOST=0.0.0.0
GATEWAY_PORT=8080
GATEWAY_AUTH_TOKEN=${GATEWAY_AUTH_TOKEN}
SANDBOX_ENABLED=false
HEARTBEAT_ENABLED=false
EMBEDDING_ENABLED=false
IRONCLAW_IN_DOCKER=true
IRONCLAW_RESTART_DELAY=5
IRONCLAW_MAX_FAILURES=${IRONCLAW_MAX_FAILURES:-10}
EOF
echo ".env written."

# ─── Install default WASM extensions (once) ──────────────────────
TOOLS_DIR="/data/.ironclaw/tools"
if [ -d "$TOOLS_DIR" ] && ls "$TOOLS_DIR"/*.wasm 1>/dev/null 2>&1; then
    echo "Extensions already installed, skipping."
else
    echo "Installing default extensions..."
    if ! ironclaw registry install-defaults --force 2>&1; then
        echo "Warning: Extension installation failed (non-fatal), continuing..."
    fi
fi

# ─── Start IronClaw with restart loop ────────────────────────────
echo "Starting IronClaw gateway on port 8080..."
FAIL_COUNT=0
MAX_FAILS=${IRONCLAW_MAX_FAILURES:-10}

while true; do
    ironclaw run --no-onboard
    EXIT_CODE=$?
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "IronClaw exited (code $EXIT_CODE, attempt $FAIL_COUNT/$MAX_FAILS). Restarting in 5s..."
    if [ $FAIL_COUNT -ge $MAX_FAILS ]; then
        echo "Too many failures. Exiting."
        exit 1
    fi
    sleep 5
done