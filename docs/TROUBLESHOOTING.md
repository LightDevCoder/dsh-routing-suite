# 故障排查

## 1. 安装器报"缺少关键依赖"

| 缺失项 | 解决 |
|---|---|
| `dsh` | 先安装 DeepSeek Harness；确认 `dsh` 在 PATH 中（`command -v dsh`） |
| `node` | 安装 Node.js ≥ 18（建议用 nvm） |
| `pnpm` | 执行 `corepack enable pnpm` 或 `npm install -g pnpm` 后重跑 |
| `git` / `curl` / `tar` | 系统自带，缺失时用 Homebrew 安装 |

## 2. 下载 Release 失败（curl 报错）

- 检查网络与代理：`curl -I https://github.com`
- 确认版本号正确：`versions.json` 中的版本必须能在 upstream Releases 找到（tag 为 `v<版本>`，资产名为 `dsh-external-dsh-super-injector-<版本>.tgz` / `dsh-router-standard-<版本>.tgz`）
- 安装器支持重试（`curl --retry 2`），持续失败多为网络/代理问题

## 3. `dsh plugin --profile web add` 失败

- 确认 `pnpm` 可用（`pnpm --version`）
- 确认 `$DSH_HOME/profiles/web` 可写
- 查看输出：pnpm 报错通常是 manifest/网络问题；dsh 报错通常是 bundle 声明问题

> 注意：注入器目录已存在且版本一致时，`install.sh` 会跳过整个步骤（含装配）。
> 若需要强制重新装配，先删除注入器目录或使用 `./install.sh --force`。

## 4. check.sh 显示 Injector registration FAIL

说明 `@dsh-external/dsh-super-injector` 没有进入 web profile 的 bundles 层：

```bash
cat ~/.dsh/profiles/web/package.json   # 查看 dependencies 与 dsh.profile.bundles
```

修复：`dsh plugin --profile web add ~/.dsh/local-plugins/dsh-super-injector`，然后 `./check.sh`。

## 5. check.sh 显示版本 MISMATCH

已安装版本与 `versions.json` 锁定版本不一致：运行 `./update.sh` 完成受控升级。

## 6. 重启 DSH 后看不到 Router Standard preset

- 确认 preset 目录存在且完整：`ls ~/.dsh/.agent-presets/router-standard/`（应有 `preset.yml`、`agent.cordis.yml`、`router-bootstrap.mjs`、`router-core.mjs`）
- 确认 `preset.yml` 的 `name` 字段（新会话 preset 列表中显示的名称）
- 重启是否真正完成：完全退出 DSH web 进程后再启动
- 检查 DSH 日志中有无 preset 挂载报错（`agent-presets: ... failed to mount`）

## 7. dev_plugin_status 不显示 dsh-super-injector

- 注入器是 bundle，**重启后生效**（当前运行的 web 进程不会热加载新 bundle）
- 确认 bundle 已注册：`cat ~/.dsh/profiles/web/package.json` 中 `dsh.profile.bundles` 应包含 `@dsh-external/dsh-super-injector`
- 若还是不行，用 `dev_self_test` 看自检输出，按提示处理

## 8. DSH_HOME 相关问题

- 安装器与 DSH 运行时使用同一 `DSH_HOME`：安装时设置了 `DSH_HOME` 环境变量，启动 DSH 时也要一致
- 检查：`./check.sh` 第一行会显示实际使用的 `DSH_HOME`

## 9. Windows（install.ps1）

- PowerShell 5.1+；`tar` 使用 Windows 10+ 自带的 bsdtar
- 需要 Git for Windows（提供 git）；`dsh`、`node`、`pnpm` 需加入 PATH
- `pnpm` 缺失时：`corepack enable pnpm`（在支持 corepack 的 Node 上）或 `npm install -g pnpm`

## 10. 其他

- 备份目录（`*.bak.<时间戳>`）累积：见 docs/UPDATE.md 的备份清理一节
- 注入器/路由器本身的问题请先查各自 upstream 仓库的 README/文档，再考虑上报
