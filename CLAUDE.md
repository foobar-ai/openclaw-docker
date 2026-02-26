# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 沟通约定
- 默认使用中文回复与提交说明。

## 仓库定位
- 这是一个 **Docker 打包/部署仓库**，目标是构建并运行集成了 OpenClaw Gateway 与中国 IM 插件（飞书/钉钉/QQ/企微）的镜像。
- 根目录没有常规应用源码与测试工程（无根 `package.json`、无单元测试框架）；核心逻辑在容器构建与启动脚本。

## 常用命令

### 本地启动与调试
```bash
cp .env.example .env
# 编辑 .env，至少填写 MODEL_ID / BASE_URL / API_KEY / API_PROTOCOL / CONTEXT_WINDOW / MAX_TOKENS

docker compose up -d
docker compose logs -f openclaw-gateway
docker compose restart
docker compose down
```

### 构建镜像
```bash
docker build -t justlikemaki/openclaw-docker-cn-im:latest .
```

### 进入容器排查
```bash
docker compose exec openclaw-gateway /bin/bash
openclaw --version
openclaw --help
```

### 校验（替代 lint/test）
```bash
docker compose config
bash -n init.sh push-to-dockerhub.sh push-to-ghcr.sh
```

### 测试说明（关键）
- 仓库当前没有可直接执行的单元测试/集成测试命令，因此不存在“运行单个测试用例”的命令。
- 变更后的最小验证方式：
```bash
docker compose up -d --build
docker compose logs -f openclaw-gateway
```
- 如需“单项验证”，通常以单个检查命令代替（例如只验证入口可执行）：
```bash
docker compose exec openclaw-gateway openclaw --help
```

### 发布相关
```bash
./push-to-dockerhub.sh [version]
./push-to-ghcr.sh [version]
```
- CI 工作流 `.github/workflows/docker-build-push.yml` 会在 `main/master` 分支的 `version.txt` 变更时自动构建并推送 Docker Hub 与 GHCR。

## 高层架构（Big Picture）

### 1) 构建层（Dockerfile）
- 基础镜像：`node:22-slim`。
- 镜像内安装 OpenClaw、OpenCode AI、Playwright、Bun、qmd 及各 IM 插件依赖。
- `ENTRYPOINT` 指向 `init.sh`，实际运行流程由初始化脚本控制。

### 2) 编排层（docker-compose.yml）
- 单服务：`openclaw-gateway`。
- 通过 `.env` 注入模型参数、网关参数、各渠道密钥。
- 卷策略：
  - `${OPENCLAW_DATA_DIR}:/home/node/.openclaw` 持久化数据。
  - `/home/node/.openclaw/extensions` 使用匿名卷，优先保留镜像预装插件形态。
- 默认 `user: ${OPENCLAW_RUN_USER:-0:0}`，允许入口脚本先用 root 修复权限，再降权运行。

### 3) 启动层（init.sh）
启动时序（核心）：
1. 创建并检查 `~/.openclaw` 与工作目录。
2. 若当前为 root，先做挂载目录 owner/写权限修复与诊断输出。
3. 若 `openclaw.json` 不存在，生成基础骨架。
4. 通过内嵌 Python 按环境变量“声明式同步”配置到 `openclaw.json`：
   - 模型提供方与默认模型
   - workspace/memory 路径
   - 各渠道启用状态与参数
   - gateway bind/port/token
5. `gosu node` 降权启动：`openclaw gateway run ...`。
6. 通过 `trap` 处理 SIGTERM/SIGINT/SIGQUIT，实现容器优雅退出。

### 4) 配置模型
- `.env.example`：运行时参数源。
- `openclaw.json.example`：目标配置结构参考（models/agents/channels/gateway/plugins）。
- 实际运行以 `init.sh` 同步后的 `~/.openclaw/openclaw.json` 为准。

## 关键文件
- `Dockerfile`：镜像构建与预装组件。
- `docker-compose.yml`：运行编排、端口、挂载、环境变量透传。
- `init.sh`：容器入口、权限修复、配置同步、网关启动。
- `.env.example`：环境变量模板。
- `openclaw.json.example`：OpenClaw 配置示例结构。
- `.github/workflows/docker-build-push.yml`：版本触发的镜像构建发布流水线。
- `README.md`：部署与参数说明主文档。

## 规则文件状态
- 未发现 `.cursor/rules/`、`.cursorrules`、`.github/copilot-instructions.md`。
- 已存在 `AGENTS.md`，内容与本文件一致方向（仓库是打包部署导向、以构建+启动日志作为主要验证手段）。
