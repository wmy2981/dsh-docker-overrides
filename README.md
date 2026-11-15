# DSH Docker 覆盖层

以 `runzhliu/deepseek-harness` market 镜像为基础，仅追加工具链与国内镜像源，保留原镜像的安全与持久化设置，不修改 DSH 源码。

## 文件和数据

所有文件与持久化数据仅位于本仓库目录下（本文以 `/path/to/dsh-docker` 指代），不使用 Docker 命名卷。

- `Dockerfile`：以原始 market 镜像为基础，仅增加工具及配置，不修改 DSH 源码。
- `compose.yaml`：使用本地镜像并保留原镜像的安全与持久化设置。
- `.env.example`：环境变量模板，定义本地镜像名、监听地址、端口和镜像源。
- `.env`：由模板复制而来的本地配置，不进入版本控制。
- `home/`：HOME `/home/node`，包含 CLI 配置、包缓存和 Go 工作缓存。
- `dsh-home/`：DSH_HOME `/home/node/.dsh`，包含会话、凭据、插件、pnpm store 和浏览器数据。
- `workspace/`：独立 Agent 工作区 `/workspace`。
- `apt/`、`config/`：构建时打入本地镜像的镜像源配置。

运行时目录（`home/`、`dsh-home/`、`workspace/`、`backups/`）和 `.env` 均不进入版本控制。

## 工具与镜像源

原镜像已有 Node.js 24.22.3、npm、pnpm 10.15.1、Python 3.13.5。本地镜像新增：

- Bun 1.4.4：npmmirror。
- pip：apt 阿里云镜像。
- ffmpeg 7.1.5（含 ffprobe）与 libavcodec-extra：apt 阿里云镜像。
- pandoc 3.1.11.1：apt 阿里云镜像。
- sqlite3 3.46.1：apt 阿里云镜像。
- Go 1.27.4：阿里云，官方 SHA-256 校验。
- gh 2.104.0：官方最新 Release（部署时），官方 SHA-256 校验。
- cf 1.0.0-beta.32：`npm install -g`，npmmirror。

默认源：

- apt：`https://mirrors.aliyun.com/debian`、`https://mirrors.aliyun.com/debian-security`
- npm / pnpm / Bun：`https://registry.npmmirror.com`
- pip：`https://mirrors.aliyun.com/pypi/simple/`
- Go modules：`https://goproxy.cn,direct`，`sum.golang.google.cn`

本地镜像标签为 `local/deepseek-harness:0.2.2-rc.3-r1-market.1-tools.3`。版本已固定，重启不会自动升级工具。

## 构建与启动

在仓库目录执行：

```bash
cp .env.example .env   # 首次部署，按需修改 DSH_BIND_ADDRESS、端口和镜像源
sudo docker compose --env-file .env build
sudo docker compose --env-file .env up -d --no-build
sudo docker compose ps
sudo docker compose logs --no-color deepseek-harness
```

持久化目录归 UID/GID 1000 所有，目录权限为 0777，容器以镜像原用户 `node` 运行并可完整操作所有挂载目录。普通文件允许组和其他用户读写；只有 DSH 凭据文件强制保留 0600，否则服务拒绝启动。容器保留只读根文件系统、cap_drop ALL、no-new-privileges，不挂载 Docker socket，不使用 privileged。

## 访问与安全

默认按局域网 HTTP 直连设计（示例主机 `192.168.1.100`）：

- Web：`http://192.168.1.100:3081`
- 桌面：`http://192.168.1.100:6081/vnc.html?autoconnect=1`

首次 Web 地址必须使用启动日志中 `dsh web:` 后带 token 的完整 URL。重启后 token 会刷新，需重新获取；登录后的浏览器 Cookie 可以继续使用。不要把 token 发到公共位置。Compose 通过原镜像提供的 `--trusted-host` 信任 `DSH_BIND_ADDRESS`，解决局域网 API / WebSocket 的 403，不修改源码。

此模式无 TLS，noVNC 无额外认证，只允许可信局域网访问，禁止公网转发。DSH token/cookie 校验仍保留，但不替代传输加密或用户级权限隔离。模型和密钥应在 Web 设置页填写，不要写入 `.env`。

## 停止与备份

```bash
sudo docker compose stop
sudo docker compose start
```

不要使用 `docker compose down --volumes`。不要删除 `home/`、`dsh-home/` 或 `workspace/`，除非明确要清除对应数据。升级工具时同步更新 Dockerfile 的版本与校验值，重新构建并重新验证。
