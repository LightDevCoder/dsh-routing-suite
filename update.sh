#!/usr/bin/env bash
#
# dsh-routing-suite — 受控升级
#
# 读取 versions.json，把当前 DSH 环境升级到锁定版本：
#   注入器  → 版本不一致时备份旧目录并安装锁定 Release（重新装配进 profile）
#   Router  → 版本不一致时备份旧 preset 并安装锁定版本
#   最后执行 health check。
#
# 版本升级由仓库维护者修改 versions.json 触发；本脚本不追踪 upstream main。
# 第一版不做“自动发现 GitHub 最新 Release”。
#
# 用法：./update.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/install.sh" --update "$@"
