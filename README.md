# dsh-routing-suite — 个人 DSH 安装与路由发行仓库

[中文](README.md) | [English](README.en.md)

> 这是基于 [yjh051108/dsh-routing-suite](https://github.com/yjh051108/dsh-routing-suite) 的个人维护版本（fork：LightDevCoder/dsh-routing-suite）。
> 原仓库保留为 `upstream`，公共改进会按需同步（见 [docs/UPSTREAM.md](docs/UPSTREAM.md)）。

## Quick Start（macOS / Linux）

```bash
git clone --recurse-submodules https://github.com/LightDevCoder/dsh-routing-suite.git
cd dsh-routing-suite
chmod +x install.sh
./install.sh
```

安装完成 → **重启 DSH（web 服务）** → 新会话选择 `Router Standard (experimental)` 或 `Router Deep (experimental)` preset。

Windows 用户使用 [install.ps1](install.ps1)（PowerShell）：

```powershell
git clone --recurse-submodules https://github.com/LightDevCoder/dsh-routing-suite.git
cd dsh-routing-suite
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## 这是什么

一套**个人长期使用的 DSH distribution / bootstrap 仓库**。它不重新实现任何组件，只负责稳定地把

```
DSH + dsh-super-injector + dsh-router-standard (Standard & Deep)
```

装成一套**可重复部署、可升级、可回滚**的个人工作环境：

| 层 | 内容 | 责任 |
|---|---|---|
| upstream 组件 | [dsh-super-injector](https://github.com/yjh051108/dsh-super-injector) · [dsh-router-standard](https://github.com/yjh051108/dsh-router-standard) | 保持 upstream，不 fork、不改内部逻辑 |
| 个人发行层 | `install.sh` / `install.ps1` / `update.sh` / `check.sh` / `versions.json` / `docs/` | 版本选择、安装、更新、验证、文档 |

## 为什么有这个 fork

原仓库是作者的 demo/kit（submodule + 手动步骤）。个人使用需要：

- **版本锁**：不追踪 upstream `main`，一切以 `versions.json` 为准（当前 injector **v0.3.3** / router **v0.2.0**）
- **macOS 一键安装**：injector 从上游 Release 下载锁定版本 tgz，无需本地构建
- **双预设就绪**：一键装配 `Router Standard`（RL 接口还原模式）与 `Router Deep`（深度思考优先模式）
- **幂等重装**：重复执行不破坏环境；旧版本自动备份
- **受控升级**：`./update.sh` 按版本锁升级，不自动跟随 upstream 发布
- **健康检查**：`./check.sh` 一键判断环境状态

## 组件与版本

| 路径 | 组件仓库 | 锁定版本 | 说明 |
|---|---|---|---|
| `injector/` (submodule) | [dsh-super-injector](https://github.com/yjh051108/dsh-super-injector) | [v0.3.3](https://github.com/yjh051108/dsh-super-injector/releases/tag/v0.3.3) | 运行时注入器：dev_* 工具全家桶 |
| `preset/` (submodule) | [dsh-router-standard](https://github.com/yjh051108/dsh-router-standard) | [v0.2.0](https://github.com/yjh051108/dsh-router-standard/releases/tag/v0.2.0) | 思维模式路由双预设：`router-standard` (RL 接口还原) 与 `router-deep` (深度思考优先) |

> 版本号唯一来源是 [versions.json](versions.json)。submodule 指针与 Release 均锁定在对应 tag。

## 如何安装

`./install.sh` 会依次：

1. **Preflight**：检查 macOS/Linux、`git`、`node`、`dsh`、`curl`、`tar`、`pnpm`（缺 pnpm 时自动尝试 `corepack enable pnpm`）；缺关键依赖即停止，不做任何修改
2. **安装注入器**：从上游 Release 下载 `dsh-external-dsh-super-injector-<版本>.tgz` → 解压到 `${DSH_HOME:-~/.dsh}/local-plugins/dsh-super-injector` → 自动剥离未就绪的 client 前端声明 → `dsh plugin --profile web add`
3. **安装 Router 双预设**：
   - `router-standard` 安装到 `${DSH_HOME:-~/.dsh}/.agent-presets/router-standard`（RL 接口还原模式）
   - `router-deep`（原 router-spec）安装到 `${DSH_HOME:-~/.dsh}/.agent-presets/router-deep`（深度思考优先模式）
   - 已存在旧版本时自动备份为 `*.bak.<时间戳>`
4. **执行 health check** 并输出结果

重复执行安全：同版本直接跳过，旧版本/不完整安装会先备份再处理。

环境变量：

| 变量 | 默认 | 说明 |
|---|---|---|
| `DSH_HOME` | `~/.dsh` | DSH 数据根目录（安装脚本优先尊重它） |
| `DSH_PROFILE` | `web` | 装配注入器的 profile 名 |

## 如何更新

仓库维护者（我）发布新版本后：

```bash
git pull
./update.sh
```

`update.sh` = 受控升级：读取 `versions.json` → 对比已安装版本 → 升级 injector / router（旧版本自动备份）→ health check。它不会自动寻找 GitHub 最新 Release——版本升级始终由 `versions.json` 决定。

## 如何验证

安装/更新后**重启 DSH**，在新会话中依次执行：

```
dev_plugin_status
dev_self_test
dev_router_status
```

> 说明：`dev_router_status` 属于 Router Standard preset（agent-plane），需在选择了
> "Router Standard (experimental)" 的新会话中使用；`dev_self_test` 需要 DSH 源码
> checkout（`DSH_CHECKOUT` 或 `~/dsh-harness`），配置见 docs/TROUBLESHOOTING.md §11。

预期：

```
dev_plugin_status
→ dsh-super-injector active

dev_self_test
→ PASS

dev_router_status
→ Router Standard：mode / band / persona / core tools 正常显示
```

随时可用 `./check.sh` 做环境健康检查：

```
DSH CLI                OK
Injector files         OK
Injector registration  OK
Router preset          OK

Environment ready.
```

## 如何回滚

- **Router**：升级前旧 preset 自动备份为 `${DSH_HOME}/.agent-presets/router-standard.bak.<时间戳>`，恢复：删掉当前目录，把备份改名为 `router-standard` 即可
- **注入器**：旧版本备份在 `${DSH_HOME}/local-plugins/dsh-super-injector.bak.<时间戳>`；恢复后重新执行 `dsh plugin --profile web add <目录>`
- 详细步骤见 [docs/UPDATE.md](docs/UPDATE.md) 的 Rollback 一节

## Upstream 来自哪里

| 角色 | 仓库 |
|---|---|
| suite upstream | [yjh051108/dsh-routing-suite](https://github.com/yjh051108/dsh-routing-suite) |
| injector upstream | [yjh051108/dsh-super-injector](https://github.com/yjh051108/dsh-super-injector) |
| router upstream | [yjh051108/dsh-router-standard](https://github.com/yjh051108/dsh-router-standard) |

同步策略：`git fetch upstream` → 先审阅改动 → 决定是否吸收；安装器类文件以个人版本为准（详见 [docs/UPSTREAM.md](docs/UPSTREAM.md)）。

## 目录结构

```
dsh-routing-suite/
├── README.md
├── LICENSE
├── NOTICE
├── versions.json        # 版本锁（唯一版本来源）
├── install.sh           # macOS/Linux 安装器
├── install.ps1          # Windows 安装器（行为对齐）
├── update.sh            # 受控升级
├── check.sh             # 健康检查
├── injector/            # submodule @ v0.3.3
├── preset/              # submodule @ v0.1.1
└── docs/
    ├── INSTALL.md
    ├── UPDATE.md
    ├── TROUBLESHOOTING.md
    └── UPSTREAM.md
```

## 文档

- [docs/INSTALL.md](docs/INSTALL.md) — 详细安装指南
- [docs/UPDATE.md](docs/UPDATE.md) — 更新与回滚
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — 常见问题排查
- [docs/UPSTREAM.md](docs/UPSTREAM.md) — upstream 关系与同步流程

## 许可证

MIT，见 [LICENSE](LICENSE)。组件归属见 [NOTICE](NOTICE)。
