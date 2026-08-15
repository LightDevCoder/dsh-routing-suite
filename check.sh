#!/usr/bin/env bash
#
# dsh-routing-suite — 环境健康检查（macOS / Linux）
#
# 检查：dsh CLI、DSH_HOME、注入器文件与注册状态、Router preset 完整性、
#       以及已安装版本与 versions.json 锁定版本是否一致。
# 退出码：0 = 环境就绪；1 = 存在失败项（会逐项列出）。
#
# 用法：./check.sh
# 环境变量：DSH_HOME（默认 $HOME/.dsh）、DSH_PROFILE（默认 web）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="${DSH_PROFILE:-web}"
VERSIONS_FILE="$SCRIPT_DIR/versions.json"

INJECTOR_PKG="@dsh-external/dsh-super-injector"
INJECTOR_DIR_NAME="dsh-super-injector"
ROUTER_ID="router-standard"

FAILED=0

say() { printf '\n==> %s\n' "$*"; }

# check_row <label> <status> [detail...]  — 失败项会计入退出码
check_row() {
  local label="$1" status="$2"
  shift 2
  printf '%-22s %s\n' "$label" "$status"
  if [ -n "${1:-}" ]; then
    printf '%-22s   %s\n' "" "$*"
  fi
  [ "$status" = "OK" ] || FAILED=1
}

# info_row <label> <value>  — 仅展示，不影响退出码
info_row() {
  printf '%-22s %s\n' "$1" "$2"
}

resolve_dsh_home() {
  if [ -n "${DSH_HOME:-}" ] && [ -n "$(printf '%s' "$DSH_HOME" | tr -d ' ')" ]; then
    printf '%s' "$DSH_HOME"
  else
    printf '%s' "$HOME/.dsh"
  fi
}

locked_version() {
  local key="$1"
  if [ ! -f "$VERSIONS_FILE" ]; then
    printf 'unknown'
    return
  fi
  node -e '
    const fs = require("fs");
    const v = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    process.stdout.write(String(v[process.argv[2]].version));
  ' "$VERSIONS_FILE" "$key" 2>/dev/null || printf 'unknown'
}

installed_marker() {
  [ -f "$1/.version" ] && cat "$1/.version" || printf ''
}

say "dsh-routing-suite 健康检查"

# ---- 1. dsh CLI ----
if command -v dsh >/dev/null 2>&1; then
  check_row "DSH CLI" "OK" "$(command -v dsh)"
else
  check_row "DSH CLI" "FAIL" "dsh 不在 PATH 中"
fi

# ---- 2. DSH_HOME ----
DSH_HOME="$(resolve_dsh_home)"
info_row "DSH_HOME" "$DSH_HOME"

# ---- 3. Injector 文件 ----
INJECTOR_DIR="$DSH_HOME/local-plugins/$INJECTOR_DIR_NAME"
INJECTOR_VERSION="$(locked_version injector)"
INJ_MARKER="$(installed_marker "$INJECTOR_DIR")"

if [ ! -d "$INJECTOR_DIR" ]; then
  check_row "Injector files" "FAIL" "目录不存在: $INJECTOR_DIR"
elif [ ! -f "$INJECTOR_DIR/lib/index.js" ]; then
  check_row "Injector files" "FAIL" "缺少 lib/index.js —— 安装不完整"
else
  check_row "Injector files" "OK"
fi

# ---- 4. Injector 注册（web profile bundle 层） ----
PROFILE_MANIFEST="$DSH_HOME/profiles/$PROFILE/package.json"
if [ ! -f "$PROFILE_MANIFEST" ]; then
  check_row "Injector registration" "FAIL" "profile 清单不存在: $PROFILE_MANIFEST"
else
  REG="$(node -e '
    const fs = require("fs");
    const p = process.argv[1], pkg = process.argv[2];
    const m = JSON.parse(fs.readFileSync(p, "utf8"));
    const deps = m.dependencies || {};
    const bundles = (m.dsh && m.dsh.profile && m.dsh.profile.bundles) || [];
    const inDeps = Object.keys(deps).includes(pkg);
    const inBundles = bundles.includes(pkg);
    process.stdout.write(inDeps && inBundles ? "registered" : "missing");
  ' "$PROFILE_MANIFEST" "$INJECTOR_PKG")"
  if [ "$REG" = "registered" ]; then
    check_row "Injector registration" "OK" "profile=$PROFILE bundles 已包含 $INJECTOR_PKG"
  else
    check_row "Injector registration" "FAIL" "$INJECTOR_PKG 未进入 $PROFILE profile（dependencies 或 bundles 缺失）"
  fi
fi

# ---- 5. Router preset ----
ROUTER_DIR="$DSH_HOME/.agent-presets/$ROUTER_ID"
ROUTER_VERSION="$(locked_version router)"
ROUTER_MARKER="$(installed_marker "$ROUTER_DIR")"

if [ ! -d "$ROUTER_DIR" ]; then
  check_row "Router preset" "FAIL" "目录不存在: $ROUTER_DIR"
else
  ROUTER_MISSING=""
  for f in preset.yml agent.cordis.yml router-bootstrap.mjs router-core.mjs; do
    [ -f "$ROUTER_DIR/$f" ] || ROUTER_MISSING="$ROUTER_MISSING $f"
  done
  if [ -n "$ROUTER_MISSING" ]; then
    check_row "Router preset" "FAIL" "缺少文件:$ROUTER_MISSING"
  else
    check_row "Router preset" "OK"
  fi
fi

# ---- 6. 版本一致性 ----
if [ -n "$INJ_MARKER" ]; then
  if [ "$INJ_MARKER" = "$INJECTOR_VERSION" ]; then
    check_row "Injector version" "OK" "v${INJ_MARKER}（与 versions.json 一致）"
  else
    check_row "Injector version" "FAIL" "已安装 v${INJ_MARKER}，锁定 v${INJECTOR_VERSION} —— 运行 ./update.sh"
  fi
elif [ -d "$INJECTOR_DIR" ]; then
  check_row "Injector version" "FAIL" "已安装但缺少 .version 标记 —— 运行 ./install.sh --force"
else
  check_row "Injector version" "FAIL" "未安装"
fi

if [ -n "$ROUTER_MARKER" ]; then
  if [ "$ROUTER_MARKER" = "$ROUTER_VERSION" ]; then
    check_row "Router version" "OK" "v${ROUTER_MARKER}（与 versions.json 一致）"
  else
    check_row "Router version" "FAIL" "已安装 v${ROUTER_MARKER}，锁定 v${ROUTER_VERSION} —— 运行 ./update.sh"
  fi
elif [ -d "$ROUTER_DIR" ]; then
  check_row "Router version" "FAIL" "已安装但缺少 .version 标记 —— 运行 ./install.sh --force"
else
  check_row "Router version" "FAIL" "未安装"
fi

# ---- 汇总 ----
printf '\n'
if [ "$FAILED" = "0" ]; then
  printf 'Environment ready.\n'
  exit 0
else
  printf 'Environment NOT ready —— 存在失败项，修复后重新运行 ./check.sh\n'
  exit 1
fi
