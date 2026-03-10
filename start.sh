#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════════════
# IronClaw Railway Template — start.sh
# Supports two modes:
#   1. Managed (CLAWLAUNCHER_MODE=managed): renders .env from templates,
#      runs ironclaw with periodic tenant validation
#   2. Interactive (default): waits for manual onboard, then runs ironclaw
# ═══════════════════════════════════════════════════════════════════

# ─── Guard: prevent double execution ─────────────────────────────
LOCKFILE="/tmp/start.sh.lock"
if [ -f "$LOCKFILE" ]; then
    EXISTING_PID=$(cat "$LOCKFILE" 2>/dev/null)
    if [ -n "$EXISTING_PID" ] && [ "$EXISTING_PID" != "$$" ] && [ "$EXISTING_PID" != "1" ] && kill -0 "$EXISTING_PID" 2>/dev/null; then
        echo "start.sh is already running (PID: $EXISTING_PID). Exiting duplicate."
        exit 0
    fi
fi
echo $$ > "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

# Kill any stale ironclaw process from a previous run (persistent volume may survive redeploys)
if pgrep -x ironclaw > /dev/null 2>&1; then
    echo "WARNING: Found stale ironclaw process(es). Killing before fresh start."
    pkill -x ironclaw || true
    sleep 1
fi

ENV_FILE="/data/.ironclaw/.env"
TEMPLATE_DIR="/app/templates"
IRONCLAW_PID=""

# ─── Virtual desktop (Xvfb + Fluxbox + x11vnc + noVNC) ──────────
start_virtual_desktop() {
    echo "Starting virtual desktop..."

    # Start Xvfb (virtual framebuffer)
    Xvfb :99 -screen 0 "${SCREEN_WIDTH:-1366}x${SCREEN_HEIGHT:-768}x${SCREEN_DEPTH:-24}" -ac +extension GLX +render -noreset &
    sleep 1

    # Start Fluxbox window manager
    fluxbox &
    sleep 0.5

    # Start x11vnc (VNC server on display :99)
    x11vnc -display :99 -nopw -listen 0.0.0.0 -rfbport 5900 -shared -forever -noxdamage &
    sleep 0.5

    # Start noVNC (web-based VNC viewer on port 6080)
    NOVNC_PATH=$(find /usr -path "*/novnc/utils/novnc_proxy" 2>/dev/null | head -1)
    if [ -z "$NOVNC_PATH" ]; then
        NOVNC_PATH=$(find /usr -path "*/novnc/utils/launch.sh" 2>/dev/null | head -1)
    fi
    if [ -n "$NOVNC_PATH" ]; then
        "$NOVNC_PATH" --vnc localhost:5900 --listen 6080 &
    else
        websockify --web /usr/share/novnc 6080 localhost:5900 &
    fi

    echo "  Virtual desktop started (DISPLAY=:99)"
    echo "  noVNC viewer: http://0.0.0.0:6080/vnc.html"
}

# Start virtual desktop if Xvfb is available
if command -v Xvfb >/dev/null 2>&1; then
    start_virtual_desktop
fi

# ─── Config rendering: envsubst ──────────────────────────────────

render_env() {
    echo "Rendering .env from template..."
    envsubst < "${TEMPLATE_DIR}/env.tmpl" > "$ENV_FILE"
    echo ".env rendered at $ENV_FILE"
}

# ─── Generate Managed Config ─────────────────────────────────────

generate_managed_config() {
    # Validate required env vars
    local required_vars="LLM_API_KEY LLM_MODEL BOT_TOKEN TELEGRAM_USERNAME"
    for var in $required_vars; do
        if [ -z "${!var}" ]; then
            echo "ERROR: Required env var $var is not set. Cannot start managed bot."
            exit 1
        fi
    done

    # Render .env from template
    render_env
}

# ─── Start Managed (ironclaw + sidecars) ─────────────────────────

start_managed() {
    echo "Starting managed bot..."

    # Start IronClaw (with pre-flight check for unexpected auto-start)
    if pgrep -x ironclaw > /dev/null 2>&1; then
        echo "WARNING: ironclaw process already running before explicit start. Killing it."
        pkill -x ironclaw || true
        sleep 1
    fi
    echo "Starting IronClaw..."
    ironclaw &
    IRONCLAW_PID=$!
    echo "IronClaw started (PID: $IRONCLAW_PID)"

    # Trap to clean up on exit
    trap "kill $IRONCLAW_PID 2>/dev/null; exit" EXIT TERM INT

    # Wait for process — if it dies, cleanup happens via trap
    wait $IRONCLAW_PID
    local exit_code=$?
    echo "IronClaw exited with code $exit_code."
    exit $exit_code
}

