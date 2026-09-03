#!/usr/bin/env bash
# ============================================================================
#  云渲染服务器一键安装脚本（离线） v2.0
#
#  适用系统：银河麒麟 V10 / 统信 UOS / CentOS 7+ / RHEL 7+ 等国产化 Linux（x86_64）
#
#  功能（对应《云渲染部署文档.docx》全部步骤）：
#    1. 离线安装 Docker 引擎（docker-*.tgz，目标版本 26.1.3）
#    2. 生成并注册 docker.service 系统服务，设置开机自启
#    3. 自动处理 "Unit docker.service is masked" 屏蔽问题
#    4. 安装 Docker Compose（docker-compose-linux-x86_64）
#    5. 将当前用户加入 docker 用户组，解决权限不足问题
#    6. 安装完成后自动验证
#
#  环境要求（不满足会直接中止并给出原因）：
#    - CPU 架构：x86_64 / amd64（与离线包一致）
#    - Linux 内核：>= 3.10（Docker 官方最低要求）
#    - 系统需使用 systemd 作为 init 系统（提供 systemctl）
#    - 磁盘可用空间 >= 512MB（安装目录所在分区）
#
#  使用方法：
#    把本脚本与 docker-26.1.3.tgz、docker-compose-linux-x86_64 放在同一目录：
#
#        sudo bash install.sh
#        或
#        bash install.sh          # 非 root 会自动请求 sudo 提权
#
#  健壮性设计：
#    - 全程日志记录到 /var/log/cloud-render-install.log，出错可完整回溯
#    - 未预期异常自动捕获（ERR trap），失败即中止并转储诊断信息
#    - 安装包完整性预检（gzip -t / ELF 校验），损坏包直接报错不落盘
#    - 替换旧二进制 / 服务文件前自动备份到 /var/backups/docker-install/
#    - 服务启动带重试 + 就绪探测，失败自动收集 systemctl/journalctl 日志
#    - 全程幂等：已安装且版本一致自动跳过，可放心重复执行
# ============================================================================

# ---------- 严格模式（不启用 set -e，改用显式检查 + ERR trap 兜底） ----------
set -uEo pipefail

umask 022

