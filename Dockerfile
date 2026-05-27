# ==============================================================================
# HolyClaude — Pre-configured Docker Environment for Claude Code CLI + CloudCLI
# https://github.com/coderluii/holyclaude
#
# Build variants:
#   docker build -t holyclaude .                        # full (default)
#   docker build --build-arg VARIANT=slim -t holyclaude:slim .
# ==============================================================================

FROM node:26.2.0-bookworm-slim

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
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

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
    # Browser (Playwright/Puppeteer)
    chromium \
    # Fonts
    fonts-liberation2 fonts-dejavu-core fonts-noto-core fonts-noto-color-emoji fonts-inter \
    # Locale support
    locales \
    # Debugging tools
    strace lsof iproute2 procps htop \
    # Database CLI tools
    postgresql-client redis-tools sqlite3 \
    # SSH client (NOT server)
    openssh-client \
    # Xvfb for headless Chrome
    xvfb \
    # Image processing
    imagemagick \
    # Sudo
    sudo \
    && rm -rf /var/lib/apt/lists/*

# ---------- bubblewrap setuid (Codex CLI sandbox on restricted kernels) ----------
RUN chmod u+s /usr/bin/bwrap

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
ENV PATH="/home/claude/.local/bin:${PATH}"

# ---------- npm global packages (slim — always installed) ----------
RUN npm i -g \
    typescript@6.0.3 tsx@4.22.3 \
    pnpm@11.3.0 \
    vite@8.0.14 esbuild@0.28.0 \
    eslint@10.4.0 prettier@3.8.3 \
    serve@14.2.6 nodemon@3.1.14 concurrently@9.2.1 \
    dotenv-cli@11.0.0

# ---------- npm global packages (full only) ----------
RUN if [ "$VARIANT" = "full" ]; then \
    npm i -g \
      wrangler@4.95.0 vercel@54.5.0 netlify-cli@26.0.2 \
      pm2@7.0.1 \
      prisma@7.8.0 drizzle-kit@0.31.10 \
      eas-cli@19.1.0 \
      lighthouse@13.3.0 @lhci/cli@0.15.1 \
      sharp-cli@5.2.0 json-server@0.17.4 http-server@14.1.1 \
      @marp-team/marp-cli@4.4.0 @cloudflare/next-on-pages@1.13.16; \
    fi

# ---------- Python packages (slim — always installed) ----------
RUN pip install --no-cache-dir --break-system-packages \
    requests==2.34.2 httpx==0.28.1 beautifulsoup4==4.14.3 lxml==6.1.1 \
    Pillow==12.2.0 \
    pandas==3.0.3 numpy==2.4.6 \
    openpyxl==3.1.5 python-docx==1.2.0 \
    jinja2==3.1.6 pyyaml==6.0.3 python-dotenv==1.2.2 markdown==3.10.2 \
    rich==15.0.0 click==8.4.1 tqdm==4.67.3 \
    playwright==1.60.0 \
    apprise==1.10.0

# ---------- Python packages (full only) ----------
RUN if [ "$VARIANT" = "full" ]; then \
    pip install --no-cache-dir --break-system-packages \
      reportlab==4.5.1 weasyprint==68.1 cairosvg==2.9.0 fpdf2==2.8.7 PyMuPDF==1.27.2.3 pdfkit==1.0.0 img2pdf==0.6.3 \
      xlsxwriter==3.2.9 xlrd==2.0.2 \
      matplotlib==3.10.9 seaborn==0.13.2 \
      python-pptx==1.0.2 \
      fastapi==0.136.3 uvicorn==0.48.0 \
      httpie==3.2.4; \
    fi

# ---------- AI CLI providers ----------
RUN npm i -g @google/gemini-cli@0.43.0 @openai/codex@0.134.0 task-master-ai@0.43.1
USER claude
RUN curl -fsSL https://cursor.com/install | bash
USER root

# ---------- Junie CLI (full only) ----------
USER claude
RUN if [ "$VARIANT" = "full" ]; then \
    curl -fsSL https://junie.jetbrains.com/install.sh | bash; \
    fi
USER root

# ---------- OpenCode CLI (full only) ----------
RUN if [ "$VARIANT" = "full" ]; then \
    npm i -g opencode-ai@1.15.10; \
    fi

COPY vendor/artifacts/siteboon-claude-code-ui-1.26.3.tgz /tmp/vendor/siteboon-claude-code-ui-1.26.3.tgz

# ---------- CloudCLI (web UI for Claude Code) ----------
RUN npm i -g /tmp/vendor/siteboon-claude-code-ui-1.26.3.tgz && rm -f /tmp/vendor/siteboon-claude-code-ui-1.26.3.tgz
RUN touch /usr/local/lib/node_modules/@siteboon/claude-code-ui/.env

# ---------- Patch: preserve WebSocket frame type in plugin proxy (Issue #11) ----------
RUN CLOUDCLI_INDEX="/usr/local/lib/node_modules/@siteboon/claude-code-ui/server/index.js" && \
    grep -q "upstream.on('message', (data) =>" "$CLOUDCLI_INDEX" && \
    sed -i "s/upstream.on('message', (data) => {/upstream.on('message', (data, isBinary) => {/" "$CLOUDCLI_INDEX" && \
    sed -i "s/if (clientWs.readyState === WebSocket.OPEN) clientWs.send(data)/if (clientWs.readyState === WebSocket.OPEN) clientWs.send(data, { binary: isBinary })/" "$CLOUDCLI_INDEX" && \
    sed -i "s/clientWs.on('message', (data) => {/clientWs.on('message', (data, isBinary) => {/" "$CLOUDCLI_INDEX" && \
    sed -i "s/if (upstream.readyState === WebSocket.OPEN) upstream.send(data)/if (upstream.readyState === WebSocket.OPEN) upstream.send(data, { binary: isBinary })/" "$CLOUDCLI_INDEX" && \
    echo "[patch] WebSocket frame type fix applied (both directions)" || \
    (echo "[patch] ERROR: WebSocket pattern not found in vendored CloudCLI install"; exit 1)

# patch: preserve Shell tab scroll position across periodic refresh (issue #35)
RUN CLOUDCLI_BUNDLE="/usr/local/lib/node_modules/@siteboon/claude-code-ui/dist/assets/index-X3ImjnMV.js" && \
    grep -q 'const B=()=>{v.current?.focus()}' "$CLOUDCLI_BUNDLE" && \
    perl -pi -e 's/const B=\(\)=>\{v\.current\?\.focus\(\)\}/const B=()=>{const _vp=v.current?.buffer?.active?.viewportY??0;v.current?.focus();v.current?.scrollToLine(_vp)}/g' "$CLOUDCLI_BUNDLE" && \
    echo "[patch] Shell scroll position fix applied" || \
    (echo "[patch] ERROR: Shell scroll pattern not found in vendored CloudCLI bundle"; exit 1)

# patch v1.2.2-1: commands.js expose newModel in spawn args (issue #36)
RUN CLOUDCLI_COMMANDS="/usr/local/lib/node_modules/@siteboon/claude-code-ui/server/routes/commands.js" && \
    grep -q 'message: args.length > 0' "$CLOUDCLI_COMMANDS" && \
    perl -pi -e 's/^(\s+)(message: args\.length > 0)/$1newModel: args.length > 0 ? args[0] : null,\n$1$2/' "$CLOUDCLI_COMMANDS" && \
    echo "[patch] commands.js newModel field added" || \
    (echo "[patch] ERROR: commands.js newModel pattern not found"; exit 1)

# patch v1.2.2-2: bundle expose setClaudeModel in claudeModel context spread (issue #36)
RUN CLOUDCLI_BUNDLE="/usr/local/lib/node_modules/@siteboon/claude-code-ui/dist/assets/index-X3ImjnMV.js" && \
    grep -q 'claudeModel:W,codexModel:V' "$CLOUDCLI_BUNDLE" && \
    perl -pi -e 's/\QclaudeModel:W,codexModel:V\E/claudeModel:W,setClaudeModel:L,codexModel:V/g' "$CLOUDCLI_BUNDLE" && \
    echo "[patch] bundle setClaudeModel context spread applied" || \
    (echo "[patch] ERROR: bundle claudeModel:W pattern not found"; exit 1)

# patch v1.2.2-3: bundle wire setClaudeModel:lS2 into cursorModel destructure (issue #36)
RUN CLOUDCLI_BUNDLE="/usr/local/lib/node_modules/@siteboon/claude-code-ui/dist/assets/index-X3ImjnMV.js" && \
    grep -q 'cursorModel:o,claudeModel:l,codexModel:c' "$CLOUDCLI_BUNDLE" && \
    perl -pi -e 's/\QcursorModel:o,claudeModel:l,codexModel:c\E/cursorModel:o,claudeModel:l,setClaudeModel:lS2,codexModel:c/g' "$CLOUDCLI_BUNDLE" && \
    echo "[patch] bundle setClaudeModel:lS2 destructure applied" || \
    (echo "[patch] ERROR: bundle cursorModel destructure pattern not found"; exit 1)

# patch v1.2.2-4: bundle apply newModel on SSE model event (issue #36)
RUN CLOUDCLI_BUNDLE="/usr/local/lib/node_modules/@siteboon/claude-code-ui/dist/assets/index-X3ImjnMV.js" && \
    grep -q 'case"model":k({type:"assistant"' "$CLOUDCLI_BUNDLE" && \
    perl -pi -e 's/\Qcase"model":k({type:"assistant"\E/case"model":me.newModel\&\&lS2\&\&(lS2(me.newModel),localStorage.setItem("claude-model",me.newModel));k({type:"assistant"/g' "$CLOUDCLI_BUNDLE" && \
    echo "[patch] bundle SSE model event handler applied" || \
    (echo "[patch] ERROR: bundle case\"model\" pattern not found"; exit 1)

# patch v1.2.2-5: bundle add custom model option to select (issue #36)
RUN CLOUDCLI_BUNDLE="/usr/local/lib/node_modules/@siteboon/claude-code-ui/dist/assets/index-X3ImjnMV.js" && \
    grep -q 'children:N.OPTIONS.map(({value:C,label:j})=>s.jsx("option",{value:C,children:j},C+j))}' "$CLOUDCLI_BUNDLE" && \
    perl -pi -e 's/\Qchildren:N.OPTIONS.map(({value:C,label:j})=>s.jsx("option",{value:C,children:j},C+j))}\E/children:[...N.OPTIONS.map(({value:C,label:j})=>s.jsx("option",{value:C,children:j},C+j)),!N.OPTIONS.some(C=>C.value===k)\&\&k\&\&s.jsx("option",{value:k,children:k},k+"custom")].filter(Boolean)}/g' "$CLOUDCLI_BUNDLE" && \
    echo "[patch] bundle custom model select option applied" || \
    (echo "[patch] ERROR: bundle custom model select pattern not found"; exit 1)

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
    git fetch --depth 1 origin 2bb28540ff5fda84972f99489f976551b8a552e8 && \
    git checkout --detach FETCH_HEAD && \
    test "$(git rev-parse --short=12 HEAD)" = "2bb28540ff5f" && \
    npm install && npm run build && \
    echo '{"project-stats":{"name":"project-stats","source":"https://github.com/cloudcli-ai/cloudcli-plugin-starter","enabled":true},"web-terminal":{"name":"web-terminal","source":"https://github.com/cloudcli-ai/cloudcli-plugin-terminal","enabled":true}}' > /home/claude/.claude-code-ui/plugins.json
USER root

# ---------- Store variant for bootstrap ----------
RUN echo "${VARIANT}" > /etc/holyclaude-variant

# ---------- Copy config files ----------
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/bootstrap.sh /usr/local/bin/bootstrap.sh
COPY scripts/notify.py /usr/local/bin/notify.py
COPY config/settings.json /usr/local/share/holyclaude/settings.json
COPY config/claude-memory-full.md /usr/local/share/holyclaude/claude-memory-full.md
COPY config/claude-memory-slim.md /usr/local/share/holyclaude/claude-memory-slim.md
RUN chmod +x /usr/local/bin/entrypoint.sh \
    /usr/local/bin/bootstrap.sh \
    /usr/local/bin/notify.py

# ---------- s6-overlay service definitions ----------
COPY s6-overlay/s6-rc.d/cloudcli/type /etc/s6-overlay/s6-rc.d/cloudcli/type
COPY s6-overlay/s6-rc.d/cloudcli/run /etc/s6-overlay/s6-rc.d/cloudcli/run
COPY s6-overlay/s6-rc.d/xvfb/type /etc/s6-overlay/s6-rc.d/xvfb/type
COPY s6-overlay/s6-rc.d/xvfb/run /etc/s6-overlay/s6-rc.d/xvfb/run
RUN chmod +x /etc/s6-overlay/s6-rc.d/cloudcli/run \
    /etc/s6-overlay/s6-rc.d/xvfb/run && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/cloudcli && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/xvfb

# ---------- Working directory ----------
WORKDIR /workspace

# ---------- Health check ----------
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -sf http://localhost:3001/ || exit 1

# ---------- s6-overlay as PID 1 ----------
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
