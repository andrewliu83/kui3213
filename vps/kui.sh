#!/bin/sh

set -eu

# ==========================================
# KUI Serverless 集群节点 - 智能跨系统安装脚本 (工业级加固版)
# 支持: Ubuntu 18-24 / Debian 10-13 / Alpine Linux
# ==========================================

API_URL=""; VPS_IP=""; TOKEN=""; PROXY_API_URL=""; UNINSTALL=0

# Single source of truth for install backup / rollback / uninstall.
# Paths are relative to / so they can be used with tar -C /.
KUI_SERVICES="kui-agent sing-box proxy-lite"
KUI_MANAGED_TREE_PATHS="opt/kui opt/proxy_lite etc/sing-box etc/proxy-lite"
KUI_MANAGED_FILE_PATHS="
etc/systemd/system/kui-agent.service
etc/systemd/system/sing-box.service
etc/systemd/system/proxy-lite.service
lib/systemd/system/proxy-lite.service
etc/init.d/kui-agent
etc/init.d/sing-box
etc/init.d/proxy-lite
etc/conf.d/proxy-lite
etc/sysctl.d/99-proxy-lite.conf
var/log/kui-agent.log
var/log/sing-box.log
var/log/proxy-lite.log
run/kui-agent.pid
run/sing-box.pid
run/proxy-lite.pid
"
# Optional binary install path (backup/rollback only; uninstall leaves system binary in place).
KUI_OPTIONAL_BINARY_PATHS="usr/bin/sing-box"

while [ "$#" -gt 0 ]; do
    case $1 in
        --uninstall) UNINSTALL=1 ;;
        --api) [ "$#" -ge 2 ] || { echo "--api 缺少参数"; exit 1; }; API_URL="$2"; shift ;;
        --ip) [ "$#" -ge 2 ] || { echo "--ip 缺少参数"; exit 1; }; VPS_IP="$2"; shift ;;
        --token) [ "$#" -ge 2 ] || { echo "--token 缺少参数"; exit 1; }; TOKEN="$2"; shift ;;
        --proxy-api) [ "$#" -ge 2 ] || { echo "--proxy-api 缺少参数"; exit 1; }; PROXY_API_URL="$2"; shift ;;
        -h|--help)
            cat <<'USAGE'
用法:
  安装:  ... | bash  -- --api https://... --ip <VPS_IP> --token <TOKEN>
  卸载:  ... | bash  -- --uninstall

--uninstall  停止并移除本机 KUI Agent / sing-box unit / 住宅 proxy-lite 与相关数据
             （保留系统包与 /usr/bin/sing-box 可执行文件；面板库请在面板「彻底移除」）
USAGE
            exit 0
            ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
    shift
done

detect_init_system() {
    if [ -d /run/systemd/system ] && [ "$(cat /proc/1/comm 2>/dev/null || true)" = "systemd" ] && command -v systemctl >/dev/null 2>&1; then echo systemd
    elif [ -x /sbin/openrc-run ] && command -v rc-service >/dev/null 2>&1; then echo openrc
    else echo none; fi
}

stop_kui_services() {
    INIT_SYS="$1"
    if [ "$INIT_SYS" = "systemd" ]; then
        # shellcheck disable=SC2086
        systemctl stop $KUI_SERVICES >/dev/null 2>&1 || true
    elif [ "$INIT_SYS" = "openrc" ]; then
        for svc in $KUI_SERVICES; do
            rc-service "$svc" stop >/dev/null 2>&1 || true
        done
    else
        pkill -f '/opt/kui/run-agent.sh' 2>/dev/null || true
        pkill -f '/opt/kui/agent.py' 2>/dev/null || true
        pkill -f '/opt/proxy_lite/lite_manager.py' 2>/dev/null || true
        pkill -f '/opt/proxy_lite/run-proxy.sh' 2>/dev/null || true
        pkill -f 'sing-box run -c /etc/sing-box/config.json' 2>/dev/null || true
    fi
}

disable_kui_services() {
    INIT_SYS="$1"
    if [ "$INIT_SYS" = "systemd" ]; then
        for svc in $KUI_SERVICES; do
            systemctl disable "$svc" >/dev/null 2>&1 || true
        done
        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl reset-failed >/dev/null 2>&1 || true
    elif [ "$INIT_SYS" = "openrc" ]; then
        for svc in $KUI_SERVICES; do
            rc-update del "$svc" default >/dev/null 2>&1 || true
        done
    fi
}

