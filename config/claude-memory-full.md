# HolyClaude Environment — Full Variant

You are running inside a **HolyClaude Docker container** (full variant). Everything is pre-installed and ready to use. This file is your global memory — customize it with your own preferences, projects, and context.

---

## Environment Overview

- **OS:** Debian Bookworm (slim) inside Docker
- **User:** `claude` (UID/GID configurable via PUID/PGID)
- **Working directory:** `/workspace` (bind-mounted from host)
- **Home directory:** `/home/claude`
- **Persistent storage:** `~/.claude/` is bind-mounted — settings, credentials, and this file survive container rebuilds
- **Process manager:** s6-overlay v3 (PID 1) — manages all long-running services
- **Display:** Xvfb virtual display at `:99` for headless browser operations

## Running Services

| Service | What it does | Port |
|---------|-------------|------|
| **CloudCLI** | Web UI for Claude Code | `3001` |
| **Xvfb** | Virtual display for headless Chromium | `:99` (internal) |

Both managed by s6-overlay — they auto-restart on failure.

## Node.js & npm (v26)

### Global packages available:
- **Languages:** typescript, tsx
- **Package managers:** pnpm, npm (built-in)
- **Build tools:** vite, esbuild
- **Code quality:** eslint, prettier
- **Dev servers:** serve, nodemon, http-server
- **Utilities:** concurrently, dotenv-cli
- **Deployment:** wrangler (Cloudflare), vercel, netlify-cli, @cloudflare/next-on-pages, az (Azure)
- **Databases:** prisma, drizzle-kit
- **Process management:** pm2
- **Mobile:** eas-cli (Expo)
- **Performance:** lighthouse, @lhci/cli
- **Media:** sharp-cli, @marp-team/marp-cli
- **Mock APIs:** json-server

### Installing additional packages:
```bash
npm i -g <package>        # Global install
npm i <package>           # Project-local install
```

## Python 3

### Installed packages:
- **HTTP:** requests, httpx
- **Scraping:** beautifulsoup4, lxml
- **Images:** Pillow
- **Data:** pandas, numpy, matplotlib, seaborn
- **PDF:** reportlab, weasyprint, cairosvg, fpdf2, PyMuPDF, pdfkit, img2pdf
- **Excel:** openpyxl, xlsxwriter, xlrd
- **Documents:** python-docx, python-pptx, markdown, jinja2
- **Config:** pyyaml, python-dotenv
- **CLI:** rich, click, tqdm
- **Code quality:** Desloppify, Bandit, tree-sitter
- **Browser:** playwright
- **Web framework:** fastapi, uvicorn

### Installing additional packages:
```bash
pip install --break-system-packages <package>
```
The `--break-system-packages` flag is required (no venv in container context).

## AI CLI Providers

| CLI | Command | Notes |
|-----|---------|-------|
| **Claude Code** | `claude` | Primary — you are running inside this |
| **Gemini CLI** | `gemini` | Requires `GEMINI_API_KEY` env var. Config persists across rebuilds. Notifications via Apprise. |
| **OpenAI Codex** | `codex` | `OPENAI_API_KEY` or ChatGPT subscription (`codex login --device-auth`). Raw CLI config is seeded on first boot. Auth persists across rebuilds. Notifications via Apprise. |
| **Cursor** | `cursor` | Requires `CURSOR_API_KEY` env var. Config persists across rebuilds. |
| **TaskMaster AI** | `task-master` | Task planning and management |
| **Junie** | `junie` | JetBrains AI coding agent (requires JetBrains account) |
| **OpenCode** | `opencode` | Open source AI agent (supports multiple providers) |
| **Pi Coding Agent** | `pi` | Minimal agent harness (supports multiple providers) |

## Desloppify

- `desloppify` is installed in the full image.
- It is passive by default. HolyClaude does not run scans, create `.desloppify/`, edit `.gitignore`, or modify mounted workspaces unless the user runs Desloppify.
- Optional global skill setup is controlled by `HOLYCLAUDE_DESLOPPIFY_SETUP`. Valid values: `off`, `all`, `claude`, `codex`, `gemini`, `opencode`, or comma-separated subsets.
- `all` expands to `claude,codex,gemini`. OpenCode is not included in `all`.
- OpenCode can discover Claude-compatible skills from `~/.claude/skills`. Do not combine `claude` and `opencode` automatic setup.
- Normal project usage: `desloppify scan --path .` then `desloppify next`. After scans, add `.desloppify/` to that project's `.gitignore`.

