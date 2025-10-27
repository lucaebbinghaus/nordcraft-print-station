cat > Dockerfile <<'EOF'
# syntax=docker/dockerfile:1.7
FROM oven/bun:1.2.2 AS build
WORKDIR /app
ARG ENTRY=packages/backend/src/bun.index.ts
ENV NODE_ENV=production

COPY . .
RUN bun install --frozen-lockfile
RUN bun run build
RUN bun packages/backend/bin/syncStaticAssets.ts
RUN mkdir -p dist && cp -r packages/backend/dist/* dist/ || true
RUN bun build --compile "$ENTRY" --outfile dist/nordcraft
RUN chmod +x dist/nordcraft
RUN mkdir -p dist/__project__ && cp -r packages/backend/__project__/* dist/__project__/ || true

FROM gcr.io/distroless/base-debian12
WORKDIR /app/dist
COPY --from=build /app/dist /app/dist
ENV NORDCRAFT_PROJECT_DIR=/app/dist/__project__
ENV NODE_ENV=production
ENV PORT=12345
EXPOSE 12345
USER 65532:65532
ENTRYPOINT ["./nordcraft"]
EOF