remove_kui_managed_files() {
    for rel in $KUI_MANAGED_TREE_PATHS; do
        rm -rf "/$rel"
    done
    for rel in $KUI_MANAGED_FILE_PATHS; do
        [ -n "$rel" ] || continue
        rm -f "/$rel"
    done
}

collect_existing_backup_items() {
    items=""
    for rel in $KUI_MANAGED_TREE_PATHS $KUI_MANAGED_FILE_PATHS $KUI_OPTIONAL_BINARY_PATHS; do
        [ -n "$rel" ] || continue
        [ ! -e "/$rel" ] || items="$items $rel"
    done
    echo "$items"
}

uninstall_kui() {
    INIT_SYS=$(detect_init_system)
    echo "=========================================="
    echo " 🧹 卸载 KUI 节点组件 (init=$INIT_SYS)"
    echo "=========================================="

    stop_kui_services "$INIT_SYS"
    disable_kui_services "$INIT_SYS"
    remove_kui_managed_files

    if command -v sing-box >/dev/null 2>&1; then
        echo " 提示: 系统仍保留 sing-box 可执行文件 ($(command -v sing-box))，如需一并删除请手动处理。"
    fi
    if [ "$INIT_SYS" = "none" ]; then
        echo " 提示: 未检测到 systemd/OpenRC，仅做了路径清理与 best-effort 进程结束。"
    fi

    echo "=========================================="
    echo " ✅ 本机 KUI 托管组件清理完成"
    echo " 面板侧请再点「彻底移除」清理数据库记录（若尚未删除）。"
    echo "=========================================="
}

if [ "$UNINSTALL" -eq 1 ]; then
    uninstall_kui
    exit 0
fi

if [ -z "$API_URL" ] || [ -z "$VPS_IP" ] || [ -z "$TOKEN" ]; then
    echo "❌ 错误: 缺少必要参数！安装需要 --api --ip --token；卸载请传 --uninstall"
    exit 1
fi

case "$API_URL" in https://*) ;; *) echo "❌ --api 必须使用 https://"; exit 1 ;; esac
case "$API_URL" in *'@'*|*'#'*) echo "❌ --api 不能包含用户信息或 fragment"; exit 1 ;; esac
if [ -n "$PROXY_API_URL" ]; then
    case "$PROXY_API_URL" in https://*) ;; *) echo "❌ --proxy-api 必须使用 https://"; exit 1 ;; esac
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS="${ID:-}"
else
    echo "❌ 无法识别操作系统，脚本退出。"
    exit 1
fi

case "$OS" in
    alpine|debian|ubuntu) ;;
    *) echo "不支持的发行版: $OS"; exit 1 ;;
esac
INIT_SYS=$(detect_init_system)
[ "$INIT_SYS" != none ] || { echo "❌ 需要正在运行的 systemd 或 OpenRC"; exit 1; }

INSTALL_SUCCESS=0
BACKUP_DIR=$(mktemp -d /tmp/kui-install-backup.XXXXXX)
chmod 700 "$BACKUP_DIR"
BACKUP_ITEMS=$(collect_existing_backup_items)
[ -z "$BACKUP_ITEMS" ] || tar -C / -czf "$BACKUP_DIR/system.tgz" $BACKUP_ITEMS

rollback_install() {
    status=$?
    if [ "$INSTALL_SUCCESS" -ne 1 ]; then
        echo "❌ 安装未完成，正在恢复上一个可用版本..."
        stop_kui_services "$INIT_SYS"
        remove_kui_managed_files
        # install may have replaced binary; always drop managed binary path before restore
        for rel in $KUI_OPTIONAL_BINARY_PATHS; do
            [ -n "$rel" ] || continue
            rm -f "/$rel"
        done
        [ ! -f "$BACKUP_DIR/system.tgz" ] || tar -C / -xzf "$BACKUP_DIR/system.tgz"
        if [ "$INIT_SYS" = "openrc" ]; then
            for svc in $KUI_SERVICES; do
                rc-service "$svc" start >/dev/null 2>&1 || true
            done
        else
            systemctl daemon-reload >/dev/null 2>&1 || true
            # shellcheck disable=SC2086
            systemctl start $KUI_SERVICES >/dev/null 2>&1 || true
        fi
    fi
    rm -rf "$BACKUP_DIR"
    exit "$status"
}
trap rollback_install EXIT INT TERM

echo "=========================================="
echo " 🚀 KUI Agent 智能安装启动中..."
echo " 💻 目标系统: ${OS}"
echo "=========================================="

export CURL_USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"

