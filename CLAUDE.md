# CLAUDE.md

## 这是什么

在宿主机上用 Docker 部署 DSH（DeepSeek）的覆盖层工程：以 `runzhliu/deepseek-harness` market 镜像为基础加装工具和国内镜像源，**不修改 DSH 源码**。容器名 `dsh`，以 UID/GID 1000 的用户 `node` 运行。

本机具体路径、IP、SSH 别名写在 `CLAUDE.local.md`，本文只描述与机器无关的规则。

## 路径对照


| 用途                               | 宿主机           | 容器内                                        |
| ---------------------------------- | ---------------- | --------------------------------------------- |
| 仓库根                             | 本仓库所在目录   | 未挂载                                        |
| `home/`、`dsh-home/`、`workspace/` | 仓库根下同名目录 | `/home/node`、`/home/node/.dsh`、`/workspace` |

宿主机上 UID 1000 可能显示为其他用户名，容器内同一 UID 是 `node`，不是两套权限。仓库根不在容器挂载范围内，容器内改不到 Dockerfile / compose.yaml / .env。

## 命令

容器内没有 docker，所有 docker 命令必须在宿主机上（仓库目录内）执行：

```bash
sudo docker compose --env-file .env config      # 语法与变量检查，最快的校验
sudo docker compose --env-file .env build
sudo docker compose --env-file .env up -d --no-build
sudo docker compose logs --no-color deepseek-harness
```

首次部署或 `.env` 缺失时先 `cp .env.example .env` 并改 `DSH_BIND_ADDRESS`。

验收标准（三项都要过，URL 中的主机换成 `DSH_BIND_ADDRESS`）：

```bash
sudo docker compose --env-file .env config >/dev/null && echo OK
curl -s -o /dev/null -w '%{http_code}\n' http://192.168.1.100:3081/         # 期望 401
curl -s -o /dev/null -w '%{http_code}\n' http://192.168.1.100:6081/vnc.html # 期望 200
```

`401` 是正常的：Web 首页未带 token 就返回 401。重启后 token 会刷新，从日志 `dsh web:` 那一行取带 token 的完整 URL；token 不要贴到对话或日志里。

## 必须遵守的约束

- **容器根文件系统只读**：容器内装不了工具（`/opt`、`/usr`、`/etc` 只读，无 sudo、无 Docker socket、无 systemd）。新增工具只能改 `Dockerfile` 后重建镜像。
- **版本固定**：所有工具版本硬编码在 `Dockerfile`，Go 与 gh 用 `sha256sum -c` 校验，重启不会自动升级。升级时同步改版本号、SHA-256、`.env` 的 `LOCAL_IMAGE` 标签和 `Dockerfile` 首行 `FROM`，再重建。
- **凭据文件权限**：`dsh-home/.credentials.yaml` 必须是 `0600`，否则服务拒绝启动。持久化目录按 UID/GID 1000 归属、`dsh-home` 为 `700`、`home`/`workspace` 为 `0777` 是刻意设置，不要改成"更整洁"的权限。
- **数据目录**：不要 `docker compose down --volumes`，不要删除 `home/`、`dsh-home/`、`workspace/`，它们就是全部持久化数据（没有 Docker 命名卷）。
- **`--trusted-host ${DSH_BIND_ADDRESS}`**：compose 靠它放行局域网 API/WebSocket，去掉会 403。它是原镜像参数，不要改源码解决。
- **XDG 变量**：compose 用的是 `DSH_XDG_*` 前缀（见 `.env.example` 注释），因为 compose 会优先读取宿主同名 `XDG_*` 变量。基础镜像默认把 XDG 目录放 `/tmp`（重启即失），必须留在 `$HOME` 下。
- **模型与密钥在 Web 设置页填写**，不要写入 `.env`。`.env`、`CLAUDE.local.md` 和运行时目录都在 `.gitignore` 里，提交前确认没有把真实 IP、token 或凭据带进仓库。

## 运行时配置

改 DSH 插件/服务配置改 `dsh-home/profiles/web/cordis.patch.yml`，**不要**改同目录的 `cordis.yml`（它只是空根，注释已说明）。`dsh-home/profiles/web/package.json` 的 `dsh.profile.bundles` 决定加载哪些 bundle/插件。

镜像内的 `/opt/deepseek-harness/web.cordis.patch.yml` 由 compose 的 `--patch` 传入，不在本仓库里，改动只能通过重建镜像。

`config/browser-launch.patch.yml` 由 Dockerfile 复制到 `/opt/deepseek-harness/`，compose 把它作为第二个 `--patch` 排在镜像那个之后，用同一个 id 覆盖浏览器自动化配置（镜像默认是 attach 接 VNC 桌面浏览器的独占模式，一个会话占住后其它会话拿不到浏览器工具）。改这个文件也要重建镜像。

## 历史备份

`backups/` 是历史备份，原样保留。
