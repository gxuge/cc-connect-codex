# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim AS webbuilder

WORKDIR /src/web

RUN npm install -g pnpm

COPY web/package.json web/pnpm-lock.yaml web/pnpm-workspace.yaml web/.pnpmrc.json ./
RUN pnpm install --frozen-lockfile

COPY web/ ./
RUN pnpm run build


FROM golang:1.25-bookworm AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build web assets and embed them into the binary.
COPY --from=webbuilder /src/web/dist /src/web/dist

# Build for the current container platform to avoid exec format mismatch.
RUN CGO_ENABLED=0 \
    go build -o /out/cc-connect ./cmd/cc-connect


FROM node:22-bookworm-slim AS runtime

ARG CODEX_CLI_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @openai/codex@${CODEX_CLI_VERSION} \
    && npm cache clean --force

COPY --from=builder /out/cc-connect /usr/local/bin/cc-connect

ENV CODEX_HOME=/root/.codex
ENV TZ=Asia/Shanghai

RUN mkdir -p /root/.cc-connect /root/.codex /workspace/project

WORKDIR /workspace/project

CMD ["cc-connect", "--config", "/root/.cc-connect/config.toml"]