# ---------- 全局配置 ----------
LOG_FILE="/var/log/cloud-render-install.log"
BACKUP_ROOT="/var/backups/docker-install"
DOCKER_SERVICE_FILE="/usr/lib/systemd/system/docker.service"
COMPOSE_DEST="/usr/local/bin/docker-compose"
BACKUP_DIR=""
TMP_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- 终端颜色（非 TTY 时自动关闭） ----------
if [ -t 1 ]; then
    C_RED='\033[0;31m'; C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'; C_BLUE='\033[0;34m'; C_NC='\033[0m'
else
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_NC=''
fi

# ---------- 日志与消息输出（同时写入日志文件） ----------
_log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE" 2>/dev/null || true; }

info()  { printf '%b[INFO]%b  %s\n' "$C_BLUE" "$C_NC" "$*";  _log "[INFO]  $*"; }
ok()    { printf '%b[ OK ]%b  %s\n' "$C_GREEN" "$C_NC" "$*";  _log "[ OK ]  $*"; }
warn()  { printf '%b[WARN]%b  %s\n' "$C_YELLOW" "$C_NC" "$*"; _log "[WARN]  $*"; }
err()   { printf '%b[ERROR]%b %s\n' "$C_RED" "$C_NC" "$*";   _log "[ERROR] $*"; }

section() {
    echo
    echo "================================================================"
    echo "  $1"
    echo "================================================================"
    _log "=============== $1 ==============="
}

fail() {
    err "$*"
    echo
    err "安装流程已中止。完整日志：${LOG_FILE}"
    exit 1
}

# ---------- 备份目录（首次使用时创建，带时间戳，不重复建） ----------
ensure_backup_dir() {
    if [ -z "$BACKUP_DIR" ]; then
        BACKUP_DIR="$BACKUP_ROOT/backup-$(date '+%Y%m%d-%H%M%S')"
        mkdir -p "$BACKUP_DIR" || fail "创建备份目录失败：${BACKUP_DIR}"
    fi
}

# ---------- 诊断信息收集（失败时写入日志，便于排查） ----------
dump_diagnostics() {
    _log "===== 系统诊断信息开始 ====="
    {
        echo "---- uname -a ----";              uname -a 2>&1 || true
        echo "---- /etc/os-release ----";       cat /etc/os-release 2>&1 || true
        echo "---- systemctl status docker ----"
        systemctl status docker --no-pager -l 2>&1 || true
        echo "---- journalctl -u docker -n 100 ----"
        journalctl -u docker --no-pager -n 100 2>&1 || true
        echo "---- dockerd --version ----";     /usr/bin/dockerd --version 2>&1 || true
        echo "---- docker --version ----";      docker --version 2>&1 || true
        echo "---- 相关内核模块 ----"
        ls /sys/module 2>/dev/null | grep -E '^(overlay|br_netfilter|nf_nat|iptable_nat)$' 2>&1 || true
    } >>"$LOG_FILE" 2>&1
    _log "===== 系统诊断信息结束 ====="
}

print_log_tail() {
    if [ -s "$LOG_FILE" ]; then
        printf '%b---- 最近日志（完整日志：%s） ----%b\n' "$C_YELLOW" "$LOG_FILE" "$C_NC"
        while IFS= read -r line; do
            printf '    %s\n' "$line"
        done < <(tail -n 30 "$LOG_FILE" 2>/dev/null || true)
    fi
}

# ---------- 异常兜底：任何未被显式容错的命令失败，立即中止并转储诊断 ----------
_err_trap() {
    local rc=$?
    trap - ERR
    err "检测到未处理的执行错误（退出码 ${rc}，第 ${1:-?} 行附近）。"
    _log "[ERROR] 第 ${1:-?} 行附近命令执行失败，退出码 ${rc}"
    dump_diagnostics
    print_log_tail
    exit 1
}
trap '_err_trap $LINENO' ERR

# ---------- 退出清理：删除临时解压目录 ----------
_cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR" 2>/dev/null || true
    fi
}
trap _cleanup EXIT
trap 'exit 130' INT TERM

# ---------- 权限处理：非 root 自动通过 sudo 重新执行 ----------
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        info "检测到当前为非 root 用户，正在通过 sudo 重新执行本脚本..."
        echo
        exec sudo -E bash "$0" "$@" || exit 1
    else
        echo
        err "当前系统未安装 sudo，请先切换为 root 用户再执行："
        echo "    su - root"
        echo "    bash $(basename "$0")"
        exit 1
    fi
fi

# 记录真实的操作用户（sudo 提权前是哪个用户）
REAL_USER="${SUDO_USER:-}"
if [ -z "$REAL_USER" ]; then
    REAL_USER="$(logname 2>/dev/null || echo root)"
fi
[ -n "$REAL_USER" ] || REAL_USER="root"

_log "===== 开始执行安装（实际操作用户：${REAL_USER}） ====="
echo
echo "================================================================"
echo "  云渲染服务器 Docker 环境一键安装（离线）"
echo "  日志文件：${LOG_FILE}"
echo "================================================================"
echo

# ============================================================================
# 工具函数
# ============================================================================

# 版本号比较：判断 内核/工具版本 >= 期望版本（仅支持 "主.次" 数字比较，如 3.10）
version_gte() {  # $1=当前版本字符串  $2=期望major  $3=期望minor
    local cur="$1" req_major="$2" req_minor="$3"
    local cur_major cur_minor rest
    cur_major="${cur%%.*}"; cur_major="${cur_major%%-*}"
    case "$cur_major" in *[!0-9]*|'') return 1 ;; esac
    rest="${cur#*.}"; cur_minor="${rest%%.*}"; cur_minor="${cur_minor%%-*}"
    case "$cur_minor" in *[!0-9]*|'') return 1 ;; esac
    if   [ "$cur_major" -gt "$req_major" ]; then return 0
    elif [ "$cur_major" -lt "$req_major" ]; then return 1
    elif [ "$cur_minor" -ge "$req_minor" ]; then return 0
    else return 1
    fi
}

