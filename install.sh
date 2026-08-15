#!/usr/bin/env bash
#
# dsh-routing-suite — 个人 DSH 安装与路由发行层（macOS / Linux）
#
# 安装内容（版本一律以 versions.json 为准，不追踪 upstream main）：
#   1. dsh-super-injector   — 从上游 Release 下载锁定版本 tgz，解压到
#                             $DSH_HOME/local-plugins/dsh-super-injector，
#                             并装配进 web profile（dsh plugin --profile web add）
#   2. dsh-router-standard  — 安装锁定版本的 preset 到
#                             $DSH_HOME/.agent-presets/router-standard
#                             （旧版本先备份为 router-standard.bak.<时间戳>）
#
# 用法：
#   ./install.sh              首次安装 / 幂等重装
#   ./install.sh --update     受控升级（update.sh 即此模式的入口）
#   ./install.sh --force      即使版本相同也重新安装（修复用）
#
# 环境变量：
#   DSH_HOME      DSH 数据根目录（默认 $HOME/.dsh），安装脚本优先尊重它
#   DSH_PROFILE   装配注入器的 profile 名（默认 web）

set -euo pipefail

# ---------------------------------------------------------------- 常量

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INJECTOR_REPO="https://github.com/yjh051108/dsh-super-injector"
ROUTER_REPO="https://github.com/yjh051108/dsh-router-standard"

INJECTOR_DIR_NAME="dsh-super-injector"
ROUTER_ID="router-standard"

PROFILE="${DSH_PROFILE:-web}"
VERSIONS_FILE="$SCRIPT_DIR/versions.json"

MODE="install"   # install | update
FORCE=0
CURRENT_TMP=""

# ---------------------------------------------------------------- 小工具

say()  { printf '\n==> %s\n' "$*"; }
ok()   { printf '    [ok] %s\n' "$*"; }
warn() { printf '    [warn] %s\n' "$*"; }
die()  { printf '\n[error] %s\n' "$*" >&2; exit 1; }

ts() { date +%Y%m%d-%H%M%S; }

cleanup() {
  [ -n "$CURRENT_TMP" ] && rm -rf "$CURRENT_TMP" || true
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
用法：
  ./install.sh              首次安装 / 幂等重装
  ./install.sh --update     受控升级（update.sh 即此模式的入口）
  ./install.sh --force      即使版本相同也重新安装（修复用）

环境变量：
  DSH_HOME      DSH 数据根目录（默认 $HOME/.dsh），安装脚本优先尊重它
  DSH_PROFILE   装配注入器的 profile 名（默认 web）
EOF
  exit 0
}

# 从 versions.json 读取组件版本（node 是 preflight 保证存在的依赖）
read_version() {
  local key="$1"
  node -e '
    const fs = require("fs");
    const v = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    process.stdout.write(String(v[process.argv[2]].version));
  ' "$VERSIONS_FILE" "$key"
}

resolve_dsh_home() {
  if [ -n "${DSH_HOME:-}" ] && [ -n "$(printf '%s' "$DSH_HOME" | tr -d ' ')" ]; then
    printf '%s' "$DSH_HOME"
  else
    printf '%s' "$HOME/.dsh"
  fi
}

# 备份已有安装目录（不做删除，备份永远保留）
backup_dir() {
  local dir="$1"
  local bak="${dir}.bak.$(ts)"
  mv "$dir" "$bak"
  warn "旧版本已备份到: $bak"
}

# ---------------------------------------------------------------- 参数

for arg in "$@"; do
  case "$arg" in
    --update) MODE="update" ;;
    --force)  FORCE=1 ;;
    -h|--help) usage ;;
    *) die "未知参数: ${arg}（支持 --update / --force）" ;;
  esac
done

MODE_LABEL="install"
[ "$MODE" = "update" ] && MODE_LABEL="升级"

# ---------------------------------------------------------------- preflight

MISSING=""
command -v git  >/dev/null 2>&1 || MISSING="$MISSING git"
command -v node >/dev/null 2>&1 || MISSING="$MISSING node"
command -v dsh  >/dev/null 2>&1 || MISSING="$MISSING dsh"
command -v curl >/dev/null 2>&1 || MISSING="$MISSING curl"
command -v tar  >/dev/null 2>&1 || MISSING="$MISSING tar"
command -v pnpm >/dev/null 2>&1 || PNPM_MISSING=1

case "$(uname -s)" in
  Darwin|Linux) ;;
  *) die "当前仅支持 macOS / Linux（Windows 请用 install.ps1）" ;;
esac

if [ "${PNPM_MISSING:-0}" = "1" ]; then
  # dsh plugin 底层转发给 pnpm；corepack 是 Node 官方的 pnpm 引导方式
  if command -v corepack >/dev/null 2>&1; then
    warn "未找到 pnpm，尝试用 corepack 启用（corepack enable pnpm）..."
    corepack enable pnpm >/dev/null 2>&1 || true
  fi
  if ! command -v pnpm >/dev/null 2>&1; then
    MISSING="$MISSING pnpm"
  fi
fi

