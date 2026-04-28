# ============================================
# Stage 1: Build VS Code Server
# ============================================
FROM node:22-bookworm AS builder

# Install all build dependencies needed by native modules
RUN apt-get update && apt-get install -y \
    build-essential \
    g++ \
    libsecret-1-dev \
    libkrb5-dev \
    python3 \
    pkg-config \
    libx11-dev \
    libxkbfile-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /vscode

# Copy full source
COPY . .

# Postinstall needs a git repo (runs git config at the end)
RUN git init && git config user.email "build@docker" && git config user.name "build" && git add -A && git commit -m "docker build"

# Let VS Code's own build system handle everything:
# - Installs root deps
# - Runs postinstall.ts which installs build/, remote/, extensions/*, test/* etc.
RUN npm install

# Compile TypeScript and extension media
RUN npm run compile

# ============================================
# Stage 2: Production Runtime (slim)
# ============================================
FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y \
    libsecret-1-0 \
    libkrb5-3 \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /vscode

# Copy only what the server needs to run
COPY --from=builder /vscode/out ./out
COPY --from=builder /vscode/remote ./remote
COPY --from=builder /vscode/extensions ./extensions
COPY --from=builder /vscode/node_modules ./node_modules
COPY --from=builder /vscode/package.json ./
COPY --from=builder /vscode/product.json ./
COPY --from=builder /vscode/resources ./resources
COPY --from=builder /vscode/.build ./.build

EXPOSE 8080

CMD ["node", "out/server-main.js", "--port", "8080", "--host", "0.0.0.0", "--without-connection-token"]
