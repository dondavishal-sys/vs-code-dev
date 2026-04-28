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

# Copy entire source
COPY . .

# Install root dependencies without postinstall (it tries to install test dirs we don't need)
RUN npm install --ignore-scripts

# Manually install only the subdirectories needed for the server
RUN cd build && npm install --ignore-scripts
RUN cd remote && npm install
RUN cd remote/web && npm install

# Compile the project
RUN npm run compile

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
CMD ["node", "out/server-main.js", "--port", "8080", "--host", "0.0.0.0", "--without-connection-token"]