if [ -n "$MISSING" ]; then
  printf '\n缺少关键依赖，安装已停止（未做任何修改）：%s\n' "$MISSING"
  printf '请先安装缺失项，再重新运行 ./install.sh。\n'
  printf '  pnpm: 可执行 npm install -g pnpm，或 corepack enable pnpm\n'
  exit 1
fi

[ -f "$VERSIONS_FILE" ] || die "找不到 versions.json（${VERSIONS_FILE}）——版本锁文件缺失，无法继续"

INJECTOR_VERSION="$(read_version injector)"
ROUTER_VERSION="$(read_version router)"
[ -n "$INJECTOR_VERSION" ] || die "versions.json 缺少 injector.version"
[ -n "$ROUTER_VERSION" ]   || die "versions.json 缺少 router.version"

DSH_HOME="$(resolve_dsh_home)"
mkdir -p "$DSH_HOME" 2>/dev/null || die "无法创建 DSH_HOME: $DSH_HOME"
[ -w "$DSH_HOME" ] || die "DSH_HOME 不可写: $DSH_HOME"

INJECTOR_DIR="$DSH_HOME/local-plugins/$INJECTOR_DIR_NAME"
ROUTER_DIR="$DSH_HOME/.agent-presets/$ROUTER_ID"

say "dsh-routing-suite ${MODE_LABEL}（锁定版本 injector v${INJECTOR_VERSION} / router v${ROUTER_VERSION}）"
ok "DSH_HOME = $DSH_HOME"
ok "profile  = $PROFILE"

# ---------------------------------------------------------------- 注入器安装

injector_installed_version() {
  if [ -f "$INJECTOR_DIR/.version" ]; then
    cat "$INJECTOR_DIR/.version"
  elif [ -f "$INJECTOR_DIR/package.json" ]; then
    node -e 'process.stdout.write(require(process.argv[1]).version)' "$INJECTOR_DIR/package.json" 2>/dev/null || true
  fi
}

# 状态：missing / incomplete / same / different
injector_state() {
  if [ ! -d "$INJECTOR_DIR" ]; then
    printf 'missing'
  elif [ ! -f "$INJECTOR_DIR/lib/index.js" ] || [ ! -f "$INJECTOR_DIR/package.json" ]; then
    printf 'incomplete'
  elif [ "$(injector_installed_version)" = "$INJECTOR_VERSION" ]; then
    printf 'same'
  else
    printf 'different'
  fi
}

injector_install() {
  local state ver tmp tgz url
  state="$(injector_state)"

  if [ "$state" = "same" ] && [ "$FORCE" != "1" ]; then
    ok "注入器 v${INJECTOR_VERSION} 已安装（${INJECTOR_DIR}），跳过下载"
    return 0
  fi

  if [ "$state" = "missing" ]; then
    say "安装注入器 v${INJECTOR_VERSION}"
  else
    ver="$(injector_installed_version)"
    if [ "$state" = "different" ]; then
      warn "已安装注入器 v${ver:-unknown}，与锁定的 v${INJECTOR_VERSION} 不一致，备份后重装"
    elif [ "$state" = "incomplete" ]; then
      warn "检测到不完整的注入器安装（缺少 lib/index.js 或 package.json），备份后重装"
    else
      warn "--force：备份现有注入器 v${ver:-unknown} 后重装"
    fi
    backup_dir "$INJECTOR_DIR"
    say "安装注入器 v${INJECTOR_VERSION}"
  fi

  tmp="$DSH_HOME/local-plugins/.injector.tmp.$(ts)"
  mkdir -p "$tmp"
  CURRENT_TMP="$tmp"
  tgz="$tmp/dsh-external-dsh-super-injector-$INJECTOR_VERSION.tgz"
  url="$INJECTOR_REPO/releases/download/v$INJECTOR_VERSION/dsh-external-dsh-super-injector-$INJECTOR_VERSION.tgz"

  say "下载 ${INJECTOR_VERSION} Release 包"
  curl -fL --retry 2 --connect-timeout 20 -o "$tgz" "$url" || die "下载注入器 Release 失败: $url"

  say "解压到 $INJECTOR_DIR"
  tar -xzf "$tgz" -C "$tmp" --strip-components=1 || die "解压注入器 Release 包失败"

  # 确认 package 内容
  for f in package.json lib/index.js cordis.patch.yml; do
    [ -f "$tmp/$f" ] || die "注入器 Release 包内容不完整（缺少 ${f}）"
  done

  rm -f "$tgz"
  mv "$tmp" "$INJECTOR_DIR"
  CURRENT_TMP=""
  printf '%s' "$INJECTOR_VERSION" > "$INJECTOR_DIR/.version"

  say "装配注入器到 profile '$PROFILE'"
  dsh plugin --profile "$PROFILE" add "$INJECTOR_DIR" || die "dsh plugin 装配注入器失败（详见上方输出）"
  ok "注入器 v${INJECTOR_VERSION} 已装配进 $PROFILE profile（重启 DSH 后生效）"
}

# ---------------------------------------------------------------- 路由预设安装

router_installed_version() {
  [ -f "$ROUTER_DIR/.version" ] && cat "$ROUTER_DIR/.version" || true
}

