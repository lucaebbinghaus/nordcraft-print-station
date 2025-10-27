# syntax=docker/dockerfile:1.7

########### BUILD (Debian/glibc, Bun 1.2.2) ###########
FROM oven/bun:1.2.2 AS build
WORKDIR /app

# Change this at build time if your entry differs
ARG ENTRY=packages/backend/src/bun.index.ts
ENV NODE_ENV=production

COPY . .

# Install deps
RUN bun install --frozen-lockfile

# Build project (optional, safe if present)
RUN bun run build || true

# Generate static assets (optional, safe if present)
RUN bun packages/backend/bin/syncStaticAssets.ts || true

# If backend wrote to packages/backend/dist, lift those files to top-level /app/dist
RUN mkdir -p dist && [ -d packages/backend/dist ] && cp -r packages/backend/dist/* dist/ || true

# Compile standalone binary -> /app/dist/nordcraft
RUN mkdir -p dist \
 && bun build --compile "$ENTRY" --outfile dist/nordcraft \
 && chmod +x dist/nordcraft \
 && echo "✅ Built binary:" && ls -la dist

# Copy project export (__project__) into /app/dist/__project__
RUN mkdir -p dist/__project__ && cp -r packages/backend/__project__/* dist/__project__/ || true

########### RUNTIME (distroless/glibc) ###########
FROM gcr.io/distroless/base-debian12

# Start in /app/dist so relative imports (./routes.js) resolve
WORKDIR /app/dist

COPY --from=build /app/dist /app/dist

ENV NORDCRAFT_PROJECT_DIR=/app/dist/__project__
ENV NODE_ENV=production
ENV PORT=12345

EXPOSE 12345
USER 65532:65532

ENTRYPOINT ["./nordcraft"]
