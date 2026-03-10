# IronClaw Railway Template

IronClaw deployed on Railway with persistent storage and embedded SQLite (libSQL).

## Overview

This template deploys [IronClaw](https://github.com/nearai/ironclaw) - a high-performance AI agent runtime written in Rust by NEAR AI - to Railway with a persistent volume for configuration and data.

**IronClaw**: Smart routing, MCP servers, WASM tools, ClawHub skills, 8 channels, 22+ LLM providers.

## Features

- **Auto-starting agent**: Container automatically runs IronClaw on boot
- **Persistent storage**: Configuration, skills, sessions, and packages survive redeploys
- **Smart routing**: Built-in cost-optimization routing across primary and cheap models
- **22+ LLM providers**: OpenAI, Anthropic, Gemini, OpenRouter, Ollama, and more
- **8 communication channels**: Telegram, Discord, Slack, WhatsApp, Signal, HTTP, Web, REPL
- **MCP server support**: Add MCP servers at runtime with `ironclaw mcp add`
- **Skills marketplace**: Install skills from ClawHub or drop local `SKILL.md` files
- **WASM-sandboxed tools**: Secure tool execution in WebAssembly sandbox
- **Browser automation**: Headless Chromium via agent-browser + virtual desktop (noVNC)
- **SSH access**: Railway's terminal feature lets you run commands interactively
- **Package persistence**: NPM and Homebrew packages survive redeploys

## Deployment

### 1. Deploy to Railway

Click the button below to deploy:

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/template?referralCode=pNTW1S)

Or manually:
1. Fork this repo
2. Create new project in Railway
3. Connect your forked repo
4. Set environment variables (see below)
5. Deploy

No external database needed — uses embedded libSQL (SQLite) by default.

### 2. Initial Setup (via Railway Terminal)

Once deployed, open the Railway terminal and run:

```bash
# Run the interactive setup wizard
ironclaw onboard
```

Or manually create `/data/.ironclaw/.env`:

```bash
cat > /data/.ironclaw/.env << 'EOF'
DATABASE_BACKEND=libsql
LLM_BACKEND=openai
LLM_API_KEY=sk-...
LLM_MODEL=gpt-4o
GATEWAY_ENABLED=true
GATEWAY_HOST=0.0.0.0
GATEWAY_PORT=8080
GATEWAY_AUTH_TOKEN=your-secret-token
CLI_ENABLED=false
SANDBOX_ENABLED=false
HEARTBEAT_ENABLED=false
EMBEDDING_ENABLED=false
EOF
```

### 3. Add Channels (optional)

```bash
# Add Telegram bot token to .env
echo 'TELEGRAM_BOT_TOKEN=your-bot-token' >> /data/.ironclaw/.env
echo 'TELEGRAM_ALLOWED_USERS=your_username' >> /data/.ironclaw/.env
```

### 4. Restart

Restart the Railway service to pick up the new configuration.

## Usage

### Common Commands

```bash
# Run interactive setup
ironclaw onboard

# Chat with the agent
ironclaw agent -m "Hello, what can you do?"

# Interactive chat mode
ironclaw agent

# Add an MCP server
ironclaw mcp add github https://mcp.github.com

# Search and install skills
ironclaw skill search "code review"
ironclaw skill install code-review

# List installed tools and skills
ironclaw tool list
ironclaw skill list

# View logs
ironclaw logs
```

### Shell Aliases

```bash
ic      # ironclaw
ics     # ironclaw status
icrc    # nano /data/.ironclaw/.env
icm     # ironclaw mcp
```

## Data Persistence

All data is stored in `/data/` which is mounted as a persistent Railway volume:

| Path | Contents |
|------|----------|
| `/data/.ironclaw/.env` | Main configuration |
| `/data/.ironclaw/ironclaw.db` | Embedded libSQL database |
| `/data/.ironclaw/skills/` | Local skills (SKILL.md files) |
| `/data/.ironclaw/installed_skills/` | ClawHub-installed skills |
| `/data/.ironclaw/npm-packages.txt` | NPM packages to auto-install |
| `/data/.ironclaw/brew-packages.txt` | Homebrew packages to auto-install |
| `/data/.npm-global/` | Persisted npm global packages |
| `/data/.npm-cache/` | Persisted npm cache |
| `/data/.linuxbrew/` | Persisted Homebrew installation |

### NPM Packages Persistence

NPM packages installed globally survive redeploys:

**Method 1: Auto-install from list**
```bash
cat > /data/.ironclaw/npm-packages.txt << 'EOF'
# Add npm packages here, one per line
typescript
@angular/cli
EOF
```