echo "[1/7] 🧹 正在清理历史残留..."
# Same lifecycle primitives as --uninstall / rollback (without dropping optional binaries yet).
stop_kui_services "$INIT_SYS"
disable_kui_services "$INIT_SYS"
remove_kui_managed_files

echo "[2/7] ⚡ 保留系统现有软件源..."
if [ "$INIT_SYS" = "openrc" ]; then
    :
else
    :
fi

echo "[3/7] 📦 正在安装底层网络依赖..."
ALIYUN_OK=0
if [ "$INIT_SYS" = "openrc" ]; then
    apk update || echo "⚠️ apk update 失败，尝试使用现有缓存安装。"
    apk add python3 py3-websocket-client curl openssl iptables coreutils bash tar libc6-compat gcompat iproute2
else
    if apt-get update -y >/tmp/kui_apt_update.log 2>&1; then
        cat /tmp/kui_apt_update.log
        ALIYUN_OK=1
    else
        cat /tmp/kui_apt_update.log
        echo "⚠️  aliyun 源 apt-get update 失败，回滚到原 sources.list..."
        if [ -f /etc/apt/sources.list.bak ]; then
            mv /etc/apt/sources.list.bak /etc/apt/sources.list
            apt-get update -y || echo "❌ 原 sources.list 也无法更新，请手动检查网络/源配置。"
        else
            echo "❌ 无备份可回滚，请手动修复 /etc/apt/sources.list 或更换镜像源后重试。"
        fi
        exit 1
    fi
    apt-get install -y python3 python3-websocket curl openssl iptables coreutils bash tar iproute2 iputils-ping
fi

echo "[4/7] ⚙️ 部署 Sing-box 代理核心..."
rm -f /usr/bin/sing-box
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) SB_ARCH="amd64" ;;
    aarch64) SB_ARCH="arm64" ;;
    *) echo "不支持的 CPU 架构: $ARCH"; exit 1 ;;
esac
SB_VER="1.13.14"
SB_SUFFIX="linux-${SB_ARCH}-glibc"
[ "$OS" = "alpine" ] && SB_SUFFIX="linux-${SB_ARCH}-musl"
curl -fL --retry 3 -o sing-box.tar.gz -A "$CURL_USER_AGENT" "https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/sing-box-${SB_VER}-${SB_SUFFIX}.tar.gz"
case "$SB_SUFFIX" in
    linux-amd64-glibc) EXPECTED_SHA="aae9172317c61760aae3dafcde889b2e51b7ea590c40d2b3c7ccdeae14b361b6" ;;
    linux-amd64-musl) EXPECTED_SHA="d5b46de6498427bccfeb87dbafcde4dbefdfe35680020d07d286ad915f0bfb34" ;;
    linux-arm64-glibc) EXPECTED_SHA="08d37b2bf12145ec44307333490cecca4c917df054cd8e27a210f8d9cdbe0fd9" ;;
    linux-arm64-musl) EXPECTED_SHA="edec18488af35a93cf8b362063146fdd7b557ef9862710ee77a1f4adb5c70118" ;;
    *) echo "❌ 不支持的 sing-box 构建: $SB_SUFFIX"; exit 1 ;;
esac
ACTUAL_SHA=$(sha256sum sing-box.tar.gz | awk '{print $1}')
[ "$ACTUAL_SHA" = "$EXPECTED_SHA" ] || { echo "❌ sing-box SHA256 校验失败"; exit 1; }
tar -xzf sing-box.tar.gz
test -x "sing-box-${SB_VER}-${SB_SUFFIX}/sing-box"
mv "sing-box-${SB_VER}-${SB_SUFFIX}/sing-box" /usr/bin/
chmod +x /usr/bin/sing-box
rm -rf sing-box.tar.gz "sing-box-${SB_VER}-${SB_SUFFIX}"

echo "[4.5/7] ⚙️ 正在应用网络内核调优（BBR / QUIC / conntrack）..."
if [ "$OS" = "alpine" ]; then
    modprobe -q xt_conntrack 2>/dev/null || true
    sysctl -w net.netfilter.nf_conntrack_max=1048576 >/dev/null 2>&1 || true
else
    cat > /etc/sysctl.d/99-kui-optimize.conf <<'SYSCTL'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 5000
net.netfilter.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_udp_timeout = 60
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
SYSCTL
    sysctl --system >/dev/null 2>&1 || echo "⚠️ 部分内核参数无法应用，继续安装。"
fi

