#!/bin/sh
# 把 DSH Web 的「带 token 可访问地址」通过 Gotify 推送。
#
# 容器每次启动都会打印一行（token 每个进程重新生成）：
#   dsh web: http://127.0.0.1:3080/?token=xxxx
# 本脚本从日志里取这一行，把内部监听地址改写成本机对外访问的
# http://<DSH_BIND_ADDRESS>:<DSH_PORT>/?token=xxxx 再推送；
# 同一个 token 只推一次，宿主 cron 定时调用即可做到「一起来就收到链接」。
#
# 凭据不写在仓库里：GOTIFY_URL / GOTIFY_APP_TOKEN 由环境变量提供，
# 或写进仓库根的 .env（已被 .gitignore 排除）；DSH_BIND_ADDRESS /
# DSH_PORT 复用 compose 的 .env，保证推出去的地址和实际映射一致。
#
# 用法：sh scripts/notify-web-url.sh [--force]
#   --force  忽略去重状态，强制再推一次（换手机/丢了消息时用）
# 环境变量：
#   GOTIFY_URL / GOTIFY_APP_TOKEN  必填，Gotify 地址与应用 token
#   DSH_BIND_ADDRESS / DSH_PORT    必填，对外访问的 IP 与端口
#   DSH_CONTAINER_NAME             可选，容器名，默认 dsh
#   DSH_WEB_URL_STATE_DIR          可选，去重状态目录，默认 <仓库根>/.state
#   DOCKER_BIN                     可选，docker 可执行文件，默认 docker

set -eu

force=0
case "${1:-}" in
	--force) force=1 ;;
	-h | --help)
		sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	"") ;;
	*)
		echo "未知参数：$1" >&2
		exit 2
		;;
esac

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname -- "$script_dir")

# 从 .env 取需要的四项：按 key=value 解析，不执行文件内容，也兼容 CRLF 行尾。
dotenv() {
	[ -f "$repo_dir/.env" ] || return 0
	sed -n "s/^$1=//p" "$repo_dir/.env" | tail -n 1 | tr -d '\r'
}
GOTIFY_URL=${GOTIFY_URL:-$(dotenv GOTIFY_URL)}
GOTIFY_APP_TOKEN=${GOTIFY_APP_TOKEN:-$(dotenv GOTIFY_APP_TOKEN)}
DSH_BIND_ADDRESS=${DSH_BIND_ADDRESS:-$(dotenv DSH_BIND_ADDRESS)}
DSH_PORT=${DSH_PORT:-$(dotenv DSH_PORT)}

if [ -z "${GOTIFY_URL:-}" ] || [ -z "${GOTIFY_APP_TOKEN:-}" ] ||
	[ -z "${DSH_BIND_ADDRESS:-}" ] || [ -z "${DSH_PORT:-}" ]; then
	echo "缺少环境变量：需要 GOTIFY_URL、GOTIFY_APP_TOKEN、DSH_BIND_ADDRESS、DSH_PORT" >&2
	exit 1
fi

container=${DSH_CONTAINER_NAME:-dsh}
state_dir=${DSH_WEB_URL_STATE_DIR:-$repo_dir/.state}
: "${DOCKER_BIN:=docker}"

started_at=$("$DOCKER_BIN" inspect --format '{{.State.StartedAt}}' "$container" 2>/dev/null) || exit 0

line=$("$DOCKER_BIN" logs --since "$started_at" "$container" 2>&1 |
	grep -F 'dsh web: http' | tail -n 1 || true)
[ -n "$line" ] || exit 0

token=$(printf '%s\n' "$line" | sed -n 's/.*token=\([A-Za-z0-9._-]*\).*/\1/p')
if [ -z "$token" ]; then
	echo "日志里没解析出 token：$line" >&2
	exit 1
fi

web_url="http://${DSH_BIND_ADDRESS}:${DSH_PORT}/?token=${token}"

state_file="$state_dir/last-web-token"
if [ "$force" -eq 0 ] && [ -f "$state_file" ] && [ "$(cat "$state_file")" = "$token" ]; then
	exit 0
fi

curl -fsS --max-time 15 -X POST "${GOTIFY_URL%/}/message?token=${GOTIFY_APP_TOKEN}" \
	--form-string "title=DSH Web UI 启动地址" \
	--form-string "message=$web_url" \
	--form-string "priority=8" >/dev/null

umask 077
mkdir -p "$state_dir"
printf '%s\n' "$token" >"$state_file"
# 不把带 token 的地址写进日志。
echo "$(date '+%F %T') 已推送启动地址（容器启动于 $started_at）"
