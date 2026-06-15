# Configuration Guide

Complete reference for all HolyClaude configuration options.

---

## Docker Compose Files

HolyClaude ships with two compose files:

| File | Purpose | Usage |
|------|---------|-------|
| `docker-compose.yaml` | Quick start — minimal config, just works | `docker compose up -d` |
| `docker-compose.full.yaml` | All options — ports, API keys, polling, notifications | `docker compose -f docker-compose.full.yaml up -d` |

---

## Environment Variables

Docker Compose also supports a local `.env` file for variable interpolation. HolyClaude uses that in `docker-compose.full.yaml` for host-side port and bind-mount paths. These values are read by Compose on the host and are not passed into the container unless you also list them under `environment:`.

### Compose-Level Host Mappings

| Variable | Default | Description |
|----------|---------|-------------|
| `HOLYCLAUDE_HOST_PORT` | `3001` | Localhost port mapped to container port `3001` |
| `HOLYCLAUDE_HOST_CLAUDE_DIR` | `./data/claude` | Host path bind-mounted to `/home/claude/.claude` |
| `HOLYCLAUDE_HOST_WORKSPACE_DIR` | `./workspace` | Host path bind-mounted to `/workspace` |

### Core

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `UTC` | Container timezone ([list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)) |
| `PUID` | `1000` | User ID — match your host user's UID (`id -u`) |
| `PGID` | `1000` | Group ID — match your host user's GID (`id -g`) |

### Performance

| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_OPTIONS` | `--max-old-space-size=4096` | Node.js heap memory limit in MB |

### Git Identity

Set during first-boot bootstrap. To change after first boot, run `git config --global` inside the container.

| Variable | Default | Description |
|----------|---------|-------------|
| `GIT_USER_NAME` | `HolyClaude User` | Git commit author name |
| `GIT_USER_EMAIL` | `noreply@holyclaude.local` | Git commit author email |

### SMB/CIFS Network Mounts

Only needed if your volumes are on a network share (Samba, NAS, etc.):

| Variable | Default | Description |
|----------|---------|-------------|
| `CHOKIDAR_USEPOLLING` | (unset) | Set to `1` — enables polling for file watchers |
| `WATCHFILES_FORCE_POLLING` | (unset) | Set to `true` — enables polling for Python watchers |

### Notifications (Apprise)

HolyClaude uses [Apprise](https://github.com/caronc/apprise) for notifications, supporting 100+ services including Discord, Telegram, Slack, Email, Pushover, Gotify, and more.

Claude Code hooks, raw CLI hooks for Codex and Gemini CLI, and CloudCLI Codex chat completion/failure events use this same Apprise setup. Permission prompts are not sent through Apprise.

| Variable | Default | Description |
|----------|---------|-------------|
| `NOTIFY_DISCORD` | *(unset)* | Discord webhook — `discord://webhook_id/webhook_token` |
| `NOTIFY_TELEGRAM` | *(unset)* | Telegram bot — `tg://bot_token/chat_id` |
| `NOTIFY_PUSHOVER` | *(unset)* | Pushover — `pover://user_key@app_token` |
| `NOTIFY_SLACK` | *(unset)* | Slack webhook — `slack://token_a/token_b/token_c` |
| `NOTIFY_EMAIL` | *(unset)* | Email (SMTP) — `mailto://user:pass@gmail.com?to=you@gmail.com` |
| `NOTIFY_GOTIFY` | *(unset)* | Gotify — `gotify://hostname/token` |
| `NOTIFY_URLS` | *(unset)* | Catch-all — comma-separated [Apprise URLs](https://github.com/caronc/apprise/wiki) |

Notifications also require the flag file `~/.claude/notify-on` to exist inside the container. Create it with `touch ~/.claude/notify-on`.

**Migrating from Pushover (v1.0.0):** Replace `PUSHOVER_APP_TOKEN` and `PUSHOVER_USER_KEY` with a single variable: `NOTIFY_PUSHOVER=pover://user_key@app_token`

### AI Provider API Keys

Claude Code can authenticate via web UI (OAuth) or `ANTHROPIC_API_KEY`. Other AI CLI keys can also be set through the web UI.

| Variable | Default | Description |
|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | (unset) | Anthropic API key (alternative to web UI OAuth) |
| `ANTHROPIC_AUTH_TOKEN` | (unset) | Anthropic auth token (alternative to API key). For Ollama, set this to `ollama` |
| `ANTHROPIC_BASE_URL` | (unset) | Custom Anthropic API endpoint (proxies, private deployments, or Ollama's Anthropic-compatible API) |
| `CLAUDE_CODE_USE_BEDROCK` | (unset) | Set to `1` to use Amazon Bedrock backend |
| `CLAUDE_CODE_USE_VERTEX` | (unset) | Set to `1` to use Google Vertex AI backend |
| `GEMINI_API_KEY` | (unset) | Google Gemini API key |
| `OPENAI_API_KEY` | (unset) | OpenAI API key |
| `CURSOR_API_KEY` | (unset) | Cursor API key |

OpenCode is configured from the full image with the `opencode` TUI. Use that path for [OpenRouter](https://openrouter.ai/docs/cookbook/coding-agents/opencode-integration) and other [OpenCode-supported providers](https://opencode.ai/docs/providers/). Free model availability depends on OpenRouter and provider account limits; HolyClaude does not proxy requests or guarantee zero-cost usage.

### Codex Permission Modes

HolyClaude provides configurable near-parity permission modes for Codex. These settings are intentionally split because CloudCLI Codex chat and the raw `codex` CLI read configuration through different paths.

| Variable | Default | Valid values | Applies to | Behavior |
|----------|---------|--------------|------------|----------|
| `HOLYCLAUDE_CODEX_CHAT_PERMISSION_MODE` | `acceptEdits` | `default`, `acceptEdits`, `bypassPermissions` | CloudCLI Codex chat | Runtime container config read by the CloudCLI Codex provider. Recreate the container after changing it. |
| `HOLYCLAUDE_CODEX_CLI_PERMISSION_MODE` | `default` | `default`, `acceptEdits`, `bypassPermissions` | Raw `codex` CLI | First-boot-only seed for new `~/.codex/config.toml`. Existing configs are not overwritten, and the generated value persists until you edit the file. |

`acceptEdits` is the recommended value for both settings. `bypassPermissions` gives Codex full access with no approval. Docker still limits access to the container and mounted volumes, but anything reachable through `/workspace`, `/home/claude`, and other mounts can be read or changed. Use bypass only for trusted local workspaces.

---

## Desloppify Setup

Desloppify is installed in both image variants as the `desloppify` command. It is passive by default. HolyClaude does not run scans, create `.desloppify/`, edit `.gitignore`, or touch mounted project files unless you run Desloppify yourself.

| Variable | Default | Valid values | Behavior |
|----------|---------|--------------|----------|
| `HOLYCLAUDE_DESLOPPIFY_SETUP` | `off` | `off`, `all`, `claude`, `codex`, `gemini`, `opencode`, comma-separated subsets | Optional global Desloppify skill setup at container start. `off` disables setup only; the CLI stays installed. |

Normal project usage stays manual:

```bash
desloppify scan --path .
desloppify next
```

After scanning a project, add `.desloppify/` to that project's `.gitignore`.

`all` expands to `claude,codex,gemini`. OpenCode is full-image only and must be requested as `opencode`. Do not combine `claude` and `opencode` in automatic setup because OpenCode can discover Claude-compatible skills from `~/.claude/skills`; HolyClaude warns and skips `opencode` in that case. If `OPENCODE_CONFIG_DIR` is set, HolyClaude also warns and skips automatic OpenCode setup because Desloppify writes to the standard `~/.config/opencode` path.

Manual upstream-supported setup targets are available through Desloppify itself: `cursor`, `copilot`, `windsurf`, `qwen`, `amp`, `rovodev`, `droid`, and `hermes`.

---

## Volumes

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| `./data/claude` | `/home/claude/.claude` | Settings, credentials, memory, API tokens |
| `./workspace` | `/workspace` | Your code and projects |

### What's inside `./data/claude`:

| File/Dir | Purpose |
|----------|---------|
| `settings.json` | Claude Code settings (permissions, hooks, model) |
| `CLAUDE.md` | Claude's global memory — customize with your preferences |
| `.credentials.json` | Anthropic API authentication (auto-created) |
| `.codex/config.toml` | Raw Codex CLI config, created on first boot if missing |
| `.holyclaude-bootstrapped` | Sentinel file — delete to re-run first-boot setup |

---

## Ports

| Port | Service | Default State |
|------|---------|--------------|
| `127.0.0.1:3001` | CloudCLI web UI | Exposed on the Docker host only |
| `3000` | Dev server (Next.js, Express) | Commented out |
| `4321` | Astro dev server | Commented out |
| `5173` | Vite dev server | Commented out |
| `8787` | Wrangler dev server | Commented out |
| `9229` | Node.js debugger | Commented out |
| `1455` | Codex auth callback | Commented out |

Uncomment additional ports in `docker-compose.full.yaml` as needed. Keep them bound to `127.0.0.1` unless you have a private tunnel or access proxy in front of them. If you use Codex's callback flow from your host browser, also uncomment `127.0.0.1:1455:1455`.

---

## Docker Capabilities

HolyClaude requires these Docker capabilities for Chromium to work:

```yaml
cap_add:
  - SYS_ADMIN      # Chromium sandboxing (namespaces)
  - SYS_PTRACE      # Debugging (strace, lsof)
security_opt:
  - seccomp=unconfined  # Chromium syscall requirements
```

These are common for Chromium-in-Docker setups. Without them, Chromium may crash on startup. They also reduce container isolation, so avoid publishing the web UI directly to a public interface.

---

## Shared Memory

```yaml
shm_size: 2g
```

Chromium uses `/dev/shm` for shared memory. Docker defaults to 64MB, which causes tab crashes. 2GB is recommended for general use. Increase if running many concurrent browser tabs.

---

## Claude Code Settings

The default `settings.json` at `~/.claude/settings.json`:

```json
{
  "permissions": {
    "defaultMode": "acceptEdits"
  },
  "env": {
    "DISABLE_AUTOUPDATER": "1"
  },
  "model": "sonnet"
}
```

### Permission Modes

| Mode | File edits | Shell commands | Use case |
|------|-----------|----------------|----------|
| `askUser` | Asks | Asks | Maximum safety |
| `acceptEdits` | Allowed | Depends on Claude Code's current prompt behavior | **Default** — shipped setting |
| `bypassPermissions` | Allowed | Allowed | Power users only |

### Changing the Model

Edit `settings.json` and change `"model"`:
- `"sonnet"` — Claude Sonnet (default, fast)
- `"opus"` — Claude Opus (most capable)
- `"haiku"` — Claude Haiku (fastest, cheapest)

---

## Customizing Claude's Memory

Edit `~/.claude/CLAUDE.md` (or `./data/claude/CLAUDE.md` on the host) to customize Claude's behavior:

```markdown
# My Preferences
- Use TypeScript for all new files
- Default to pnpm, not npm
- Direct communication, no fluff
- Always run tests after changes
```

This file is read by Claude at the start of every conversation.

---

## Re-triggering First-Boot Setup

If you need to re-run the bootstrap (e.g., after updating the image):

```bash
# Delete the sentinel file — NOT the entire directory
rm ./data/claude/.holyclaude-bootstrapped

# Restart the container
docker compose restart holyclaude
```

**Warning:** Do NOT delete `./data/claude/` entirely — this wipes your credentials and you'll need to re-authenticate.
