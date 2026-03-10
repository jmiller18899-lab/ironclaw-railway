# Deploy and Host IronClaw on Railway

IronClaw is a high-performance AI agent runtime written in Rust by NEAR AI. It features built-in smart routing across 22+ LLM providers, MCP server support, a skills marketplace (ClawHub), 8 communication channels (Telegram, Discord, Slack, WhatsApp, Signal, HTTP, Web, REPL), and WASM-sandboxed tool execution. Perfect for deploying autonomous AI agents with minimal resource usage.

## About Hosting IronClaw

Deploying IronClaw on Railway involves downloading the pre-built binary and configuring via environment variables. Uses embedded libSQL (SQLite) by default — no external database needed. A persistent volume at `/data` ensures your configuration, skills, and sessions survive redeploys. Once deployed, access the container through Railway's web terminal to run initial setup, then IronClaw auto-starts on subsequent boots. The container exposes port 8080 for the web gateway and webhook integrations.

## Common Use Cases

- **Personal AI Assistant**: Deploy a private AI agent that responds 24/7 via Telegram, Discord, or Slack
- **Multi-Channel Bot**: Run a single agent across multiple platforms simultaneously
- **Automated Task Scheduler**: Run routines (cron, event-driven, webhook) with AI capabilities
- **Tool-Augmented Agent**: Extend capabilities via MCP servers, WASM tools, and ClawHub skills

## Dependencies for IronClaw Hosting

- **LLM Provider API Key**: OpenRouter, OpenAI, Anthropic, or any of 22+ supported providers
- **Telegram Bot Token** (optional): For Telegram integration, obtained from @BotFather
- **Composio API Key** (optional): For 1000+ OAuth tool integrations via MCP
- **PostgreSQL 15+** (optional): Only if you prefer Postgres over embedded libSQL

### Deployment Dependencies

- [IronClaw GitHub Repository](https://github.com/nearai/ironclaw)
- [Railway Documentation](https://docs.railway.app/)

### Implementation Details

The deployment uses a pre-built binary from GitHub releases:

```dockerfile
FROM debian:trixie-slim

# Install runtime dependencies + virtual desktop
RUN apt-get update && apt-get install -y \
    curl ca-certificates libssl3 nodejs npm \
    xvfb fluxbox x11vnc novnc websockify \
    && rm -rf /var/lib/apt/lists/*

# Download pre-built binary
ARG IRONCLAW_VERSION="v0.16.1"
RUN curl -fsSL "https://github.com/nearai/ironclaw/releases/download/${IRONCLAW_VERSION}/ironclaw-x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz -C /usr/local/bin ironclaw

ENV HOME=/data
EXPOSE 8080
```

Key implementation notes:

- `HOME=/data` redirects IronClaw's config directory from `~/.ironclaw` to `/data/.ironclaw`
- Persistent Railway volume mounted at `/data` preserves configuration
- Shell aliases (ic, ics, icm) added for faster CLI usage
- Container waits for `.env` file before starting on first boot
- Virtual desktop (Xvfb + noVNC) for browser automation on port 6080

## Why Deploy IronClaw on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying IronClaw on Railway, you get a production-ready AI agent with persistent storage, automatic restarts, and SSH terminal access for management — all without managing servers.
