#!/bin/bash
set -e

# ══════════════════════════════════════════════════════════════════
# IronClaw Railway Template — start.sh (NullClaw Edition)
# Automatically writes .env from Railway env vars and starts IronClaw
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
    # Fallback to simple lockfile with PID check
    if [ -f "$LOCKFILE" ]; then
        EXISTING_PID=$(cat "$LOCKFILE" 2>/dev/null || true)
        if printf '%s\n' "$EXISTING_PID" | grep -Eq '^[0-9]+$'; then
            if [ "$EXISTING_PID" != "$$" ] && [ "$EXISTING_PID" != "1" ]; then
                if kill -0 "$EXISTING_PID" 2>/dev/null; then
                    echo "start.sh already running (PID: $EXISTING_PID). Exiting."
                    exit 0
                else
                    # Stale lockfile, remove it
                    rm -f "$LOCKFILE"
                fi
            fi
        else
            # Non-numeric or empty lockfile, remove it
            rm -f "$LOCKFILE"
        fi
    fi
    echo $$ > "$LOCKFILE"
    trap "rm -f $LOCKFILE" EXIT
fi

# Kill any stale ironclaw process (if pgrep/pkill available)
if command -v pgrep >/dev/null 2>&1 && command -v pkill >/dev/null 2>&1; then
    if pgrep -x ironclaw > /dev/null 2>&1; then
        echo "Cleaning up existing ironclaw process..."
        if ! pkill -x ironclaw 2>/dev/null; then
            echo "Warning: Could not gracefully stop ironclaw, forcing kill..."
            pkill -9 -x ironclaw || true
        fi
        sleep 2
    fi
else
    echo "Note: pgrep/pkill not found; skipping stale ironclaw cleanup."
fi

ENV_FILE="/data/.ironclaw/.env"
mkdir -p /data/.ironclaw /data/.ironclaw/logs /data/.npm-global /data/.npm-cache

# npm + Homebrew setup (only if npm present)
if command -v npm >/dev/null 2>&1; then
    npm config set prefix '/data/.npm-global'
    npm config set cache '/data/.npm-cache'
else
    echo "Warning: npm not found; skipping npm config."
fi

if [ -x "/data/.linuxbrew/bin/brew" ]; then
    eval "$(/data/.linuxbrew/bin/brew shellenv)"
else
    echo "Warning: Homebrew not found, continuing without it..."
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

# ─── Normalize LLM_MODEL to "provider/model" format ─────────────
# IronClaw requires "provider/model" format. Auto-prefix the provider
# when LLM_MODEL is a bare model name (no slash).
RAW_MODEL="${LLM_MODEL:-claude-sonnet-4-20250514}"
case "$RAW_MODEL" in
    */*) RESOLVED_MODEL="$RAW_MODEL" ;;  # already has provider/ prefix
    gemini-*)    RESOLVED_MODEL="gemini/$RAW_MODEL" ;;
    gpt-*|o1-*|o3-*|o4-*|chatgpt-*) RESOLVED_MODEL="openai/$RAW_MODEL" ;;
    claude-*)    RESOLVED_MODEL="anthropic/$RAW_MODEL" ;;
    deepseek-*)  RESOLVED_MODEL="deepseek/$RAW_MODEL" ;;
    mistral-*|codestral-*|pixtral-*) RESOLVED_MODEL="mistral/$RAW_MODEL" ;;
    llama-*|meta-llama*) RESOLVED_MODEL="openrouter/meta-llama/$RAW_MODEL" ;;
    *)           RESOLVED_MODEL="openrouter/$RAW_MODEL" ;;
esac
# Extract detected provider from resolved model (first path component)
# Validate it's a known LLM_BACKEND value; fall back to openrouter for
# org/model style paths (e.g. meta-llama/llama-3.1-70b) that aren't backends.
DETECTED_PROVIDER="${RESOLVED_MODEL%%/*}"
case "$DETECTED_PROVIDER" in
    openai|anthropic|gemini|openrouter|mistral|deepseek|groq|ollama|together|fireworks|cerebras|sambanova|nvidia|cloudflare|nearai)
        ;; # valid backend, keep it
    *)
        DETECTED_PROVIDER="openrouter" ;;
esac
echo "Resolved model: $RESOLVED_MODEL (raw: $RAW_MODEL, detected provider: $DETECTED_PROVIDER)"

# ─── Write .env from Railway env vars (atomic) ───────────────────
echo "Writing IronClaw config..."
TMP_ENV="$(mktemp /tmp/ironclaw-env.XXXXXX)" || TMP_ENV="/tmp/ironclaw-env.$$"
cat > "$TMP_ENV" <<EOF
DATABASE_BACKEND=${DATABASE_BACKEND:-libsql}
LLM_BACKEND=${LLM_BACKEND:-$DETECTED_PROVIDER}
LLM_API_KEY=${LLM_API_KEY}
LLM_MODEL=${RESOLVED_MODEL}
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

# ─── Install default WASM extensions (once) ──────────────────────
TOOLS_DIR="/data/.ironclaw/tools"
if command -v ironclaw >/dev/null 2>&1; then
    if [ -d "$TOOLS_DIR" ] && ls "$TOOLS_DIR"/*.wasm 1>/dev/null 2>&1; then
        echo "Extensions already installed, skipping."
    else
        echo "Installing default extensions..."
        if ! ironclaw registry install-defaults --force 2>&1; then
            echo "Warning: Extension installation failed (non-fatal), continuing..."
        fi
    fi
else
    echo "Warning: ironclaw binary not found; skipping extension installation and start. Deploy will fail unless ironclaw is provided."
fi

# ─── Start IronClaw with restart loop ────────────────────────────
echo "Starting IronClaw gateway on port 8080..."
FAIL_COUNT=0
MAX_FAILS=${IRONCLAW_MAX_FAILURES:-10}

if ! command -v ironclaw >/dev/null 2>&1; then
    echo "ERROR: ironclaw executable not found in PATH. Ensure it's installed and available."
    exit 1
fi

# Disable exit-on-error so the restart loop can catch ironclaw failures
set +e

while true; do
    ironclaw run --no-onboard
    EXIT_CODE=$?
    set -e
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "IronClaw exited (code $EXIT_CODE, attempt $FAIL_COUNT/$MAX_FAILS). Restarting in ${IRONCLAW_RESTART_DELAY:-5}s..."
    if [ $FAIL_COUNT -ge $MAX_FAILS ]; then
        echo "Too many failures. Exiting."
        exit 1
    fi
    set +e
    sleep ${IRONCLAW_RESTART_DELAY:-5}
done
