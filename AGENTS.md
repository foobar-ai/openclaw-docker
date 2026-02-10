# AGENTS.md（给仓库内的 Agent/自动化编程助手）

> 目标：让新来的 agent 在 5 分钟内拿到“怎么启动/怎么构建/怎么验证/怎么改”的最小闭环。
> 交互与产出：本仓库面向中文用户，默认用中文沟通与写文档。

## 1) 仓库定位

这是一个 **Docker 打包/部署仓库**：构建包含 OpenClaw Gateway + 中国 IM 插件的镜像，并提供 Compose 与启动初始化脚本。

- 主要文件类型：`Dockerfile`、`docker-compose.yml`、`*.sh`、示例配置（`.env.example`, `openclaw.json.example`）
- 重要事实：仓库里**没有**传统应用源码/依赖管理（根目录无 `package.json`），也**没有**测试框架与单测。

关键入口：
- 容器入口：`init.sh`（`Dockerfile` 的 `ENTRYPOINT`）
- Compose 服务：`openclaw-gateway`（见 `docker-compose.yml`）

## 2) 初始化（本地最小可运行）

依据：`README.md`、`.env.example`。

```bash
cp .env.example .env
nano .env  # 至少配置 MODEL_ID/BASE_URL/API_KEY/API_PROTOCOL/CONTEXT_WINDOW/MAX_TOKENS

docker-compose up -d
docker-compose logs -f
```

进容器排查：

```bash
docker compose exec openclaw-gateway /bin/bash
```

## 3) Build / Lint / Test（含“单测”）

### 3.1 Build（构建镜像）

```bash
docker build -t justlikemaki/openclaw-docker-cn-im:latest .
```

### 3.2 Run（运行/重启/停止）

```bash
docker-compose up -d
docker-compose restart
docker-compose down
docker-compose logs -f
```

### 3.3 Test（结论：无单测；用 smoke check）

仓库当前**没有**可运行的测试套件，因此：
- 不存在“运行单个测试”的命令
- 交付验证以 **构建 + 启动 + 观察日志** 为主：

```bash
docker-compose up -d --build
docker-compose logs -f openclaw-gateway

docker compose exec openclaw-gateway /bin/bash
openclaw --help
```

可选的“类 lint”检查（不引入新依赖时）：

```bash
docker compose config  # 验证 compose 插值/语法
bash -n init.sh push-to-dockerhub.sh push-to-ghcr.sh  # Bash 语法检查
```

### 3.4 发布（交互式脚本）

```bash
./push-to-dockerhub.sh [version]
./push-to-ghcr.sh [version]
```

### 3.5 CI

`.github/workflows/docker-build-push.yml`：当 `version.txt` 在 `main/master` 变更时自动构建并推送（Docker Hub + GHCR）。

## 4) 变更点速览（按此对齐约定）

- `Dockerfile`
  - `node:22-slim` 基础镜像；安装 `openclaw`/`opencode-ai`/`playwright` 等
  - 插件安装用 `timeout ... || true`（网络不稳时避免卡死）
  - `ENTRYPOINT` 指向 `init.sh`

- `docker-compose.yml`
  - `user: ${OPENCLAW_RUN_USER:-0:0}`：默认 root 起容器，便于 `init.sh` 修复挂载卷权限，再降权运行
  - 挂载：`${OPENCLAW_DATA_DIR}:/home/node/.openclaw`
  - 排除：`/home/node/.openclaw/extensions` 用匿名卷，保证使用镜像内预装插件

- `init.sh`
  - `set -e`；root 时做挂载目录写权限预检/修复（失败输出可执行的修复命令）
  - 若 `openclaw.json` 不存在则生成；随后 `gosu node openclaw gateway --verbose`
  - `trap` 捕获 SIGTERM/SIGINT/SIGQUIT 做优雅退出

## 5) 代码风格/约定（仓库以脚本与配置为主）

### 5.1 通用

- 小改动优先，**不要顺手重构**（打包仓库最怕行为漂移）。
- 任何改动后，至少跑一次：`docker-compose up -d --build` 并看日志。

### 5.2 Bash（`init.sh`, `push-to-*.sh`）

- 统一：`#!/bin/bash` + `set -e`
- 变量：环境变量/常量偏好全大写（例：`OPENCLAW_HOME`, `MODEL_ID`）
- 引号：变量展开用双引号（`"$VAR"`）避免空格/通配符坑
- 容错：只有“可接受失败”的地方才用 `|| true`，并在输出里说明原因/补救方式
- 错误信息要可操作（`init.sh` 的权限诊断是范例）

### 5.3 YAML / JSON / Env

- `docker-compose.yml`：`${VAR}` / `${VAR:-default}`；端口映射保持字符串（如 `"${PORT}:18789"`）
- JSON（`openclaw.json.example` 风格）：2 空格缩进、双引号、无尾逗号、camelCase key
- `.env(.example)`：`UPPER_SNAKE_CASE`；按域分组（`MODEL_`/`API_`/`OPENCLAW_`/各 IM 前缀）

### 5.4 关于 imports / types

仓库几乎没有 TS/Python/Go/Rust 源码：没有通用的 import 顺序与类型系统约定；新增代码请优先遵循该语言的社区默认风格，并保持与现有文件一致。

## 6) 安全与敏感信息（强约束）

- 不要把真实密钥写入可追踪文件；尤其是 `.env`、任何示例配置、README 片段。
- `.opencode/` 目录在 `.gitignore` 中；但本地可能包含真实 `apiKey`（见 `.opencode/opencode.jsonc`）。
- 若你生成示例配置：用占位符（`your-api-key` / `sk-***`），不要回显真实 token。

## 7) Cursor / Copilot 规则

当前未发现：
- `.cursor/rules/` 或 `.cursorrules`
- `.github/copilot-instructions.md`

若未来新增上述规则文件，本 AGENTS.md 必须同步更新并引用其路径。

## 8) 变更策略

- 修复类改动：倾向“最小行为改动”，避免同时做重构。
- 发布相关：CI 以 `version.txt` 作为触发点；调整版本/镜像标签时保持一致。
