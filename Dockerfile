FROM runzhliu/deepseek-harness:0.2.2-rc.3-r1-market.1

USER root

COPY apt/debian.sources /etc/apt/sources.list.d/debian.sources
COPY apt/debian-security.sources /etc/apt/sources.list.d/debian-security.sources
COPY apt/99mirror.conf /etc/apt/apt.conf.d/99mirror.conf
COPY config/pip.conf /etc/pip.conf
COPY config/npmrc /etc/npmrc

RUN chmod 0644 /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian-security.sources /etc/apt/apt.conf.d/99mirror.conf /etc/pip.conf /etc/npmrc

ENV HOME=/home/node \
    DSH_HOME=/home/node/.dsh \
    PIP_CONFIG_FILE=/etc/pip.conf \
    PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/ \
    NPM_CONFIG_REGISTRY=https://registry.npmmirror.com \
    npm_config_registry=https://registry.npmmirror.com \
    COREPACK_NPM_REGISTRY=https://registry.npmmirror.com \
    GOPROXY=https://goproxy.cn,direct \
    GOSUMDB=sum.golang.google.cn \
    GOPATH=/home/node/go \
    GOMODCACHE=/home/node/go/pkg/mod \
    GOROOT=/usr/local/go \
    BUN_INSTALL=/usr/local/bun \
    PATH=/usr/local/go/bin:/home/node/.local/bin:/home/node/.local/share/pnpm:$PATH

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends python3-pip; \
    rm -rf /var/lib/apt/lists/*; \
    curl -fsSL --retry 3 -o /tmp/bun.zip https://registry.npmmirror.com/-/binary/bun/bun-v1.4.4/bun-linux-x64.zip; \
    unzip -q /tmp/bun.zip -d /tmp; \
    install -m 0755 /tmp/bun-linux-x64/bun /usr/local/bin/bun; \
    ln -s bun /usr/local/bin/bunx; \
    curl -fsSL --retry 3 -o /tmp/go.tgz https://mirrors.aliyun.com/golang/go1.27.4.linux-amd64.tar.gz; \
    echo '7226736c2339719cda28fbf3a54d71aa63bcefe376e98cef00034268dab24840  /tmp/go.tgz' | sha256sum -c -; \
    tar -xzf /tmp/go.tgz -C /usr/local; \
    curl -fsSL --retry 3 -o /tmp/gh.tgz https://github.com/cli/cli/releases/download/v2.104.0/gh_2.104.0_linux_amd64.tar.gz; \
    echo '98cb101ad87dbbd3f6b2f2bfcbd43197ccd07643140121d8a9cfaa91eadbc24e  /tmp/gh.tgz' | sha256sum -c -; \
    tar -xzf /tmp/gh.tgz -C /tmp; \
    install -m 0755 /tmp/gh_2.104.0_linux_amd64/bin/gh /usr/local/bin/gh; \
    npm install -g cf@1.0.0-beta.32 --no-audit --no-fund; \
    mkdir -p /home/node/.dsh /home/node/go /home/node/.cache /workspace; \
    chown -R node:node /home/node /workspace; \
    rm -rf /tmp/bun* /tmp/go.tgz /tmp/gh*; \
    node --version; \
    npm --version; \
    pnpm --version; \
    python3 --version; \
    pip3 --version; \
    bun --version; \
    go version; \
    gh --version; \
    cf --version; \
    test "$(npm config get registry)" = https://registry.npmmirror.com; \
    test "$(pnpm config get registry)" = https://registry.npmmirror.com; \
    test "$(go env GOPROXY)" = https://goproxy.cn,direct

# 浏览器自动化覆盖层：把镜像自带的 attach 独占挂载改成每会话 launch，理由见文件内注释。
# 由 compose 作为第二个 --patch 传入；仓库根没挂载进容器，所以必须留在镜像里。
COPY config/browser-launch.patch.yml /opt/deepseek-harness/browser-launch.patch.yml

RUN chmod 0644 /opt/deepseek-harness/browser-launch.patch.yml

USER node
WORKDIR /workspace