echo "[5/7] 📂 初始化 KUI 工作目录与环境..."
mkdir -p /opt/kui /etc/sing-box
if [ -f "$BACKUP_DIR/system.tgz" ]; then
    for state_file in warp.json egress-state.json traffic-state.json; do
        tar -xOf "$BACKUP_DIR/system.tgz" "opt/kui/$state_file" > "/opt/kui/$state_file" 2>/dev/null || rm -f "/opt/kui/$state_file"
        [ ! -f "/opt/kui/$state_file" ] || chmod 600 "/opt/kui/$state_file"
    done
fi

API_URL="$API_URL" VPS_IP="$VPS_IP" TOKEN="$TOKEN" PROXY_API_URL="${PROXY_API_URL:-}" python3 -c 'import json, os; json.dump({"api_url": os.environ["API_URL"] + "/api/config", "report_url": os.environ["API_URL"] + "/api/report", "ip": os.environ["VPS_IP"], "token": os.environ["TOKEN"], "proxy_api": os.environ["PROXY_API_URL"]}, open("/opt/kui/config.json", "w"))'
chmod 600 /opt/kui/config.json

verify_agent_manifest() {
    component="$1"; file="$2"; headers="$3"
    expected_sha=$(tr -d '\r' < "$headers" | awk '/^[Xx]-[Aa]gent-[Ss][Hh][Aa]256:/ {print tolower($2)}' | tail -n 1)
    version=$(tr -d '\r' < "$headers" | awk '/^[Xx]-[Aa]gent-[Mm]anifest-[Vv]ersion:/ {print $2}' | tail -n 1)
    expected_length=$(tr -d '\r' < "$headers" | awk '/^[Xx]-[Aa]gent-[Ll]ength:/ {print $2}' | tail -n 1)
    supplied_mac=$(tr -d '\r' < "$headers" | awk '/^[Xx]-[Aa]gent-[Mm][Aa][Cc]:/ {print tolower($2)}' | tail -n 1)
    actual_sha=$(sha256sum "$file" | awk '{print $1}')
    actual_length=$(wc -c < "$file" | tr -d ' ')
    expected_mac=$(printf 'v1\n%s\n%s\n%s\n' "$component" "$expected_sha" "$actual_length" | openssl dgst -sha256 -mac HMAC -macopt "key:${TOKEN}" | awk '{print tolower($NF)}')
    [ "$version" = "1" ] && [ "$expected_length" = "$actual_length" ] && [ -n "$expected_sha" ] && [ "$expected_sha" = "$actual_sha" ] && [ -n "$supplied_mac" ] && [ "$supplied_mac" = "$expected_mac" ]
}

echo "正在拉取最新版 Agent 执行器..."
AGENT_URL="${API_URL}/api/agent_update?ip=${VPS_IP}&component=agent"
AGENT_TEMP="/opt/kui/agent.py.download"; AGENT_HEADERS="/opt/kui/agent.py.headers"
curl -fsSL --retry 3 --retry-delay 2 -A "$CURL_USER_AGENT" -D "$AGENT_HEADERS" -H "Authorization: ${TOKEN}" "$AGENT_URL" -o "$AGENT_TEMP"
verify_agent_manifest agent "$AGENT_TEMP" "$AGENT_HEADERS" || { echo "❌ agent.py 更新清单校验失败"; exit 1; }
python3 -m py_compile "$AGENT_TEMP"
mv "$AGENT_TEMP" /opt/kui/agent.py
rm -f "$AGENT_HEADERS"
chmod 700 /opt/kui/agent.py

REALTIME_CLIENT_URL="${API_URL}/api/agent_update?ip=${VPS_IP}&component=realtime-client"
REALTIME_CLIENT_TEMP="/opt/kui/realtime_client.py.download"; REALTIME_CLIENT_HEADERS="/opt/kui/realtime_client.py.headers"
curl -fsSL --retry 3 --retry-delay 2 -A "$CURL_USER_AGENT" -D "$REALTIME_CLIENT_HEADERS" -H "Authorization: ${TOKEN}" "$REALTIME_CLIENT_URL" -o "$REALTIME_CLIENT_TEMP"
verify_agent_manifest realtime-client "$REALTIME_CLIENT_TEMP" "$REALTIME_CLIENT_HEADERS" || { echo "❌ realtime_client.py 更新清单校验失败"; exit 1; }
python3 -m py_compile "$REALTIME_CLIENT_TEMP"
mv "$REALTIME_CLIENT_TEMP" /opt/kui/realtime_client.py
rm -f "$REALTIME_CLIENT_HEADERS"
chmod 700 /opt/kui/realtime_client.py

