# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim AS webbuilder

WORKDIR /src/web

RUN npm install -g pnpm

COPY web/package.json web/pnpm-lock.yaml web/pnpm-workspace.yaml web/.pnpmrc.json ./
RUN pnpm install --frozen-lockfile --allow-build=esbuild

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

FROM docker:28-cli AS dockercli

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
COPY --from=dockercli /usr/local/bin/docker /usr/bin/docker
COPY --from=dockercli /usr/local/libexec/docker/cli-plugins/ /usr/libexec/docker/cli-plugins/

# Keep docker discoverable in both standard and /usr/local paths.
RUN ln -sf /usr/bin/docker /usr/local/bin/docker \
    && mkdir -p /usr/local/libexec/docker/cli-plugins \
    && ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose

ENV CODEX_HOME=/root/.codex
ENV TZ=Asia/Shanghai
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN mkdir -p /root/.cc-connect /root/.codex /workspace/project

WORKDIR /workspace/project

CMD ["cc-connect", "--config", "/root/.cc-connect/config.toml"]
