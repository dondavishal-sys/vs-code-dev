# Single-stage build: VS Code needs many interdependent files at runtime
FROM node:22-bookworm

# Install build + runtime dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    g++ \
    libsecret-1-dev \
    libsecret-1-0 \
    libkrb5-dev \
    libkrb5-3 \
    python3 \
    pkg-config \
    libx11-dev \
    libxkbfile-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /vscode

# Copy full source
COPY . .

# Postinstall needs a git repo
RUN git init && git config user.email "build@docker" && git config user.name "build" && git add -A && git commit -m "docker build"

# Full install with postinstall
RUN npm install

# Compile server + client
RUN npm run compile

EXPOSE 8080

# Run in dev mode (same as ./scripts/code-server.sh does locally)
ENV NODE_ENV=development
ENV VSCODE_DEV=1

CMD ["node", "out/server-main.js", "--port", "8080", "--host", "0.0.0.0", "--without-connection-token"]
