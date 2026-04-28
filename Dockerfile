# ============================================
# Stage 1: Build VS Code Server
# ============================================
FROM node:22-bookworm AS builder

# Install build dependencies
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

# Copy package files first for better Docker layer caching
COPY package.json package-lock.json .npmrc .nvmrc ./
COPY build/npm/ ./build/npm/

# Install root dependencies
RUN npm install --ignore-scripts
RUN node build/npm/postinstall.ts

# Copy source code
COPY . .

# Compile the project
RUN npm run compile

# Install remote dependencies (needed for server runtime)
WORKDIR /vscode/remote
RUN npm install
WORKDIR /vscode

# ============================================
# Stage 2: Production Runtime
# ============================================
FROM node:22-bookworm-slim

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    libsecret-1-0 \
    libkrb5-3 \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /vscode

# Copy compiled output and necessary files from builder
COPY --from=builder /vscode/out ./out
COPY --from=builder /vscode/remote ./remote
COPY --from=builder /vscode/extensions ./extensions
COPY --from=builder /vscode/node_modules ./node_modules
COPY --from=builder /vscode/package.json ./
COPY --from=builder /vscode/product.json ./
COPY --from=builder /vscode/resources ./resources
COPY --from=builder /vscode/.build ./.build

# Expose the port Render will use
EXPOSE 8080

# Start the VS Code server
# --without-connection-token: no auth token (we handle auth at the LMS level)
# --host 0.0.0.0: listen on all interfaces (required for Docker/Render)
CMD ["node", "out/server-main.js", "--port", "8080", "--host", "0.0.0.0", "--without-connection-token"]