# 源文件是否需要更新目标文件（目标不存在或内容不一致时为真）
need_update() {  # $1=源  $2=目标
    [ ! -f "$2" ] || ! cmp -s "$1" "$2"
}

# 安装单个文件：内容一致则跳过（幂等）；不一致则先备份旧文件再覆盖
install_file() {  # $1=源  $2=目标  $3=描述名
    local src="$1" dst="$2" name="$3"
    if ! need_update "$src" "$dst"; then
        ok "$name 已存在且内容一致，跳过（$dst）"
        return 0
    fi
    ensure_backup_dir
    if [ -e "$dst" ]; then
        if cp -a "$dst" "$BACKUP_DIR/$(basename "$dst")" 2>/dev/null; then
            warn "旧文件已备份：$dst -> $BACKUP_DIR/$(basename "$dst")"
        else
            warn "旧文件备份失败，继续安装（$dst）"
        fi
    fi
    install -m 0755 "$src" "$dst" || fail "安装失败，无法写入：$dst"
    ok "$name 安装完成 -> $dst"
}

# 预检函数
check_arch() {
    local arch
    arch="$(uname -m 2>/dev/null || echo unknown)"
    case "$arch" in
        x86_64|amd64)
            ok "CPU 架构：$arch（与离线包一致）"
            ;;
        *)
            fail "不支持的 CPU 架构：${arch}。离线包仅支持 x86_64/amd64，请更换 64 位 x86 服务器。"
            ;;
    esac
}

check_kernel() {
    local kver
    kver="$(uname -r 2>/dev/null || echo 0)"
    if version_gte "$kver" 3 10; then
        ok "Linux 内核：$kver（满足 >= 3.10 的最低要求）"
        if ! version_gte "$kver" 4 0; then
            warn "内核低于 4.0：overlay2 存储驱动可能不可用，Docker 将自动回退其他存储驱动；"
            warn "        若后续容器启动异常，建议升级内核到 4.0 以上（麒麟/UOS 请使用官方最新内核）。"
        fi
    else
        err "当前内核版本过低：$kver"
        err "Docker Engine 26.x 最低要求 Linux 内核 3.10，请先升级操作系统/内核后再安装。"
        fail "环境检查未通过。"
    fi
}

check_systemd() {
    if ! command -v systemctl >/dev/null 2>&1; then
        fail "未检测到 systemctl（本系统未使用 systemd 作为 init 系统）。"
        fail "离线包依赖 systemd 注册开机自启服务，请使用 systemd 系的 Linux 发行版（麒麟 V10 / UOS / CentOS 7+ 等）。"
    fi
    local init
    init="$(ps -p 1 -o comm= 2>/dev/null || echo unknown)"
    case "$init" in
        systemd) ok "init 系统：systemd（PID 1 = $init）" ;;
        *)       warn "PID 1 不是 systemd（当前为：$init），systemctl 可能不可用，将尝试继续……" ;;
    esac
}

check_disk() {
    local avail
    for mp in /usr /var; do
        avail="$(df -Pk "$mp" 2>/dev/null | awk 'NR==2 {print $4}')"
        [ -n "$avail" ] || avail=0
        if [ "$avail" -lt 524288 ]; then
            fail "磁盘空间不足：$mp 分区可用空间仅 ${avail}KB（需要 >= 512MB）。请清理磁盘后重试。"
        else
            ok "$mp 分区可用空间：$((avail / 1024))MB"
        fi
    done
}

# ============================================================================
# 第 0 步：环境预检
# ============================================================================
section "环境预检"
check_arch
check_kernel
check_systemd
check_disk

# ============================================================================
# 第 1 步：定位并校验离线安装包
# ============================================================================
section "校验离线安装包"

