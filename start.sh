#!/bin/bash
set -e

# ══════════════════════════════════════════════════════════════════
# IronClaw Railway Template — start.sh (NullClaw Edition + Hermes)
# Automatically writes .env from Railway env vars and starts IronClaw
# Hermes agent runs alongside on port 8081
# ══════════════════════════════════════════════════════════════════

LOCKFILE="/tmp/start.sh.lock"

# Prefer flock if available for an atomic lock
if command -v flock >/dev/null 2>&1; then
    exec 9> "$LOCKFILE"
    if ! flock -n 9; then
        echo "start.sh already running (locked by another process). Exiting."
        exit 0
    fi
    trap 'rm -f "$LOCKFILE"; flock -u 9 || true' EXIT
else
    if [ -f "$LOCKFILE" ]; then
        EXISTING_PID=$(cat "$LOCKFILE" 2>/dev/null || true)
        if printf '%s\n' "$EXISTING_PID" | grep -Eq '^[0-9]+$'; then
            if [ "$EXISTING_PID" != "$$" ] && [ "$EXISTING_PID" != "1" ]; then
                if kill -0 "$EXISTING_PID" 2>/dev/null; then
                    echo "start.sh already running (PID: $EXISTING_PID). Exiting."
                    exit 0
                else
                    rm -f "$LOCKFILE"
                fi
            fi
        else
            rm -f "$LOCKFILE"
        fi
    fi
    echo $$ > "$LOCKFILE"
    trap "rm -f $LOCKFILE" EXIT
fi

# Kill any stale ironclaw process
if command -v pgrep >/dev/null 2>&1 && command -v pkill >/dev/null 2>&1; then
    if pgrep -x ironclaw > /dev/null 2>&1; then
        echo "Cleaning up existing ironclaw process..."
        if ! pkill -x ironclaw 2>/dev/null; then
            pkill -9 -x ironclaw || true
        fi
        sleep 2
    fi
fi

ENV_FILE="/data/.ironclaw/.env"
mkdir -p /data/.ironclaw /data/.ironclaw/logs /data/.npm-global /data/.npm-cache /data/.hermes

# npm setup
if command -v npm >/dev/null 2>&1; then
    npm config set prefix '/data/.npm-global'
    npm config set cache '/data/.npm-cache'
fi

if [ -x "/data/.linuxbrew/bin/brew" ]; then
    eval "$(/data/.linuxbrew/bin/brew shellenv)"
fi

# ─── Validate required env vars ──────────────────────────────────
if [ -z "${LLM_API_KEY:-}" ]; then
    echo "ERROR: LLM_API_KEY is not set in Railway Variables."
    exit 1
fi
if [ -z "${GATEWAY_AUTH_TOKEN:-}" ]; then
    echo "ERROR: GATEWAY_AUTH_TOKEN is not set in Railway Variables."
    exit 1
fi

# ─── Write IronClaw .env ─────────────────────────────────────────
echo "Writing IronClaw config..."
TMP_ENV="$(mktemp /tmp/ironclaw-env.XXXXXX)" || TMP_ENV="/tmp/ironclaw-env.$$"
cat > "$TMP_ENV" <<EOF
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
mv "$TMP_ENV" "$ENV_FILE"
chmod 600 "$ENV_FILE" || true
echo ".env written to $ENV_FILE."

# ─── Install default WASM extensions ─────────────────────────────
# Reinstalls whenever the ironclaw binary changes so bundled-registry
# updates (new tools, renamed manifests, WIT bumps) actually take effect
# after a redeploy. The previous behaviour skipped forever on first
# success, which silently kept stale/broken WASM around across binary
# upgrades.
TOOLS_DIR="/data/.ironclaw/tools"
MARKER="/data/.ironclaw/.install_marker"
CURRENT_BINARY_SHA=""
if command -v sha256sum >/dev/null 2>&1 && command -v ironclaw >/dev/null 2>&1; then
    CURRENT_BINARY_SHA=$(sha256sum "$(command -v ironclaw)" | awk '{print $1}')