# ═══════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════

# ─── Shared Setup ─────────────────────────────────────────────────

mkdir -p /data/.ironclaw /data/.ironclaw/logs /data/.npm-global /data/.npm-cache

# npm persistent storage
npm config set prefix '/data/.npm-global'
npm config set cache '/data/.npm-cache'

# Install npm packages from persistent list (if exists)
NPM_PACKAGES_FILE="/data/.ironclaw/npm-packages.txt"
if [ -f "$NPM_PACKAGES_FILE" ]; then
    echo "Installing npm packages from $NPM_PACKAGES_FILE..."
    while IFS= read -r package || [[ -n "$package" ]]; do
        [[ -z "$package" || "$package" =~ ^# ]] && continue
        if ! npm list -g "$package" &>/dev/null; then
            echo "Installing $package..."
            npm install -g "$package"
        else
            echo "$package is already installed"
        fi
    done < "$NPM_PACKAGES_FILE"
fi

# Homebrew: pre-installed in Docker image, just activate shellenv
eval "$(/data/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true

# Install Homebrew packages from persistent list (if exists)
HOMEBREW_PACKAGES_FILE="/data/.ironclaw/brew-packages.txt"
if [ -f "$HOMEBREW_PACKAGES_FILE" ]; then
    echo "Installing Homebrew packages from $HOMEBREW_PACKAGES_FILE..."
    while IFS= read -r package || [[ -n "$package" ]]; do
        [[ -z "$package" || "$package" =~ ^# ]] && continue
        if ! brew list "$package" &>/dev/null; then
            echo "Installing $package..."
            brew install "$package"
        else
            echo "$package is already installed"
        fi
    done < "$HOMEBREW_PACKAGES_FILE"
fi

# ─── Composio MCP (optional) ─────────────────────────────────────

provision_composio() {
    if [ -z "$COMPOSIO_API_KEY" ]; then
        return
    fi

    echo "Provisioning Composio MCP server..."

    # Install the composio MCP bridge if not present
    if ! command -v composio-mcp >/dev/null 2>&1 && ! npm list -g @composio/mcp &>/dev/null; then
        echo "  Installing @composio/mcp..."
        npm install -g @composio/mcp
    fi

    # Register Composio as an MCP server in IronClaw (stdio transport via npx bridge)
    # This survives restarts because ironclaw stores MCP config in persistent /data/.ironclaw/
    local MCP_CONFIG_DIR="/data/.ironclaw/mcp"
    mkdir -p "$MCP_CONFIG_DIR"

    # Only register if not already configured
    if ! ironclaw mcp list 2>/dev/null | grep -q composio; then
        echo "  Registering Composio MCP with IronClaw..."
        ironclaw mcp add composio --transport stdio --command "npx" --args "@composio/mcp" 2>/dev/null || {
            echo "  WARNING: Could not register Composio MCP via CLI. Will be available for manual setup."
        }
    fi

    echo "  Composio MCP provisioned (API key set via COMPOSIO_API_KEY env var)"
}

# ─── Mode Selection ──────────────────────────────────────────────

if [ "$CLAWLAUNCHER_MODE" = "managed" ]; then
    echo "=== 1claw.network Managed Mode ==="

    # Generate config from templates
    generate_managed_config

    # Provision optional integrations
    provision_composio

    # Start ironclaw (does not return)
    start_managed
else
    # Interactive mode (original behavior)
    if [ ! -f "$ENV_FILE" ]; then
        echo "=========================================="
        echo "IronClaw is not configured yet!"
        echo ""
        echo "To get started:"
        echo "1. Open Railway terminal for this service"
        echo "2. Run: ironclaw onboard"
        echo ""
        echo "   Or manually create /data/.ironclaw/.env with:"
        echo "   DATABASE_URL=postgres://..."
        echo "   LLM_BACKEND=openai"
        echo "   LLM_API_KEY=sk-..."
        echo "   GATEWAY_ENABLED=true"
        echo "   GATEWAY_HOST=0.0.0.0"
        echo "   GATEWAY_PORT=8080"
        echo ""
        echo "3. Restart the container after configuration"
        echo "=========================================="
        echo ""
        echo "Container is running but waiting for config..."
        echo "(Keep this running so you can access the terminal)"

        while [ ! -f "$ENV_FILE" ]; do
            sleep 5
        done

        echo "Config detected! Starting IronClaw..."
    fi

    # Provision optional integrations
    provision_composio

    echo "Starting IronClaw..."
    exec ironclaw
fi
