# REA (Reverse Engineer Anything, npm rea-agents) for hosts without Node. Built locally by ../rea on first use.
#   target "base"   : Node 26 + REA + procps (static JavaScript/Electron, .NET, Go, Rust, WASM, SQLite, packages)
#   target "native" : base + JDK 27 + Ghidra 12.2 (native decompilation) + jadx-headless-mcp 0.8.0 (Android APKs)
# Every download is pinned and checked against its SHA-256. Bump the ARGs (and the hashes) to update.
ARG NODE_IMAGE=node:26-bookworm-slim

FROM ${NODE_IMAGE} AS base
ARG REA_VERSION=6.8.0
RUN apt-get update \
 && apt-get install -y --no-install-recommends procps ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && npm install --global --no-audit --no-fund "rea-agents@${REA_VERSION}" \
 && npm cache clean --force
ENTRYPOINT ["rea"]

FROM eclipse-temurin:27-jdk AS jdk

FROM base AS native
ARG GHIDRA_URL=https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.2_build/ghidra_12.2_PUBLIC_20261016.zip
ARG GHIDRA_SHA256=2c2cd776db3c1f6a097ba418922378ac3649cadd5e844a6f5f088ae628a7be67
ARG JADX_URL=https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.8.0/jadx-headless-mcp-0.8.0-all.jar
ARG JADX_SHA256=4b9a01c23845c123c217840182d2b5f2c26a7ca20dec3d08810b310fc80a2372
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk
ENV JAVA_HOME=/opt/java/openjdk \
    PATH=/opt/java/openjdk/bin:$PATH \
    GHIDRA_INSTALL_DIR=/opt/ghidra \
    REA_JADX_MCP_JAR=/opt/jadx/jadx-headless-mcp-0.8.0-all.jar \
    JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=60
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl unzip \
 && curl -fsSL -o /tmp/ghidra.zip "$GHIDRA_URL" \
 && echo "$GHIDRA_SHA256  /tmp/ghidra.zip" | sha256sum -c - \
 && unzip -q /tmp/ghidra.zip -d /opt \
 && mv /opt/ghidra_*_PUBLIC /opt/ghidra \
 && rm /tmp/ghidra.zip \
 && mkdir -p /opt/jadx \
 && curl -fsSL -o "$REA_JADX_MCP_JAR" "$JADX_URL" \
 && echo "$JADX_SHA256  $REA_JADX_MCP_JAR" | sha256sum -c - \
 && apt-get purge -y curl unzip && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*
