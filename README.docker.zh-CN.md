# cc-connect + Codex CLI Docker 部署（Windows）

本方案将 `cc-connect` 和 `@openai/codex` 安装在同一个容器中运行，并让 Codex 直接操作你挂载进容器的本地项目目录。

## 1. 准备

1. 安装 Docker Desktop（Windows，建议 WSL2 backend）。
2. 在项目根目录复制环境变量模板：

```powershell
Copy-Item .env.example .env
```

3. 编辑 `.env`，至少设置：
- `HOST_PROJECT_DIR`：你要让 Codex 访问的 Windows 本地项目目录（用正斜杠，如 `D:/project_magic/cc-connect`）
- `HOST_CODEX_HOME`：你本机已有 Codex 配置目录（如 `C:/Users/63576/.codex`）
- `OPENAI_API_KEY`

## 2. 配置 cc-connect

默认配置文件是：

`docker-data/cc-connect/config.toml`

如果该文件不存在，可先复制模板：

```powershell
Copy-Item docker-data/cc-connect/config.toml.example docker-data/cc-connect/config.toml
```

已预置：
- `projects.agent.type = "codex"`
- `work_dir = "/workspace/project"`
- `codex_home = "/root/.codex"`

注意：模板里 Feishu `app_id/app_secret` 是占位值。正式使用前请替换为你在飞书开放平台创建应用后拿到的真实值。

## 3. 启动

```powershell
docker compose up -d --build
```

查看日志：

```powershell
docker compose logs -f cc-connect-codex
```

进入容器检查：

```powershell
docker compose exec cc-connect-codex sh
cc-connect --version
codex --version
```

## 4. 目录与持久化（已复用本地 Codex）

- 容器内配置目录：`/root/.cc-connect`（映射到 `./docker-data/cc-connect`）
- 容器内 Codex 目录：`/root/.codex`（映射到 `HOST_CODEX_HOME`）
- 容器内项目目录：`/workspace/project`（映射到 `HOST_PROJECT_DIR`）

说明：
- 现在容器会直接读写你本机的 `.codex`，因此配置、登录态、会话历史可直接复用。
- 不建议本机 Codex 与容器 Codex 同时高频写入同一目录，避免状态冲突。