DOCKER_TGZ="${DOCKER_TGZ:-}"
if [ -z "$DOCKER_TGZ" ]; then
    DOCKER_TGZ="$(ls "$SCRIPT_DIR"/docker-*.tgz 2>/dev/null | head -n 1 || true)"
fi
if [ -n "$DOCKER_TGZ" ]; then
    cnt="$(ls "$SCRIPT_DIR"/docker-*.tgz 2>/dev/null | wc -l || echo 0)"
    [ "$cnt" -gt 1 ] && warn "检测到多个 docker-*.tgz 包，将使用：$DOCKER_TGZ"
fi
[ -f "$DOCKER_TGZ" ] || fail "未找到 Docker 安装包（docker-*.tgz），请将安装包与本脚本放在同一目录。"

COMPOSE_SRC="${COMPOSE_SRC:-}"
if [ -z "$COMPOSE_SRC" ]; then
    COMPOSE_SRC="$(ls "$SCRIPT_DIR"/docker-compose-linux-* 2>/dev/null | head -n 1 || true)"
fi
[ -f "$COMPOSE_SRC" ] || fail "未找到 Docker Compose 文件（docker-compose-linux-x86_64），请将文件与本脚本放在同一目录。"

info "Docker 安装包   ：$DOCKER_TGZ"
info "Compose 二进制  ：$COMPOSE_SRC"

# 1.1 Docker 包完整性：gzip 校验 + 目录结构校验
if command -v gzip >/dev/null 2>&1; then
    if gzip -t "$DOCKER_TGZ" 2>/dev/null; then
        ok "Docker 包 gzip 校验通过"
    else
        fail "Docker 安装包已损坏（gzip 校验失败）：$DOCKER_TGZ"
    fi
else
    warn "系统无 gzip 命令，跳过 gzip 完整性校验"
fi
if ! tar -tzf "$DOCKER_TGZ" >/dev/null 2>&1; then
    fail "Docker 安装包无法解析（不是有效的 tar.gz）：$DOCKER_TGZ"
fi
if ! tar -tzf "$DOCKER_TGZ" 2>/dev/null | grep -q 'docker/dockerd'; then
    fail "Docker 安装包内容异常：缺少 docker/dockerd，请重新获取安装包。"
fi

# 1.2 Compose 文件完整性：ELF 魔数 + 64 位 x86_64 检查
check_elf() {  # $1=文件
    local h
    h="$(head -c 20 "$1" 2>/dev/null | od -An -tx1 -v 2>/dev/null | tr -d ' \n')"
    [ "${h:0:8}" = "7f454c46" ] && [ "${h:8:2}" = "02" ] && [ "${h:36:4}" = "3e00" ]
}
if check_elf "$COMPOSE_SRC"; then
    ok "Compose 文件校验通过（64 位 x86_64 ELF 可执行文件）"
else
    fail "Compose 文件不是有效的 64 位 x86_64 ELF 程序，可能损坏或下载错误：$COMPOSE_SRC"
fi

# ============================================================================
# 第 2 步：准备临时目录，停止并备份旧版 Docker
# ============================================================================
section "准备安装环境"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/docker-install.XXXXXX")" || fail "创建临时目录失败"
info "临时目录：$TMP_DIR（退出时自动清理）"

# 如果系统里已有 docker 服务在运行，先停止，避免覆盖二进制时冲突
info "停止旧版 Docker 相关服务（若存在）……"
systemctl stop docker.service docker.socket containerd.service 2>/dev/null || true
pkill -x dockerd 2>/dev/null || true
pkill -x containerd 2>/dev/null || true
sleep 1

# 2.1 解压 Docker 二进制
info "解压 Docker 二进制包……"
tar -xzf "$DOCKER_TGZ" -C "$TMP_DIR" || fail "解压 Docker 安装包失败：$DOCKER_TGZ"
[ -d "$TMP_DIR/docker" ] || fail "Docker 包结构异常：解压后缺少 docker/ 目录"

