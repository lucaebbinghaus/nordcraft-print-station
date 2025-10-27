# syntax=docker/dockerfile:1.7
FROM oven/bun:1.2.2-alpine AS build
WORKDIR /app
COPY . .
RUN bun install --frozen-lockfile
RUN bun run build
RUN bun build --compile "packages/backend/src/bun.index.ts" --outfile dist/nordcraft
RUN chmod +x dist/nordcraft
RUN mkdir -p dist && bun build --compile "packages/backend/src/bun.index.ts" --outfile dist/nordcraft


FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=build /app/dist /app/dist
ENV NORDCRAFT_PROJECT_DIR=/app/dist/__project__
ENV PORT=12345
EXPOSE 12345
USER 65532:65532
ENTRYPOINT ["/app/dist/nordcraft"]
