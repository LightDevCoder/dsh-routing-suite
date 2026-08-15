# 安装指南（macOS / Linux）

## 1. 前置要求

安装器 preflight 会自动检查以下依赖，缺失时**明确报错并停止**（不会留下半安装状态）：

| 依赖 | 用途 | 缺失时 |
|---|---|---|
| macOS 或 Linux | 平台 | Windows 请用 install.ps1 |
| `git` | 拉取仓库 / submodule | 安装 git |
| `node` | 解析 versions.json、DSH 运行时 | 安装 Node.js（≥18） |
| `dsh` | DSH CLI（安装器装配插件） | 先安装 DeepSeek Harness |
| `curl` | 下载 Release 包 | macOS/Linux 自带 |
| `tar` | 解压 Release 包 | macOS/Linux 自带 |
| `pnpm` | `dsh plugin` 底层包管理 | 自动尝试 `corepack enable pnpm`；仍失败则 `npm install -g pnpm` |

## 2. 安装

```bash
git clone --recurse-submodules https://github.com/LightDevCoder/dsh-routing-suite.git
cd dsh-routing-suite
chmod +x install.sh
./install.sh
```

> 提示：没有 `--recurse-submodules` 也能安装——安装器对 injector 始终使用 Release tgz，
> router 在 submodule 缺失时会自动回退到 Release tgz 下载。

## 3. 安装了什么

| 内容 | 位置 | 版本来源 |
|---|---|---|
| Super Injector 插件 | `${DSH_HOME:-~/.dsh}/local-plugins/dsh-super-injector` | versions.json（Release tgz） |
| Injector 注册 | `${DSH_HOME:-~/.dsh}/profiles/web/package.json`（dependencies + bundles） | 安装器执行 `dsh plugin --profile web add` |
| Router Standard preset | `${DSH_HOME:-~/.dsh}/.agent-presets/router-standard/` | versions.json（submodule 或 Release tgz） |
| 版本标记 | 上述目录内的 `.version` 文件 | 安装器写入 |

`DSH_HOME` 优先尊重环境变量；未设置时默认 `~/.dsh`。

## 4. 安装后验证

**重启 DSH（web 服务）**，然后：

1. 新会话选择 `Router Standard (experimental)` preset
2. 依次执行 `dev_plugin_status` → `dev_self_test` → `dev_router_status`
3. 预期：injector active、self-test PASS、router 正常显示 mode / band / persona / core tools

> 注：`dev_self_test` 与插件生产线（dev_scaffold_plugin → dev_build_plugin）需要 DSH 源码
> checkout（探测 `DSH_CHECKOUT` / `~/dsh-harness`）；缺省时自检第一项报"无 DSH_CHECKOUT"，
> 不影响注入器本身。配置方法见 docs/TROUBLESHOOTING.md §11。
> `dev_router_status` 是 Router Standard preset 的 agent-plane 工具，须在选择了
> "Router Standard (experimental)" 的新会话中使用。

也可随时运行 `./check.sh` 检查环境状态。

## 5. 重复安装

`./install.sh` 可重复执行：

| 状态 | 行为 |
|---|---|
| 未安装 | 全新安装 |
| 同版本 | 跳过，提示已安装，继续 health check |
| 旧版本 / 版本不一致 | 备份（`*.bak.<时间戳>`）→ 重装 |
| 安装不完整 | 备份 → 重装 |
| 强制重装 | `./install.sh --force`（也用于修复） |

## 6. 卸载

本套件不提供自动卸载脚本，手动步骤：

```bash
# 1. 从 web profile 移除注入器
dsh plugin --profile web remove @dsh-external/dsh-super-injector
# 2. 删除本地插件目录
rm -rf ~/.dsh/local-plugins/dsh-super-injector
# 3. 删除 router preset
rm -rf ~/.dsh/.agent-presets/router-standard
```

> 如版本升级过，`.bak.<时间戳>` 备份会保留，确认无误后可手动清理。