# 2.2 备份旧的服务文件（在覆盖前做一次快照）
ensure_backup_dir
for svc in docker.service docker.socket containerd.service; do
    for base in /usr/lib/systemd/system /lib/systemd/system /etc/systemd/system; do
        if [ -f "$base/$svc" ] || [ -L "$base/$svc" ]; then
            cp -a "$base/$svc" "$BACKUP_DIR/$(basename "$base")-$svc" 2>/dev/null \
                && warn "已备份服务文件：$base/$svc"
            break
        fi
    done
done

# ============================================================================
# 第 3 步：安装 Docker Engine 二进制
# ============================================================================
section "安装 Docker Engine（v26.1.3）"

for bin in docker dockerd containerd containerd-shim-runc-v2 runc docker-init docker-proxy ctr; do
    src="$TMP_DIR/docker/$bin"
    if [ ! -f "$src" ]; then
        warn "安装包中缺少 $bin，跳过（当前包版本可能已不再包含该组件）"
        continue
    fi
    install_file "$src" "/usr/bin/$bin" "$bin"
done

# ============================================================================
# 第 4 步：生成 systemd 服务文件并启动
# ============================================================================
section "注册系统服务"

# 确保 docker 用户组存在（docker.socket 需要）
if ! getent group docker >/dev/null 2>&1; then
    groupadd docker 2>/dev/null && ok "已创建 docker 用户组" || warn "创建 docker 用户组失败（可能已存在）"
fi

# docker.service
cat > "$DOCKER_SERVICE_FILE" <<'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target docker.socket firewalld.service containerd.service time-set.target
Wants=network-online.target
Requires=docker.socket containerd.service

[Service]
Type=notify
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

# docker.socket
cat > /usr/lib/systemd/system/docker.socket <<'EOF'
[Unit]
Description=Docker Socket for the API

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

# containerd.service
cat > /usr/lib/systemd/system/containerd.service <<'EOF'
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/bin/containerd
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

# 处理 "Unit docker.service is masked" 屏蔽问题（麒麟/UOS/加固系统常见）
info "解除可能的服务屏蔽（masked）状态……"
systemctl unmask docker.service docker.socket containerd.service 2>/dev/null || true
rm -f /etc/systemd/system/docker.service 2>/dev/null || true   # 清掉指向 /dev/null 的屏蔽软链

systemctl daemon-reload || warn "systemctl daemon-reload 失败"
systemctl enable containerd.service >/dev/null 2>&1 || warn "设置 containerd 开机自启失败"
systemctl enable docker.socket    >/dev/null 2>&1 || warn "设置 docker.socket 开机自启失败"
systemctl enable docker.service   >/dev/null 2>&1 || warn "设置 docker 开机自启失败"

# 启动 + 重试 + 就绪探测（docker.service 为 Type=notify，start 返回即视为就绪）
info "启动 Docker 服务（最多重试 3 次）……"
docker_started=0
for attempt in 1 2 3; do
    if systemctl start containerd.service 2>/dev/null; then
        ok "containerd 已启动（第 ${attempt} 次尝试）"
        break
    else
        warn "containerd 启动失败（第 ${attempt} 次），2 秒后重试……"
        sleep 2
    fi
done

for attempt in 1 2 3; do
    if systemctl start docker.service 2>/dev/null; then
        docker_started=1
        break
    fi
    warn "docker 服务启动失败（第 ${attempt} 次），3 秒后重试……"
    sleep 3
done

if [ "$docker_started" -ne 1 ]; then
    err "Docker 服务多次启动仍然失败，已收集诊断信息："
    dump_diagnostics
    err "可尝试手动执行：systemctl start docker.service 并查看 journalctl -u docker 定位原因。"
    print_log_tail
    exit 1
fi
ok "Docker 服务已启动"

# 二次确认守护进程真正可用（docker version 客户端成功不代表 daemon 正常）
if ! docker info >/dev/null 2>&1; then
    err "docker 服务虽已启动，但守护进程未就绪（docker info 失败）。"
    dump_diagnostics
    print_log_tail
    exit 1