fi
PREVIOUS_BINARY_SHA=""
[ -f "$MARKER" ] && PREVIOUS_BINARY_SHA=$(cat "$MARKER" 2>/dev/null || true)

NEEDS_INSTALL=0
if ! command -v ironclaw >/dev/null 2>&1; then
    echo "ironclaw binary not found in PATH; skipping default extension install."
elif [ ! -d "$TOOLS_DIR" ] || ! ls "$TOOLS_DIR"/*.wasm 1>/dev/null 2>&1; then
    NEEDS_INSTALL=1
elif [ -n "$CURRENT_BINARY_SHA" ] && [ "$CURRENT_BINARY_SHA" != "$PREVIOUS_BINARY_SHA" ]; then
    echo "ironclaw binary changed; reinstalling default extensions..."
    NEEDS_INSTALL=1
else
    echo "Extensions already installed for current ironclaw binary, skipping."
fi

if [ "$NEEDS_INSTALL" -eq 1 ]; then
    echo "Installing default extensions..."
    if ironclaw registry install-defaults --force 2>&1; then
        [ -n "$CURRENT_BINARY_SHA" ] && echo "$CURRENT_BINARY_SHA" > "$MARKER"
    else
        echo "Warning: Extension installation failed (non-fatal), continuing..."
    fi
fi

# ─── Start Hermes agent on port 8081 ─────────────────────────────
start_hermes() {
    echo "Starting Hermes agent gateway on port 8081..."
    export HOME=/data
    export HERMES_HOME=/data/.hermes
    export HERMES_DIR=/data/.hermes-src
    export HERMES_RUNNER=/data/.hermes-src/hermes_runner.py
    export PORT=8081

    # Install hermes if not already installed
    if [ ! -f "/data/.hermes-src/server.js" ]; then
        echo "Installing Hermes from GitHub..."
        mkdir -p /data/.hermes-src
        cd /data/.hermes-src
        git clone --depth=1 https://github.com/jmiller18899-lab/hermes-agent . 2>&1 || true
        npm install --omit=dev 2>&1 || true
        pip3 install -e "." --break-system-packages 2>&1 || true
        cd /data
    fi

    # Set OpenRouter or Anthropic key for Hermes
    if [ -n "${OPENROUTER_API_KEY:-}" ]; then
        export OPENROUTER_API_KEY="${OPENROUTER_API_KEY}"
    fi
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}"
    fi

    # Run Hermes in background with restart loop
    while true; do
        node /data/.hermes-src/server.js 2>&1 | sed 's/^/[hermes] /' || true
        echo "[hermes] Restarting in 5s..."
        sleep 5
    done
}

# Launch Hermes in background
start_hermes &
HERMES_PID=$!
echo "Hermes started (PID: $HERMES_PID) on port 8081"

# ─── Start IronClaw with restart loop ────────────────────────────
echo "Starting IronClaw gateway on port 8080..."
FAIL_COUNT=0
MAX_FAILS=${IRONCLAW_MAX_FAILURES:-10}

if ! command -v ironclaw >/dev/null 2>&1; then
    echo "ERROR: ironclaw executable not found in PATH."
    kill $HERMES_PID 2>/dev/null || true
    exit 1
fi

set +e

while true; do
    ironclaw run --no-onboard
    EXIT_CODE=$?
    set -e
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "IronClaw exited (code $EXIT_CODE, attempt $FAIL_COUNT/$MAX_FAILS). Restarting in ${IRONCLAW_RESTART_DELAY:-5}s..."
    if [ $FAIL_COUNT -ge $MAX_FAILS ]; then
        echo "Too many failures. Exiting."
        kill $HERMES_PID 2>/dev/null || true
        exit 1
    fi
    set +e
    sleep ${IRONCLAW_RESTART_DELAY:-5}
done