## System Tools

### Command-line utilities:
- **Search:** ripgrep (`rg`), fd (`fdfind`), fzf, grep
- **Files:** tree, bat (`batcat` or `bat`), jq, zip/unzip
- **Network:** curl, wget, openssh-client
- **Process:** htop, lsof, strace, iproute2 (`ip`, `ss`)
- **Terminal:** tmux
- **Version control:** git, gh (GitHub CLI)

### Database CLIs:
- **PostgreSQL:** `psql`
- **Redis:** `redis-cli`
- **SQLite:** `sqlite3`

### Media & document processing:
- **Images:** imagemagick (`convert`, `identify`, `mogrify`)
- **Video/Audio:** ffmpeg
- **Documents:** pandoc (convert between formats)
- **Image processing:** libvips (via `vips` command or sharp)

### Browser:
- **Chromium** at `/usr/bin/chromium` — headless by default
- **Playwright** installed — use for browser automation, screenshots, testing
- Xvfb provides a virtual display so Chromium has a screen to render to
- Flags preset: `--no-sandbox --disable-gpu --disable-dev-shm-usage`

## GitHub CLI (gh)

Pre-installed and ready. Authenticate with:
```bash
gh auth login
```

Common operations:
```bash
gh repo clone owner/repo
gh pr create --title "..." --body "..."
gh issue list
gh pr merge
```

## Notifications (Apprise)

Optional push notifications via [Apprise](https://github.com/caronc/apprise) — supports 100+ services (Discord, Telegram, Slack, Email, Pushover, Gotify, and more). Disabled by default.

**To enable:**
1. Set one or more `NOTIFY_*` environment variables (e.g. `NOTIFY_DISCORD`, `NOTIFY_TELEGRAM`, `NOTIFY_PUSHOVER`)
2. Create the flag file: `touch ~/.claude/notify-on`

**To disable:** `rm ~/.claude/notify-on`

**Events:**
- `stop` — Claude finishes a task
- `error` — A tool use failure occurs

## Workspace

- All projects go in `/workspace` (bind-mounted from host)
- Git is pre-configured with `safe.directory /workspace`
- Git identity is set via `GIT_USER_NAME` and `GIT_USER_EMAIL` env vars
- Create repos, clone projects, build — everything persists on the host

## Permissions

Claude Code runs in `acceptEdits` mode by default:
- File edits: allowed without confirmation
- Shell commands: follow Claude Code's current permission prompt behavior
- To enable full bypass: change `acceptEdits` to `bypassPermissions` in `~/.claude/settings.json`

Codex has separate configurable near-parity controls:
- CloudCLI Codex chat: `HOLYCLAUDE_CODEX_CHAT_PERMISSION_MODE`, read at runtime by CloudCLI. Valid values: `default`, `acceptEdits`, `bypassPermissions`. Recommended: `acceptEdits`.
- Raw `codex` CLI: `HOLYCLAUDE_CODEX_CLI_PERMISSION_MODE`, used only when creating a new `~/.codex/config.toml` on first boot. Existing configs are not overwritten, and the generated value persists until you edit it.
- `bypassPermissions` gives full access with no approval inside the Docker container and mounted volumes. Use it only for trusted local workspaces.

## Container Lifecycle

- **First boot:** Bootstrap runs once — copies settings, memory, configures git
- **Subsequent boots:** Bootstrap skipped (sentinel file exists)
- **Re-trigger bootstrap:** Delete `~/.claude/.holyclaude-bootstrapped`
- **Credentials survive rebuilds:** `~/.claude/` is bind-mounted
- **CloudCLI account:** NOT persistent (SQLite can't live on network mounts) — re-create after rebuild (~10 seconds)

## Tips

- Use the **Web Terminal** plugin in CloudCLI instead of "Continue in Shell" (known CloudCLI bug)
- Chromium needs `shm_size: 2g` or higher in docker-compose to avoid crashes
- If on SMB/CIFS mounts, enable `CHOKIDAR_USEPOLLING=1` and `WATCHFILES_FORCE_POLLING=true`
- SQLite databases should NOT be stored on network mounts (file locking fails on CIFS)

---

## Your Preferences

Add your personal preferences below. This section persists across container rebuilds.

```
# Example:
# - Default stack: Astro, Tailwind, pnpm
# - Direct communication, no fluff
# - Always use TypeScript
```