# 状态：missing / incomplete / same / different
router_state() {
  local f
  if [ ! -d "$ROUTER_DIR" ]; then
    printf 'missing'
  else
    for f in preset.yml agent.cordis.yml router-bootstrap.mjs router-core.mjs; do
      [ -f "$ROUTER_DIR/$f" ] || { printf 'incomplete'; return; }
    done
    if [ "$(router_installed_version)" = "$ROUTER_VERSION" ]; then
      printf 'same'
    else
      printf 'different'
    fi
  fi
}

# 优先使用仓库内 submodule（preset/ 指向 router-standard 的锁定 tag），
# 缺失或损坏时回退到上游 Release tgz。
router_source_dir() {
  local sm="$SCRIPT_DIR/preset/preset"
  if [ -f "$sm/preset.yml" ] && [ -f "$sm/agent.cordis.yml" ] && \
     [ -f "$sm/router-bootstrap.mjs" ] && [ -f "$sm/router-core.mjs" ]; then
    printf '%s' "$sm"
  else
    printf 'download'
  fi
}

router_install() {
  local state ver src tmp tgz url lic_src
  state="$(router_state)"

  if [ "$state" = "same" ] && [ "$FORCE" != "1" ]; then
    ok "Router Standard v${ROUTER_VERSION} 已安装（${ROUTER_DIR}），跳过"
    return 0
  fi

  if [ "$state" = "missing" ]; then
    say "安装 Router Standard v${ROUTER_VERSION}"
  else
    ver="$(router_installed_version)"
    if [ "$state" = "different" ]; then
      warn "已安装 Router v${ver:-unknown}，与锁定的 v${ROUTER_VERSION} 不一致，备份后重装"
    elif [ "$state" = "incomplete" ]; then
      warn "检测到不完整的 Router preset（缺少必需文件），备份后重装"
    else
      warn "--force：备份现有 Router v${ver:-unknown} 后重装"
    fi
    backup_dir "$ROUTER_DIR"
    say "安装 Router Standard v${ROUTER_VERSION}"
  fi

  mkdir -p "$DSH_HOME/.agent-presets" "$ROUTER_DIR"
  src="$(router_source_dir)"
  tmp=""
  lic_src="$SCRIPT_DIR/preset"   # submodule 根部（含 LICENSE/NOTICE）

  if [ "$src" = "download" ]; then
    tmp="$DSH_HOME/.agent-presets/.router.tmp.$(ts)"
    mkdir -p "$tmp"
    CURRENT_TMP="$tmp"
    tgz="$tmp/dsh-router-standard-$ROUTER_VERSION.tgz"
    url="$ROUTER_REPO/releases/download/v$ROUTER_VERSION/dsh-router-standard-$ROUTER_VERSION.tgz"
    say "下载 ${ROUTER_VERSION} Release 包（submodule 不可用）"
    curl -fL --retry 2 --connect-timeout 20 -o "$tgz" "$url" || die "下载 Router Release 失败: $url"
    tar -xzf "$tgz" -C "$tmp" --strip-components=1 || die "解压 Router Release 包失败"
    rm -f "$tgz"
    [ -f "$tmp/preset/preset.yml" ] || die "Router Release 包缺少 preset/preset.yml"
    lic_src="$tmp"               # 包根（LICENSE/NOTICE 所在）
    src="$tmp/preset"
  fi

  say "安装 Router preset 到 $ROUTER_DIR"
  cp -R "$src/." "$ROUTER_DIR"

  # 顺带保留 LICENSE / NOTICE（存在才复制，缺失不阻塞）
  if [ -f "$lic_src/LICENSE" ] && [ ! -f "$ROUTER_DIR/LICENSE" ]; then
    cp "$lic_src/LICENSE" "$ROUTER_DIR/LICENSE"
  fi
  if [ -f "$lic_src/NOTICE" ] && [ ! -f "$ROUTER_DIR/NOTICE" ]; then
    cp "$lic_src/NOTICE" "$ROUTER_DIR/NOTICE"
  fi

  # 确认 preset 内容完整
  for f in preset.yml agent.cordis.yml router-bootstrap.mjs router-core.mjs; do
    [ -f "$ROUTER_DIR/$f" ] || die "Router preset 安装不完整（缺少 ${f}）"
  done
  printf '%s' "$ROUTER_VERSION" > "$ROUTER_DIR/.version"
  [ -n "$tmp" ] && rm -rf "$tmp"
  CURRENT_TMP=""
  ok "Router Standard v${ROUTER_VERSION} 已安装（${ROUTER_DIR}）"
}

# ---------------------------------------------------------------- 主流程

injector_install
router_install

say "${MODE_LABEL}完成"
if [ -x "$SCRIPT_DIR/check.sh" ]; then
  "$SCRIPT_DIR/check.sh" || true
fi
printf '\n重启 DSH（web 服务）后，在新会话中验证：\n'
printf '  dev_plugin_status   → dsh-super-injector active\n'
printf '  dev_self_test       → PASS\n'
printf '  dev_router_status   → Router Standard 正常显示\n'
