#!/bin/bash
# 为实例启用 SSH。密钥由环境变量或持久目录提供，不在代码中保存用户密钥。
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
KEY="${1:-${SSH_PUBLIC_KEY:-}}"

mkdir -p /root/.ssh
chmod 700 /root/.ssh
# 持久副本 -> 恢复
if [ -f "$H3_SSH_DIR/authorized_keys" ]; then
  cat "$H3_SSH_DIR/authorized_keys" >> /root/.ssh/authorized_keys
fi
if [ -n "$KEY" ]; then
  grep -qF "$KEY" /root/.ssh/authorized_keys 2>/dev/null || echo "$KEY" >> /root/.ssh/authorized_keys
fi
sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys
if [ ! -s /root/.ssh/authorized_keys ]; then
  echo "[ssh] 没有可用公钥；请在 AMD Profile 保存 SSH Public Key，或设置 SSH_PUBLIC_KEY" >&2
  exit 1
fi
chmod 600 /root/.ssh/authorized_keys
# 更新持久副本
mkdir -p "$H3_SSH_DIR" 2>/dev/null && cp /root/.ssh/authorized_keys "$H3_SSH_DIR/authorized_keys" 2>/dev/null

if [ ! -x /usr/sbin/sshd ]; then
  APT_TIMEOUT_SEC="${H3_APT_TIMEOUT_SEC:-180}"
  APT_RETRIES="${H3_APT_RETRIES:-2}"
  APT_OPTIONS=(
    -o "Acquire::Retries=$APT_RETRIES"
    -o "Acquire::http::Timeout=${H3_APT_HTTP_TIMEOUT_SEC:-20}"
    -o "Acquire::https::Timeout=${H3_APT_HTTPS_TIMEOUT_SEC:-20}"
  )
  timeout "$APT_TIMEOUT_SEC" env DEBIAN_FRONTEND=noninteractive \
    apt-get "${APT_OPTIONS[@]}" update -qq \
    || { echo "[ssh] apt update 超时或失败，跳过 SSH 安装" >&2; exit 1; }
  timeout "$APT_TIMEOUT_SEC" env DEBIAN_FRONTEND=noninteractive \
    apt-get "${APT_OPTIONS[@]}" install -y -qq openssh-server \
    || { echo "[ssh] openssh-server 安装超时或失败" >&2; exit 1; }
fi
mkdir -p /run/sshd
pgrep -x sshd >/dev/null 2>&1 || /usr/sbin/sshd
sleep 1
if pgrep -x sshd >/dev/null 2>&1; then
  echo "[ssh] sshd 已运行；密钥持久副本: $H3_SSH_DIR/authorized_keys"
else
  echo "[ssh] sshd 启动失败" >&2
  exit 1
fi
