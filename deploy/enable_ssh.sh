#!/bin/bash
# 为实例启用 SSH（镜像默认不带 sshd；平台 ssh_enabled 只开端口）
# 用法: bash deploy/enable_ssh.sh 'ssh-ed25519 AAAA... 注释'
# 不带参数时使用默认公钥
set -u
DEFAULT_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII3go8vvSXvAB/bapLjXcY88m3DgQoHzbYay+W2rGuAM modelscope-h3-cloudflare'
KEY="${1:-$DEFAULT_KEY}"

if [ ! -x /usr/sbin/sshd ]; then
  apt-get update -qq && apt-get install -y -qq openssh-server
fi
mkdir -p /run/sshd /root/.ssh
chmod 700 /root/.ssh
grep -qF "$KEY" /root/.ssh/authorized_keys 2>/dev/null || echo "$KEY" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
pgrep -x sshd >/dev/null 2>&1 || /usr/sbin/sshd
sleep 1
if pgrep -x sshd >/dev/null 2>&1; then
  echo "[ssh] sshd 已运行"
else
  echo "[ssh] sshd 启动失败" >&2
  exit 1
fi
