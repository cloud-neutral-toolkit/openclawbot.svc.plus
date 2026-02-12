# ============================================================================
# Stage 1: Builder - Install dependencies and build the application
# ============================================================================
FROM node:22-bookworm AS builder

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# Install optional system packages if specified
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
  fi

# Copy package files for dependency installation
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

# Install dependencies with frozen lockfile
RUN pnpm install --frozen-lockfile

# Copy source code and build
COPY . .
RUN pnpm build

# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# ============================================================================
# Stage 2: Runtime - Minimal production image
# ============================================================================
FROM node:22-bookworm-slim AS runtime

# Install only runtime dependencies
RUN corepack enable && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
  ca-certificates \
  curl && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /app

# Copy package files for production dependencies
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json

# Install production dependencies only
RUN pnpm install --frozen-lockfile --prod

# Copy built artifacts from builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/openclaw.mjs ./openclaw.mjs
COPY --from=builder /app/src ./src
COPY --from=builder /app/extensions ./extensions
COPY --from=builder /app/skills ./skills
# Required by workspace bootstrap/template loader at runtime.
COPY --from=builder /app/docs/reference/templates ./docs/reference/templates

# Copy UI dist if it exists (may not exist if ui:build was skipped)
COPY --from=builder /app/ui ./ui

# Create directory for GCS volume mount
# Cloud Run will mount GCS bucket to /data
# We'll use /data as the state directory for persistent storage
RUN mkdir -p /data && \
  chown -R node:node /data /app

# Set environment variables for production
ENV NODE_ENV=production
ENV OPENCLAW_STATE_DIR=/data

# Security hardening: Run as non-root user (uid 1000)
USER node

# Expose port (Cloud Run will override with PORT env var)
EXPOSE 8080

# Start gateway server for Cloud Run
# - Binds to 0.0.0.0 (lan) to allow external health checks
# - Uses token auth mode explicitly to avoid config drift (e.g. stale password mode in persisted config)
# - Reads PORT from Cloud Run env and defaults to 8080
# - State directory remains /data (GCS mounted volume)
CMD ["sh", "-c", "node openclaw.mjs gateway --bind lan --allow-unconfigured --auth token --port ${PORT:-8080}"]
