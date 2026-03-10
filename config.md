# IronClaw Config Reference

All configuration is done via environment variables in `~/.ironclaw/.env`. Based on upstream v0.16.1.

| Variable | Description | In template? | Notes |
|----------|-------------|:---:|-------|
| `DATABASE_BACKEND` | Database backend | yes | `libsql` (embedded SQLite) or `postgres` |
| `DATABASE_URL` | PostgreSQL connection string | no | Only needed if `DATABASE_BACKEND=postgres` |
| `COMPOSIO_API_KEY` | Composio API key | no | Optional — auto-provisions MCP integration |
| `LLM_BACKEND` | LLM provider (openai, anthropic, nearai, etc.) | yes | 22+ providers supported |
| `LLM_API_KEY` | Provider API key | yes | |
| `LLM_MODEL` | Default model identifier | yes | |
| `LLM_BASE_URL` | OpenAI-compatible endpoint URL | yes | For custom endpoints |
| `AGENT_NAME` | Agent name | yes | `ironclaw` |
| `CLI_ENABLED` | Enable REPL CLI | yes | `false` for managed |
| `GATEWAY_ENABLED` | Enable web gateway | yes | `true` |
| `GATEWAY_HOST` | Gateway bind address | yes | `0.0.0.0` for Railway |
| `GATEWAY_PORT` | Gateway port | yes | `8080` |
| `GATEWAY_AUTH_TOKEN` | Bearer token for gateway API | yes | |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | yes | From @BotFather |
| `TELEGRAM_ALLOWED_USERS` | Telegram username allowlist | yes | |
| `SANDBOX_ENABLED` | Docker sandbox for code execution | yes | `false` |
| `HEARTBEAT_ENABLED` | Health pings | yes | |
| `EMBEDDING_ENABLED` | Vector embeddings | yes | `false` |
| `EMBEDDING_PROVIDER` | Embedding provider (openai, ollama, nearai) | no | Default: openai |
| `RUST_LOG` | Log level | no | `ironclaw=info` |
| `IRONCLAW_IN_DOCKER` | Docker restart loop | yes | `true` |
| `IRONCLAW_RESTART_DELAY` | Restart delay seconds | yes | `5` |
| `IRONCLAW_MAX_FAILURES` | Max consecutive failures | yes | `10` |

## Supported LLM Providers

IronClaw supports 22+ providers out of the box. Set `LLM_BACKEND` and the corresponding API key:

| Provider | LLM_BACKEND | Key Variable |
|----------|-------------|-------------|
| OpenAI | `openai` | `LLM_API_KEY` |
| Anthropic | `anthropic` | `LLM_API_KEY` |
| Google Gemini | `gemini` | `LLM_API_KEY` |
| NEAR AI | `nearai` | `NEARAI_API_KEY` |
| OpenRouter | `openrouter` | `LLM_API_KEY` |
| Mistral | `mistral` | `LLM_API_KEY` |
| DeepSeek | `deepseek` | `LLM_API_KEY` |
| Groq | `groq` | `LLM_API_KEY` |
| Ollama | `ollama` | (none) |
| Together AI | `together` | `LLM_API_KEY` |
| Fireworks AI | `fireworks` | `LLM_API_KEY` |
| Cerebras | `cerebras` | `LLM_API_KEY` |
| SambaNova | `sambanova` | `LLM_API_KEY` |
| NVIDIA NIM | `nvidia` | `LLM_API_KEY` |
| Cloudflare | `cloudflare` | `LLM_API_KEY` |

## Smart Routing

IronClaw has built-in smart routing (`smart_routing.rs`) that automatically routes requests between a primary (capable) model and a cheap (fast) model based on a 13-dimension scoring system. No configuration needed — it activates when both a primary and cheap model are configured.

## MCP Servers

Add MCP servers at runtime (no restart needed):

```bash
ironclaw mcp add <name> <url>                    # HTTP transport
ironclaw mcp add <name> --transport stdio --command <cmd>  # stdio transport
```

## Skills

Install skills from ClawHub marketplace:

```bash
ironclaw skill search <query>
ironclaw skill install <name>
ironclaw skill list
ironclaw skill remove <name>
```

Or drop a `SKILL.md` file into `~/.ironclaw/skills/` for local skills.