fi
ok "Docker 守护进程就绪"

# ============================================================================
# 第 5 步：安装 Docker Compose（兼容 docker-compose 与 docker compose 两种用法）
# ============================================================================
section "安装 Docker Compose"

install_file "$COMPOSE_SRC" "/usr/local/bin/docker-compose" "docker-compose"

# 同时注册为 docker CLI 插件，使 `docker compose` 也可用（compose v2 推荐用法）
CLI_PLUGIN_DIR="/usr/local/lib/docker/cli-plugins"
mkdir -p "$CLI_PLUGIN_DIR" 2>/dev/null || true
if [ -d "$CLI_PLUGIN_DIR" ]; then
    rm -f "$CLI_PLUGIN_DIR/docker-compose" 2>/dev/null || true
    ln -sf /usr/local/bin/docker-compose "$CLI_PLUGIN_DIR/docker-compose" 2>/dev/null \
        && ok "已注册 docker CLI 插件（支持 docker compose 命令）" \
        || warn "注册 docker CLI 插件失败（仅 docker-compose 命令可用）"
fi

# ============================================================================
# 第 6 步：将实际操作用户加入 docker 用户组
# ============================================================================
section "配置用户权限"

if [ "$REAL_USER" != "root" ] && id "$REAL_USER" >/dev/null 2>&1; then
    usermod -aG docker "$REAL_USER" && ok "已将用户 $REAL_USER 加入 docker 用户组" \
        || warn "将用户 $REAL_USER 加入 docker 用户组失败（可用 root 手动执行：usermod -aG docker $REAL_USER）"
    warn "提示：docker 用户组需重新登录后才生效；当前会话如需立即使用可执行：sudo -s"
elif [ "$REAL_USER" = "root" ]; then
    ok "当前以 root 执行，无需加入 docker 组"
else
    warn "用户 $REAL_USER 不存在，跳过加入用户组（root 可直接使用 docker）"
fi

# ============================================================================
# 第 7 步：安装结果验证
# ============================================================================
section "验证安装结果"

if command -v docker >/dev/null 2>&1; then
    docker_version="$(docker --version 2>/dev/null || true)"
    ok "docker CLI     ：${docker_version:-未知}"
else
    fail "docker 命令不可用，安装可能未成功。"
fi

if command -v docker-compose >/dev/null 2>&1; then
    compose_version="$(docker-compose --version 2>/dev/null || true)"
    ok "docker-compose ：${compose_version:-未知}"
else
    fail "docker-compose 命令不可用，安装可能未成功。"
fi

if docker info >/dev/null 2>&1; then
    ok "Docker 守护进程：运行正常"
else
    err "Docker 守护进程状态异常，请检查：journalctl -u docker -n 100"
    exit 1
fi

info "开机自启状态："
systemctl is-enabled docker.service   2>/dev/null | sed 's/^/  docker.service      -> /' || true
systemctl is-enabled docker.socket    2>/dev/null | sed 's/^/  docker.socket       -> /' || true
systemctl is-enabled containerd.service 2>/dev/null | sed 's/^/  containerd.service -> /' || true

echo
echo "================================================================"
ok "Docker 环境安装完成！"
echo "---------------------------------------------------------------"
echo "  版本信息："
echo "    $(docker --version 2>/dev/null)"
echo "    $(docker-compose --version 2>/dev/null)"
echo "  docker 服务状态：$(systemctl is-active docker 2>/dev/null)"
echo "---------------------------------------------------------------"
echo "  后续使用（离线内网环境）："
echo "    1. 若需重新登录使用 docker 命令：exit 后重新 SSH 登录；"
echo "    2. 加载离线镜像：docker load -i <镜像tar文件>；"
echo "    3. 启动应用栈：cd <部署目录> && docker compose up -d（或 docker-compose up -d）。"
echo "  备份目录：${BACKUP_DIR}"
echo "  完整日志：${LOG_FILE}"
echo "================================================================"
echo