cat > /opt/kui/run-agent.sh <<'EOF'
#!/bin/sh
set -u
while true; do
    /usr/bin/python3 /opt/kui/agent.py
    status=$?
    if [ -f /opt/kui/.update-pending ]; then
        echo "[launcher] 新版本启动失败，恢复 last-good 组件" >&2
        [ ! -f /opt/kui/agent.py.last-good ] || cp -f /opt/kui/agent.py.last-good /opt/kui/agent.py
        [ ! -f /opt/kui/realtime_client.py.last-good ] || cp -f /opt/kui/realtime_client.py.last-good /opt/kui/realtime_client.py
        rm -f /opt/kui/.update-pending
        continue
    fi
    exit "$status"
done
EOF
chmod 700 /opt/kui/run-agent.sh

echo "[6/7] 🛡️ 智能注册底层守护进程并启动..."
if [ "$OS" = "alpine" ]; then
    cat > /etc/init.d/kui-agent <<EOF
#!/sbin/openrc-run
description="KUI Serverless Agent"
command="/opt/kui/run-agent.sh"
command_args=""
command_background="yes"
pidfile="/run/kui-agent.pid"
output_log="/var/log/kui-agent.log"
error_log="/var/log/kui-agent.log"
depend() { need net; }
EOF
    cat > /etc/init.d/sing-box <<EOF
#!/sbin/openrc-run
description="Sing-box Proxy Service"
command="/usr/bin/sing-box"
command_args="run -c /etc/sing-box/config.json"
command_background="yes"
pidfile="/run/sing-box.pid"
output_log="/var/log/sing-box.log"
error_log="/var/log/sing-box.log"
depend() { need net; after kui-agent; }
EOF
    chmod +x /etc/init.d/kui-agent /etc/init.d/sing-box
    rc-update add kui-agent default
    rc-update add sing-box default
    rc-service kui-agent start
else
    cat > /etc/systemd/system/kui-agent.service <<EOF
[Unit]
Description=KUI Serverless Agent
After=network.target

[Service]
Type=simple
ExecStart=/opt/kui/run-agent.sh
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable kui-agent
    if command -v sing-box >/dev/null 2>&1; then
        if [ ! -f /etc/systemd/system/sing-box.service ]; then
            cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box Proxy Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/sing-box run -c /etc/sing-box/config.json
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
        fi
        systemctl enable sing-box
    fi
    systemctl start kui-agent
fi

echo "[7/7] 🌐 部署住宅 IP 主备双隧道代理..."
PROXY_INSTALLER_URL="${API_URL}/api/agent_update?ip=${VPS_IP}&component=proxy-installer"
PROXY_INSTALLER_TEMP="/opt/kui/residential-proxy.sh.download"; PROXY_INSTALLER_HEADERS="/opt/kui/residential-proxy.sh.headers"
cleanup_proxy_installer() { rm -f "$PROXY_INSTALLER_TEMP" "$PROXY_INSTALLER_HEADERS"; }
curl -fsSL --retry 3 --retry-delay 2 -A "$CURL_USER_AGENT" -D "$PROXY_INSTALLER_HEADERS" -H "Authorization: ${TOKEN}" "$PROXY_INSTALLER_URL" -o "$PROXY_INSTALLER_TEMP"
EXPECTED_INSTALLER_SHA=$(tr -d '\r' < "$PROXY_INSTALLER_HEADERS" | awk '/^[Xx]-[Aa]gent-[Ss][Hh][Aa]256:/ {print tolower($2)}' | tail -n 1)
verify_agent_manifest proxy-installer "$PROXY_INSTALLER_TEMP" "$PROXY_INSTALLER_HEADERS" || { echo "❌ residential-proxy.sh 更新清单校验失败"; exit 1; }
bash -n "$PROXY_INSTALLER_TEMP"
chmod 700 "$PROXY_INSTALLER_TEMP"
bash "$PROXY_INSTALLER_TEMP" --domain "$API_URL" --controller "${PROXY_API_URL:-$API_URL}" --ip "$VPS_IP" --token "$TOKEN"
cleanup_proxy_installer
INSTALL_SUCCESS=1
rm -rf "$BACKUP_DIR"
trap - EXIT INT TERM

echo "=========================================="
echo " 🎉 KUI + 住宅 IP 双隧道代理部署成功！"
echo " 节点 IP: ${VPS_IP}"
echo " 系统架构: ${OS}"
echo "=========================================="
