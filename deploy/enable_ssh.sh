#!/bin/bash
# 为实例启用 SSH（authorized_keys 持久化到 /workspace；重启后重跑此脚本即可恢复）
set -u
DEFAULT_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII3go8vvSXvAB/bapLjXcY88m3DgQoHzbYay+W2rGuAM modelscope-h3-cloudflare'
KEY="${1:-$DEFAULT_KEY}"

KEY_DIR=/root/.ssh
if [ -d /workspace ]; then
  mkdir -p /workspace/ssh
  KEY_DIR=/workspace/ssh
fi
mkdir -p "$KEY_DIR" && chmod 700 "$KEY_DIR"
grep -qF "$KEY" "$KEY_DIR/authorized_keys" 2>/dev/null || echo "$KEY" >> "$KEY_DIR/authorized_keys"
chmod 600 "$KEY_DIR/authorized_keys"

if [ "$KEY_DIR" != "/root/.ssh" ]; then
  if [ -d /root/.ssh ] && [ ! -L /root/.ssh ]; then
    mv /root/.ssh "/root/.ssh.bak.$(date +%s)" 2>/dev/null || true
  fi
  ln -sfn "$KEY_DIR" /root/.ssh
fi

if [ ! -x /usr/sbin/sshd ]; then
  apt-get update -qq && apt-get install -y -qq openssh-server
fi
mkdir -p /run/sshd
pgrep -x sshd >/dev/null 2>&1 || /usr/sbin/sshd
sleep 1
if pgrep -x sshd >/dev/null 2>&1; then
  echo "[ssh] sshd 已运行，密钥持久化于 $KEY_DIR/authorized_keys"
else
  echo "[ssh] sshd 启动失败" >&2
  exit 1
fi
