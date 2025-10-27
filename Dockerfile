# im Repo-Root:
cat > Dockerfile <<'EOF'
# syntax=docker/dockerfile:1.7

# -------------------
# BUILD (Debian/glibc, kompatibel mit distroless)
# -------------------
FROM oven/bun:1.2.2 AS build
WORKDIR /app

# Entry kann auf preview/index angepasst werden:
ARG ENTRY=packages/backend/src/bun.index.ts
ENV NODE_ENV=production

# Code rein
COPY . .

# Dependencies & Build
RUN bun install --frozen-lockfile
RUN bun run build

# Static assets wirklich generieren (erzeugt routes.js/project.js in packages/backend/dist)
RUN bun packages/backend/bin/syncStaticAssets.ts

# Backend-/dist → top-level dist heben (Binary sucht dort)
RUN mkdir -p dist && cp -r packages/backend/dist/* dist/ || true

# Standalone Binary bauen (glibc)
RUN bun build --compile "$ENTRY" --outfile dist/nordcraft
RUN chmod +x dist/nordcraft

# Projekt-Export (__project__) ins dist legen
RUN mkdir -p dist/__project__ && cp -r packages/backend/__project__/* dist/__project__/ || true

# Fallback: falls routes.js / project.js noch fehlen, aus JSONs generieren
RUN test -f dist/routes.js || ( \
  echo 'const u=new URL("./__project__/route.json", import.meta.url);'      >  dist/routes.js && \
  echo 'export default await Bun.file(u).json();'                           >> dist/routes.js \
)
RUN test -f dist/project.js || ( \
  echo 'const u=new URL("./__project__/project.json", import.meta.url);'    >  dist/project.js && \
  echo 'const j=await Bun.file(u).json();'                                  >> dist/project.js && \
  echo 'export default (j.project ?? j);'                                   >> dist/project.js \
)

# -------------------
# RUNTIME (distroless/glibc)
# -------------------
FROM gcr.io/distroless/base-debian12

# WICHTIG: im dist-Ordner starten, damit ./routes.js relativ gefunden wird
WORKDIR /app/dist

# Artefakte übernehmen
COPY --from=build /app/dist /app/dist

ENV NORDCRAFT_PROJECT_DIR=/app/dist/__project__
ENV NODE_ENV=production
ENV PORT=12345

EXPOSE 12345
USER 65532:65532

# relativ starten (./nordcraft), damit relative Importe funktionieren
ENTRYPOINT ["./nordcraft"]
EOF
