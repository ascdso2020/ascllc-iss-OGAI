# ==============================================================================
# HolyClaude — Pre-configured Docker Environment for Claude Code CLI + CloudCLI
# https://github.com/coderluii/holyclaude
#
# Build variants:
#   docker build -t holyclaude .                        # full (default)
#   docker build --build-arg VARIANT=slim -t holyclaude:slim .
# ==============================================================================

FROM node:26.4.0-bookworm-slim

LABEL org.opencontainers.image.source=https://github.com/CoderLuii/HolyClaude

# ---------- Build args ----------
ARG S6_OVERLAY_VERSION=3.2.3.0
ARG TARGETARCH
ARG VARIANT=full

# ---------- Environment ----------
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    DISPLAY=:99 \
    DBUS_SESSION_BUS_ADDRESS=disabled: \
    CHROMIUM_FLAGS="--no-sandbox --disable-gpu --disable-dev-shm-usage" \
    CHROME_PATH=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    NODE_PATH=/usr/local/lib/node_modules

# ---------- s6-overlay v3 (multi-arch) ----------
RUN apt-get update && apt-get install -y --no-install-recommends xz-utils curl ca-certificates && rm -rf /var/lib/apt/lists/*
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
RUN S6_ARCH=$(case "$TARGETARCH" in arm64) echo "aarch64";; *) echo "x86_64";; esac) && \
    curl -fsSL -o /tmp/s6-overlay-arch.tar.xz \
      "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" && \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-arch.tar.xz && \
    rm /tmp/s6-overlay-*.tar.xz

# ---------- System packages (always installed) ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    git curl wget jq ripgrep fd-find unzip zip tree tmux fzf bat bubblewrap \
    # Build tools
    build-essential pkg-config python3 python3-pip python3-venv \
    # Browser runtime dependencies are installed by Playwright below.
    # Fonts
    fonts-liberation2 fonts-dejavu-core fonts-noto-core fonts-noto-color-emoji fonts-inter \
    # Locale support
    locales \
    # Debugging tools
    strace lsof iproute2 procps htop \
    # Database CLI tools
    postgresql-client redis-tools sqlite3 \
    # SSH/Mosh remote shell support (disabled by default)
    openssh-client openssh-server mosh \
    # Xvfb for headless Chrome
    xvfb \
    # Image processing
    imagemagick \
    # Sudo
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub

# ---------- bubblewrap setuid (Codex CLI sandbox on restricted kernels) ----------
RUN test -x /usr/bin/bwrap && chown root:root /usr/bin/bwrap && chmod 4755 /usr/bin/bwrap && test "$(stat -c '%a %u %g' /usr/bin/bwrap)" = "4755 0 0"

# ---------- Full-only system packages ----------
RUN if [ "$VARIANT" = "full" ]; then \
    apt-get update && apt-get install -y --no-install-recommends \
      pandoc ffmpeg libvips-dev \
    && rm -rf /var/lib/apt/lists/*; \
    fi

# ---------- Azure CLI (full only) ----------
RUN if [ "$VARIANT" = "full" ]; then \
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && rm -rf /var/lib/apt/lists/*; \
    fi

# ---------- GitHub CLI ----------
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# ---------- bat symlink (Debian names it batcat) ----------
RUN ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true

# ---------- Locale configuration ----------
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

# ---------- Create claude user ----------
# The official Node slim image already has UID 1000 as 'node' — rename it to 'claude'
RUN usermod -l claude -d /home/claude -m node && \
    groupmod -n claude node && \
    echo "claude ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claude && \
    chmod 0440 /etc/sudoers.d/claude

# ---------- Claude Code CLI (native installer) ----------
# CRITICAL: WORKDIR must be non-root-owned or the installer hangs
WORKDIR /workspace
USER claude
RUN curl -fsSL https://claude.ai/install.sh | bash
USER root
RUN rm -f /home/claude/.claude.json
ENV PATH="/home/claude/.local/bin:${PATH}"

# ---------- npm global packages (slim — always installed) ----------
RUN PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm i -g \
    playwright@1.61.0 \
    typescript@6.0.3 tsx@4.23.0 \
    pnpm@11.10.0 \
    vite@8.1.3 esbuild@0.28.1 \
    eslint@10.6.0 prettier@3.9.4 \
    serve@14.2.6 nodemon@3.1.14 concurrently@10.0.3 \
    dotenv-cli@11.0.0

# ---------- npm global packages (full only) ----------
RUN if [ "$VARIANT" = "full" ]; then \
    npm i -g \
      wrangler@4.107.0 vercel@54.21.0 netlify-cli@26.1.0 \
      pm2@7.0.3 \
      prisma@7.8.0 drizzle-kit@0.31.10 \
      eas-cli@20.5.1 \
      lighthouse@13.4.0 @lhci/cli@0.15.1 \
      sharp-cli@5.2.0 json-server@1.0.0-beta.15 http-server@14.1.1 \
      @marp-team/marp-cli@4.4.1 && \
    npm i -g --legacy-peer-deps @cloudflare/next-on-pages@1.13.16; \
    fi

# ---------- Python packages (slim — always installed) ----------
RUN pip install --no-cache-dir --break-system-packages \
    requests==2.34.2 httpx==0.28.1 beautifulsoup4==4.15.0 lxml==6.1.1 \
    Pillow==12.3.0 \
    pandas==3.0.3 numpy==2.4.6 \
    openpyxl==3.1.5 python-docx==1.2.0 \
    jinja2==3.1.6 pyyaml==6.0.3 python-dotenv==1.2.2 markdown==3.10.2 \
    rich==15.0.0 click==8.4.2 tqdm==4.68.3 \
    'desloppify[full]==1.0' bandit==1.9.4 defusedxml==0.7.1 \
    tree-sitter==0.26.0 tree-sitter-language-pack==1.6.2 stevedore==5.9.0 \
    playwright==1.61.0 \
    apprise==1.12.0

COPY scripts/holyclaude-chromium /usr/local/bin/holyclaude-chromium
RUN mkdir -p /ms-playwright && \
    playwright install --with-deps --no-shell chromium && \
    rm -rf /var/lib/apt/lists/* && \
    chmod -R a+rX /ms-playwright && \
    chmod +x /usr/local/bin/holyclaude-chromium && \
    ln -sf /usr/local/bin/holyclaude-chromium /usr/bin/chromium && \
    NODE_CHROMIUM_PATH="$(node --input-type=module -e "import { createRequire } from 'node:module'; import { existsSync } from 'node:fs'; const require = createRequire('file:///usr/local/lib/node_modules/playwright/package.json'); const playwright = require('playwright'); const executablePath = playwright.chromium.executablePath(); if (!existsSync(executablePath)) throw new Error('missing Node Playwright Chromium at ' + executablePath); console.log(executablePath);")" && \
    PYTHON_CHROMIUM_PATH="$(python3 -c "from playwright.sync_api import sync_playwright; p = sync_playwright().start(); print(p.chromium.executable_path); p.stop()")" && \
    test "$NODE_CHROMIUM_PATH" = "$PYTHON_CHROMIUM_PATH" && \
    test -x "$NODE_CHROMIUM_PATH" && \
    runuser -u claude -- test -r "$NODE_CHROMIUM_PATH" && \
    runuser -u claude -- test -x "$NODE_CHROMIUM_PATH"

# ---------- Python packages (full only) ----------
RUN if [ "$VARIANT" = "full" ]; then \
    pip install --no-cache-dir --break-system-packages \
      reportlab==5.0.0 weasyprint==69.0 cairosvg==2.9.0 fpdf2==2.8.7 PyMuPDF==1.28.0 pdfkit==1.0.0 img2pdf==0.6.3 \
      xlsxwriter==3.2.9 xlrd==2.0.2 \
      matplotlib==3.11.0 seaborn==0.13.2 \
      python-pptx==1.0.2 \
      fastapi==0.139.0 uvicorn==0.50.2; \
    fi

# ---------- AI CLI providers ----------
RUN npm i -g @google/gemini-cli@0.49.0 @openai/codex@0.142.5 task-master-ai@0.43.1
USER claude
RUN curl -fsSL https://cursor.com/install | bash && \
    if [ ! -e /home/claude/.local/bin/cursor ] && [ -e /home/claude/.local/bin/cursor-agent ]; then \
      ln -s /home/claude/.local/bin/cursor-agent /home/claude/.local/bin/cursor; \
    fi
USER root

# ---------- Junie CLI (full only) ----------
USER claude
RUN if [ "$VARIANT" = "full" ]; then \
    curl -fsSL https://junie.jetbrains.com/install.sh | bash; \
    fi
USER root

# ---------- OpenCode CLI (full only) ----------
RUN if [ "$VARIANT" = "full" ]; then \
    npm i -g opencode-ai@1.17.14; \
    fi

# ---------- Pi Coding Agent (full only) ----------
RUN if [ "$VARIANT" = "full" ]; then \
    npm i -g --ignore-scripts @earendil-works/pi-coding-agent@0.80.3; \
    fi

ARG CLOUDCLI_VERSION=1.36.1
ARG CLOUDCLI_ACCOUNT_MANAGEMENT_ARTIFACT=cloudcli-ai-cloudcli-1.36.1-holyclaude-account-management.tgz
COPY vendor/artifacts/${CLOUDCLI_ACCOUNT_MANAGEMENT_ARTIFACT} /tmp/vendor/cloudcli-ai-cloudcli.tgz
COPY vendor/artifacts/cloudcli-account-management.manifest.json /tmp/vendor/cloudcli-account-management.manifest.json

# ---------- CloudCLI (web UI for Claude Code) ----------
RUN npm i -g /tmp/vendor/cloudcli-ai-cloudcli.tgz && rm -f /tmp/vendor/cloudcli-ai-cloudcli.tgz
RUN node --input-type=module -e "import { createRequire } from 'node:module'; import { existsSync } from 'node:fs'; const require = createRequire('file:///usr/local/lib/node_modules/@cloudcli-ai/cloudcli/dist-server/server/index.js'); const playwright = require('playwright'); const executablePath = playwright.chromium.executablePath(); if (!existsSync(executablePath)) throw new Error('missing CloudCLI-resolved Playwright Chromium at ' + executablePath); console.log(executablePath);"
COPY scripts/patch-cloudcli-apprise-notifications.mjs /tmp/patch-cloudcli-apprise-notifications.mjs
COPY scripts/patch-cloudcli-base-path.mjs /tmp/patch-cloudcli-base-path.mjs
COPY scripts/patch-cloudcli-browser-runtime.mjs /tmp/patch-cloudcli-browser-runtime.mjs
COPY scripts/patch-cloudcli-codex-complete-exit-code.mjs /tmp/patch-cloudcli-codex-complete-exit-code.mjs
COPY scripts/patch-cloudcli-codex-permissions.mjs /tmp/patch-cloudcli-codex-permissions.mjs
COPY scripts/patch-cloudcli-disable-self-update.mjs /tmp/patch-cloudcli-disable-self-update.mjs
COPY --chown=claude:claude scripts/patch-cloudcli-web-terminal-rendering.mjs /tmp/patch-cloudcli-web-terminal-rendering.mjs
COPY scripts/verify-cloudcli-account-management-support.mjs /tmp/verify-cloudcli-account-management-support.mjs
RUN touch /usr/local/lib/node_modules/@cloudcli-ai/cloudcli/.env

# patch: launch CloudCLI Browser Use with HolyClaude's canonical Chromium
RUN node /tmp/patch-cloudcli-browser-runtime.mjs && rm -f /tmp/patch-cloudcli-browser-runtime.mjs
RUN CLOUDCLI_BROWSER_USE="/usr/local/lib/node_modules/@cloudcli-ai/cloudcli/dist-server/server/modules/browser-use/browser-use.service.js" && \
    grep -Fq "// HolyClaude canonical browser runtime" "$CLOUDCLI_BROWSER_USE" && \
    grep -Fq "executablePath: process.env.CHROME_PATH," "$CLOUDCLI_BROWSER_USE" && \
    echo "[patch] CloudCLI Browser Use canonical Chromium applied to runtime"

# patch: disable CloudCLI npm self-update inside HolyClaude (issue #50)
RUN node /tmp/patch-cloudcli-disable-self-update.mjs && rm -f /tmp/patch-cloudcli-disable-self-update.mjs

# CloudCLI 1.36.1 already contains the WebSocket binary-frame fix, provider
# model flow, and final Codex complete exit codes. Keep checks fail-closed.
RUN CLOUDCLI_WS_PROXY="/usr/local/lib/node_modules/@cloudcli-ai/cloudcli/dist-server/server/modules/websocket/services/plugin-websocket-proxy.service.js" && \
    grep -q "binary: isBinary" "$CLOUDCLI_WS_PROXY" && \
    echo "[patch] WebSocket frame type fix already present upstream"

RUN CLOUDCLI_COMMANDS="/usr/local/lib/node_modules/@cloudcli-ai/cloudcli/dist-server/server/routes/commands.js" && \
    grep -q "providerModelsService.getProviderModels" "$CLOUDCLI_COMMANDS" && \
    echo "[patch] Provider model command flow already present upstream"

RUN CLOUDCLI_CODEX="/usr/local/lib/node_modules/@cloudcli-ai/cloudcli/dist-server/server/openai-codex.js" && \
    grep -q "exitCode: terminalFailure ? 1 : 0" "$CLOUDCLI_CODEX" && \
    grep -q "exitCode: 1" "$CLOUDCLI_CODEX" && \
    echo "[patch] Codex final completion exitCode fix already present upstream"

# patch: support serving CloudCLI below a reverse-proxy subpath (issue #64)
RUN node /tmp/patch-cloudcli-base-path.mjs && rm -f /tmp/patch-cloudcli-base-path.mjs
RUN CLOUDCLI_SERVER="/usr/local/lib/node_modules/@cloudcli-ai/cloudcli/dist-server/server/index.js" && \
    CLOUDCLI_WS_SERVER="/usr/local/lib/node_modules/@cloudcli-ai/cloudcli/dist-server/server/modules/websocket/services/websocket-server.service.js" && \
    grep -q "HOLYCLAUDE_BASE_PATH" "$CLOUDCLI_SERVER" && \
    grep -q "sendHolyClaudeIndexHtml" "$CLOUDCLI_SERVER" && \
    grep -q "stripHolyClaudeBasePathFromPathname" "$CLOUDCLI_WS_SERVER" && \
    echo "[patch] CloudCLI base path support applied to runtime"

# patch: bridge Codex CloudCLI lifecycle events to Apprise (issue #17)
RUN node /tmp/patch-cloudcli-apprise-notifications.mjs && rm -f /tmp/patch-cloudcli-apprise-notifications.mjs
RUN CLOUDCLI_NOTIFICATIONS="/usr/local/lib/node_modules/@cloudcli-ai/cloudcli/dist-server/server/modules/notifications/services/notification-orchestrator.service.js" && \
    test "$(grep -c "^  sendAppriseLifecycleNotification({" "$CLOUDCLI_NOTIFICATIONS")" = "2" && \
    grep -q "kind: 'stop'" "$CLOUDCLI_NOTIFICATIONS" && \
    grep -q "kind: 'error'" "$CLOUDCLI_NOTIFICATIONS" && \
    echo "[patch] Apprise lifecycle bridge applied to CloudCLI runtime"

# patch: configure Codex CloudCLI chat permission mode (issue #18)
RUN node /tmp/patch-cloudcli-codex-permissions.mjs && rm -f /tmp/patch-cloudcli-codex-permissions.mjs

# patch: preserve explicit Codex complete fields on the 1.35.x provider path (issue #19)
RUN node /tmp/patch-cloudcli-codex-complete-exit-code.mjs && rm -f /tmp/patch-cloudcli-codex-complete-exit-code.mjs
RUN CLOUDCLI_CODEX_PROVIDER="/usr/local/lib/node_modules/@cloudcli-ai/cloudcli/dist-server/server/modules/providers/list/codex/codex-sessions.provider.js" && \
    grep -q "exitCode: 0" "$CLOUDCLI_CODEX_PROVIDER" && \
    grep -q "success: true" "$CLOUDCLI_CODEX_PROVIDER" && \
    grep -q "aborted: false" "$CLOUDCLI_CODEX_PROVIDER" && \
    echo "[patch] Codex provider completion fields applied to CloudCLI runtime"

# patch: local account logout/password bridge for CloudCLI (issue #65)
RUN node /tmp/verify-cloudcli-account-management-support.mjs /usr/local/lib/node_modules/@cloudcli-ai/cloudcli && \
    rm -f /tmp/verify-cloudcli-account-management-support.mjs /tmp/vendor/cloudcli-account-management.manifest.json

# ---------- CloudCLI plugins (baked into image) ----------
USER claude
RUN mkdir -p /home/claude/.claude-code-ui/plugins && \
    git init /home/claude/.claude-code-ui/plugins/project-stats && \
    cd /home/claude/.claude-code-ui/plugins/project-stats && \
    git remote add origin https://github.com/cloudcli-ai/cloudcli-plugin-starter.git && \
    git fetch --depth 1 origin 4895cd3fd33362471e739b786493aba048487bcc && \
    git checkout --detach FETCH_HEAD && \
    test "$(git rev-parse --short=12 HEAD)" = "4895cd3fd333" && \
    npm install && npm run build && \
    git init /home/claude/.claude-code-ui/plugins/web-terminal && \
    cd /home/claude/.claude-code-ui/plugins/web-terminal && \
    git remote add origin https://github.com/cloudcli-ai/cloudcli-plugin-terminal.git && \
    git fetch --depth 1 origin 8aa41f614c216d961e7c0d9c3e67982c6b2d9da3 && \
    git checkout --detach FETCH_HEAD && \
    test "$(git rev-parse --short=12 HEAD)" = "8aa41f614c21" && \
    node /tmp/patch-cloudcli-web-terminal-rendering.mjs /home/claude/.claude-code-ui/plugins/web-terminal && \
    npm install && npm run build && \
    rm -f /tmp/patch-cloudcli-web-terminal-rendering.mjs && \
    echo '{"project-stats":{"name":"project-stats","source":"https://github.com/cloudcli-ai/cloudcli-plugin-starter","enabled":true},"web-terminal":{"name":"web-terminal","source":"https://github.com/cloudcli-ai/cloudcli-plugin-terminal","enabled":true}}' > /home/claude/.claude-code-ui/plugins.json
USER root

# ---------- Store variant for bootstrap ----------
RUN echo "${VARIANT}" > /etc/holyclaude-variant

# ---------- Copy config files ----------
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/bootstrap.sh /usr/local/bin/bootstrap.sh
COPY scripts/holyclaude-mosh-server /usr/local/bin/holyclaude-mosh-server
COPY scripts/persist-claude-json.mjs /usr/local/bin/persist-claude-json.mjs
COPY scripts/notify.py /usr/local/bin/notify.py
COPY config/settings.json /usr/local/share/holyclaude/settings.json
COPY config/claude-memory-full.md /usr/local/share/holyclaude/claude-memory-full.md
COPY config/claude-memory-slim.md /usr/local/share/holyclaude/claude-memory-slim.md
RUN chmod +x /usr/local/bin/entrypoint.sh \
    /usr/local/bin/bootstrap.sh \
    /usr/local/bin/holyclaude-mosh-server \
    /usr/local/bin/persist-claude-json.mjs \
    /usr/local/bin/notify.py

RUN mkdir -p /usr/local/lib/holyclaude && \
    if [ -x /usr/bin/mosh-server ]; then \
      mv /usr/bin/mosh-server /usr/local/lib/holyclaude/mosh-server.real && \
      ln -sf /usr/local/bin/holyclaude-mosh-server /usr/bin/mosh-server; \
    fi

# ---------- s6-overlay service definitions ----------
COPY s6-overlay/s6-rc.d/cloudcli/type /etc/s6-overlay/s6-rc.d/cloudcli/type
COPY s6-overlay/s6-rc.d/cloudcli/run /etc/s6-overlay/s6-rc.d/cloudcli/run
COPY s6-overlay/s6-rc.d/persist-claude-json/type /etc/s6-overlay/s6-rc.d/persist-claude-json/type
COPY s6-overlay/s6-rc.d/persist-claude-json/run /etc/s6-overlay/s6-rc.d/persist-claude-json/run
COPY s6-overlay/s6-rc.d/xvfb/type /etc/s6-overlay/s6-rc.d/xvfb/type
COPY s6-overlay/s6-rc.d/xvfb/run /etc/s6-overlay/s6-rc.d/xvfb/run
COPY s6-overlay/s6-rc.d/sshd/type /etc/s6-overlay/s6-rc.d/sshd/type
COPY s6-overlay/s6-rc.d/sshd/run /etc/s6-overlay/s6-rc.d/sshd/run
RUN chmod +x /etc/s6-overlay/s6-rc.d/cloudcli/run \
    /etc/s6-overlay/s6-rc.d/persist-claude-json/run \
    /etc/s6-overlay/s6-rc.d/xvfb/run \
    /etc/s6-overlay/s6-rc.d/sshd/run && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/cloudcli && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/persist-claude-json && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/xvfb

# ---------- Working directory ----------
WORKDIR /workspace

# ---------- Health check ----------
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -sf http://localhost:3001/ || exit 1

# ---------- s6-overlay as PID 1 ----------
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