**Method 2: Manual install (also persists)**
```bash
npm install -g <package-name>
```

### Homebrew Packages Persistence

```bash
cat > /data/.ironclaw/brew-packages.txt << 'EOF'
# Add Homebrew packages here, one per line
jq
htop
EOF
```

Or: `brew install <package-name>`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HOME` | `/data` | Sets home directory (`~/.ironclaw` = `/data/.ironclaw`) |
| `IRONCLAW_VERSION` | `v0.16.1` | Release version to install (build arg) |
| `DATABASE_BACKEND` | `libsql` | Database backend (`libsql` or `postgres`) |
| `COMPOSIO_API_KEY` | — | (Optional) Composio API key for MCP integrations |
| `LLM_BACKEND` | — | LLM provider (openai, anthropic, openrouter, etc.) |
| `LLM_API_KEY` | — | Provider API key |
| `LLM_MODEL` | — | Default model identifier |
| `GATEWAY_ENABLED` | `true` | Enable web gateway |
| `GATEWAY_HOST` | `0.0.0.0` | Gateway bind address |
| `GATEWAY_PORT` | `8080` | Gateway port |

See [config.md](config.md) for the full configuration reference.

## Local Testing

```bash
# Build the image
docker build -t railway-ironclaw .

# Run locally (no external database needed)
docker run --rm -it \
  -p 8080:8080 \
  -v $(pwd)/.tmpdata:/data \
  railway-ironclaw

# In another terminal, exec into container
docker exec -it <container-id> /bin/bash
ironclaw onboard
```

## Architecture

IronClaw uses a **multi-layered extensibility architecture**:

| Layer | Mechanism | Examples |
|-------|-----------|---------|
| **Skills** (prompt-level) | `SKILL.md` files with activation scoring | ClawHub marketplace, local skills |
| **Tools** (code-level) | WASM modules (sandboxed) or MCP servers | GitHub, Gmail, Slack, 1000+ via MCP |
| **Routines** (automation) | Cron, event, webhook triggers | Scheduled tasks, event-driven workflows |
| **Channels** (I/O) | WASM plugins + built-in | Telegram, Discord, Slack, WhatsApp, Signal |

### Smart Routing

Built-in cost-optimization routing between primary and cheap models:
- 13-dimension scoring (reasoning, code patterns, complexity, safety, etc.)
- 4 tiers: Flash (simple) → Standard → Pro → Frontier (complex)
- Cascade mode: tries cheap model first, escalates if needed
- Tool use always routes to primary model

### Supported LLM Providers (22+)

OpenAI, Anthropic, Google Gemini, Mistral, DeepSeek, Groq, NVIDIA NIM, OpenRouter, Together AI, Fireworks AI, Ollama, Cerebras, SambaNova, Cloudflare Workers AI, NEAR AI, and any OpenAI-compatible endpoint.

## Getting API Keys

### OpenRouter (recommended — access to all models)
1. Visit [openrouter.ai](https://openrouter.ai)
2. Create account and get API key
3. Supports Claude, GPT-4, Gemini, and more

### Telegram Bot
1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Run `/newbot` and follow prompts
3. Copy the token

### Discord Bot
1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. New Application → Bot → Add Bot
3. Enable MESSAGE CONTENT INTENT
4. Copy Bot Token
5. Invite bot to your server

See [IronClaw documentation](https://github.com/nearai/ironclaw) for more channels.

## Troubleshooting

**Not starting?**
```bash
ps aux | grep ironclaw
cat /data/.ironclaw/.env
ironclaw logs
```

**Config not persisting?**
- Ensure volume is mounted at `/data`
- Check `HOME` env var is set to `/data`

**Database issues?**
- Default: embedded libSQL at `/data/.ironclaw/ironclaw.db` (no external DB needed)
- For Postgres: set `DATABASE_BACKEND=postgres` and `DATABASE_URL=postgres://...`

**Composio not working?**
- Ensure `COMPOSIO_API_KEY` env var is set
- Check `ironclaw mcp list` shows composio registered
- Composio MCP is a hosted service — requires outbound HTTPS to `backend.composio.dev`

**Channel issues?**
```bash
ironclaw channel doctor
```

## Links & Resources

- **GitHub**: https://github.com/nearai/ironclaw
- **NEAR AI**: https://near.ai
- **Releases**: https://github.com/nearai/ironclaw/releases

## License

IronClaw is licensed under [Apache 2.0](https://github.com/nearai/ironclaw/blob/main/LICENSE).

---

**IronClaw** — Smart routing. MCP servers. WASM tools. 22+ providers. Deploy anywhere.
