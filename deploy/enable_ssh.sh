#!/bin/bash
# 为实例启用 SSH v3
# 说明: sshd 的 StrictModes 拒绝从 world-writable 目录(/workspace)读取密钥，
#       因此密钥实际放 /root/.ssh，/workspace/ssh 只存持久化副本，重启后重跑本脚本恢复。
set -u
DEFAULT_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII3go8vvSXvAB/bapLjXcY88m3DgQoHzbYay+W2rGuAM modelscope-h3-cloudflare'
KEY="${1:-$DEFAULT_KEY}"

mkdir -p /root/.ssh
chmod 700 /root/.ssh
# 持久副本 -> 恢复
if [ -f /workspace/ssh/authorized_keys ]; then
  cat /workspace/ssh/authorized_keys >> /root/.ssh/authorized_keys
fi
grep -qF "$KEY" /root/.ssh/authorized_keys 2>/dev/null || echo "$KEY" >> /root/.ssh/authorized_keys
sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
# 更新持久副本
mkdir -p /workspace/ssh 2>/dev/null && cp /root/.ssh/authorized_keys /workspace/ssh/authorized_keys 2>/dev/null

if [ ! -x /usr/sbin/sshd ]; then
  apt-get update -qq && apt-get install -y -qq openssh-server
fi
mkdir -p /run/sshd
pgrep -x sshd >/dev/null 2>&1 || /usr/sbin/sshd
sleep 1
if pgrep -x sshd >/dev/null 2>&1; then
  echo "[ssh] sshd 已运行；密钥持久副本: /workspace/ssh/authorized_keys"
else
  echo "[ssh] sshd 启动失败" >&2
  exit 1
fi
