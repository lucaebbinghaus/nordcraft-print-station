# syntax=docker/dockerfile:1.7

########### BUILD (Debian/glibc, Bun 1.2.2) ###########
FROM oven/bun:1.2.2 AS build
WORKDIR /app

# Welcher Entry? (falls nötig beim Build überschreiben)
ARG ENTRY=packages/backend/src/bun.index.ts
ENV NODE_ENV=production

COPY . .

# Abhängigkeiten
RUN bun install --frozen-lockfile

# --- Binary bauen (dist vorher sicher anlegen) ---
RUN mkdir -p dist && bun build --compile "$ENTRY" --outfile dist/nordcraft

# HARTE PRÜFUNG: existiert & ist ausführbar?
RUN test -f dist/nordcraft && chmod +x dist/nordcraft && file dist/nordcraft || (echo "❌ Binary missing"; exit 1)

# --- (optional) Static assets generieren & hochkopieren ---
# Wenn dein Build sie erzeugt:
RUN bun run build || true
RUN bun packages/backend/bin/syncStaticAssets.ts || true
RUN mkdir -p dist && [ -d packages/backend/dist ] && cp -r packages/backend/dist/* dist/ || true

# Projekt-Export ins Image (project.json etc.)
RUN mkdir -p dist/__project__ && cp -r packages/backend/__project__/* dist/__project__/ || true


########### RUNTIME (distroless/glibc) ###########
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

ENTRYPOINT ["./nordcraft"]
