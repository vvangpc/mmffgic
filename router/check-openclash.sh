#!/bin/sh
# Run on OpenWrt, or pass a trusted SSH host from the home computer.
set -eu

usage() {
    echo "用法：sh router/check-openclash.sh [路由器的 SSH 主机别名或 user@LAN-IP]"
}
case ${1:-} in -h|--help) usage; exit 0 ;; esac
[ "$#" -le 1 ] || { usage >&2; exit 2; }
target=${1:-}
if [ -z "$target" ] && [ ! -r /etc/openwrt_release ]; then
    if [ ! -t 0 ]; then usage >&2; exit 2; fi
    printf '家庭路由器的 SSH 主机别名或 user@LAN-IP：' >&2
    IFS= read -r target || exit 2
    [ -n "$target" ] || exit 2
fi
if [ -n "$target" ]; then
    case "$target" in -*|*[!A-Za-z0-9.@:_-]*) echo 'SSH 目标格式无效' >&2; exit 2 ;; esac
    exec ssh -T -o ConnectTimeout=8 -o ForwardAgent=no -o ClearAllForwardings=yes "$target" 'sh -s' < "$0"
fi
[ -r /etc/openwrt_release ] && command -v uci >/dev/null || { echo '当前设备未识别为 OpenWrt' >&2; exit 1; }

if [ -s /tmp/sysinfo/model ]; then
    printf '型号：'; cat /tmp/sysinfo/model
elif [ -r /proc/device-tree/model ]; then
    printf '型号：'; tr -d '\000' </proc/device-tree/model; echo
fi
printf '固件：'; sed -n "s/^DISTRIB_DESCRIPTION=//p" /etc/openwrt_release
printf '路由器时间：'; date '+%Y-%m-%d %H:%M:%S %z'
[ -x /etc/init.d/openclash ] || { echo '未发现 OpenClash 服务，请先核对设备及安装情况'; exit 1; }
enabled=$(uci -q get openclash.config.enable || :)
printf 'OpenClash 启用设置：%s\n' "${enabled:-未知}"
if pidof clash_meta >/dev/null 2>&1 || pidof mihomo >/dev/null 2>&1 || pidof clash >/dev/null 2>&1; then
    echo '已检测到运行的 Clash/Mihomo 内核进程'
else
    echo '未检测到常见名称的内核进程，请在 OpenClash 运行状态页确认'
fi
configured=$(uci -q get openclash.config.config_path || :)
if [ -n "$configured" ] && [ -r "$configured" ]; then
    echo 'OpenClash 选中的配置文件可读'
else
    echo '未能从 UCI 确认选中的配置文件，请在 LuCI 核对'
fi
for binary in /etc/openclash/core/clash_meta /etc/openclash/clash /usr/bin/mihomo; do
    [ -x "$binary" ] || continue
    printf '可用内核文件版本：'; "$binary" -v 2>/dev/null | head -n 1
    break
done
if command -v nft >/dev/null && nft list table inet fw4 >/dev/null 2>&1; then
    echo '检测到活动的 nftables inet fw4 表'
elif command -v iptables >/dev/null && iptables -S FORWARD >/dev/null 2>&1; then
    echo '可以读取 iptables FORWARD 链，请核对实际防火墙后端'
else
    echo '无法确认防火墙后端，请用具备本机读取权限的账号核对'
fi
echo '盘点结束。接下来请按 router/OPENCLASH-HANDOFF.md 备份、适配并验收。'
