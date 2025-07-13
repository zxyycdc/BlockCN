#!/bin/bash

# 确保脚本以root权限运行
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# 临时保存目录和文件名
WORKDIR="/tmp/block_cn_ip"
IPV4_URL="https://www.ipdeny.com/ipblocks/data/countries/cn.zone"
IPV6_URL="https://www.ipdeny.com/ipv6/ipaddresses/aggregated/cn-aggregated.zone"
IPV4_FILE="$WORKDIR/cn_ipv4.zone"
IPV6_FILE="$WORKDIR/cn_ipv6.zone"
IPTABLES_BACKUP="/tmp/iptables_backup.rules"
IP6TABLES_BACKUP="/tmp/ip6tables_backup.rules"

mkdir -p "$WORKDIR"

function menu() {
    echo ""
    echo "========= 中国IP封锁工具 ========="
    echo "1. 下载更新地址列表"
    echo "2. 选择需要屏蔽的地址范围"
    echo "3. 恢复初始状态，解除阻止"
    echo "4. 退出不做任何改动"
    echo "=================================="
    read -rp "请输入对应数字进行操作: " main_choice
    case "$main_choice" in
        1) download_lists ;;
        2) block_menu ;;
        3) restore_rules ;;
        4) echo "退出脚本..." ;;
        *) echo "无效输入，请重新运行。"; exit 1 ;;
    esac
}

function download_lists() {
    echo "下载中国 IPv4 地址列表..."
    curl -s -o "$IPV4_FILE" "$IPV4_URL" || { echo "下载 IPv4 失败"; exit 1; }

    echo "下载中国 IPv6 地址列表..."
    curl -s -o "$IPV6_FILE" "$IPV6_URL" || { echo "下载 IPv6 失败"; exit 1; }

    echo "地址列表已更新并保存在: $WORKDIR"
}

function block_menu() {
    echo ""
    echo "请选择需要屏蔽的地址类型："
    echo "1. 屏蔽 IPv4"
    echo "2. 屏蔽 IPv6"
    echo "3. 屏蔽 IPv4 和 IPv6"
    read -rp "请输入选项数字: " ip_choice

    echo ""
    echo "请选择屏蔽方式："
    echo "1. 阻止所有访问（所有端口）"
    echo "2. 阻止特定端口访问"
    read -rp "请输入选项数字: " block_mode

    if [[ "$block_mode" == "2" ]]; then
        read -rp "请输入要屏蔽的端口号（单个端口）: " port
    fi

    # 保存原始规则（仅第一次运行）
    if [[ ! -f $IPTABLES_BACKUP ]]; then
        iptables-save > "$IPTABLES_BACKUP"
        ip6tables-save > "$IP6TABLES_BACKUP"
    fi

    [[ "$ip_choice" == "1" || "$ip_choice" == "3" ]] && apply_block "ipv4" "$block_mode" "$port"
    [[ "$ip_choice" == "2" || "$ip_choice" == "3" ]] && apply_block "ipv6" "$block_mode" "$port"

    echo "屏蔽规则已应用。"
}

function apply_block() {
    local version=$1
    local mode=$2
    local port=$3

    local file=""
    local cmd=""

    if [[ "$version" == "ipv4" ]]; then
        file="$IPV4_FILE"
        cmd="iptables"
    else
        file="$IPV6_FILE"
        cmd="ip6tables"
    fi

    if [[ ! -f "$file" ]]; then
        echo "未找到 $version 地址列表，请先选择[1]下载更新地址列表"
        exit 1
    fi

    echo "应用 $version 屏蔽规则..."

    while read -r ip; do
        [[ -z "$ip" ]] && continue
        if [[ "$mode" == "1" ]]; then
            $cmd -A INPUT -s "$ip" -j DROP
        elif [[ "$mode" == "2" ]]; then
            $cmd -A INPUT -s "$ip" -p tcp --dport "$port" -j DROP
        fi
    done < "$file"
}

function restore_rules() {
    if [[ -f "$IPTABLES_BACKUP" ]]; then
        echo "恢复 IPv4 iptables 规则..."
        iptables-restore < "$IPTABLES_BACKUP"
    else
        echo "找不到原始 IPv4 iptables 备份，跳过..."
    fi

    if [[ -f "$IP6TABLES_BACKUP" ]]; then
        echo "恢复 IPv6 ip6tables 规则..."
        ip6tables-restore < "$IP6TABLES_BACKUP"
    else
        echo "找不到原始 IPv6 ip6tables 备份，跳过..."
    fi

    echo "所有规则已还原。"
}

menu
