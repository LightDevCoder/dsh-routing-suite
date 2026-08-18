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

## 11. dev_self_test / dev_build_plugin 需要 DSH 源码 checkout

> 先判断是否需要：**创建/定制 preset（YAML 组合，如 Router Standard 的 preset）不需要
> checkout**——用 DSH 的"创造模式"（cordis preset）或直接编辑 `~/.dsh/.agent-presets/`
> 即可，全程无编译。checkout 只在**开发 TypeScript 插件**（tsc 编译 → lib/）时才需要。

注入器的自检（`dev_self_test`）与插件生产线（`dev_scaffold_plugin` → `dev_build_plugin`）
需要一个 DSH 源码 checkout：链接 `cordis` / `cosmokit` / `schemastery` /
`@deepseek-ai/dsh-tools` 等依赖并用 checkout 的 tsc 编译。

探测顺序：`DSH_CHECKOUT` 环境变量（须含 `packages/` 目录）→ `~/dsh-harness` →
`~/dsh` → `~/.dsh/dsh-harness`。用 npx/全局包方式安装 DSH 的机器没有源码目录，
自检第一项会报 `无 DSH_CHECKOUT`（注入器本身不受影响，注入/热重载/卸载照常）。

本机配置方法（源码快照 + 运行版本已构建包 + tsc 工具链）：

```bash
# 1. 源码快照（也可 git clone --depth 1 https://github.com/deepseek-ai/deepseek-harness.git ~/dsh-harness）
curl -fL -o /tmp/dsh-harness.tar.gz https://codeload.github.com/deepseek-ai/deepseek-harness/tar.gz/refs/heads/master
mkdir -p ~/dsh-harness && tar -xzf /tmp/dsh-harness.tar.gz -C ~/dsh-harness --strip-components=1

# 2. tsc 工具链（放 checkout 内 .toolchain，避免触发 monorepo 全量安装）
cd ~/dsh-harness && mkdir -p .toolchain
echo '{"name":"dsh-harness-toolchain","private":true,"version":"0.0.0"}' > .toolchain/package.json
(cd .toolchain && npm install --no-workspaces --no-audit --no-fund typescript@5 @types/node@24)
mkdir -p node_modules/.bin node_modules/@types
ln -sfn ../.toolchain/node_modules/typescript node_modules/typescript
ln -sfn ../../.toolchain/node_modules/@types/node node_modules/@types/node
ln -sfn ../../.toolchain/node_modules/.bin/tsc node_modules/.bin/tsc

# 3. 源码里未构建的包 → 替换为运行中 harness 同版本的已构建包（npx 安装路径按实际调整）
NPX="$(dirname "$(dirname "$(dirname "$(command -v dsh)")")")"   # 缓存根（含 node_modules/）
mv vendor/cordis vendor/cordis.src && mv vendor/cosmokit vendor/cosmokit.src
mv vendor/schemastery vendor/schemastery.src && mv packages/core/tools packages/core/tools.src
ln -s "$NPX/node_modules/@deepseek-ai/cordis" vendor/cordis
ln -s "$NPX/node_modules/@deepseek-ai/cosmokit" vendor/cosmokit
ln -s "$NPX/node_modules/@deepseek-ai/schemastery" vendor/schemastery
ln -s "$NPX/node_modules/@deepseek-ai/dsh-tools" packages/core/tools

# 4. pnpm store 布局（build.sh 用 find node_modules/.pnpm 找 @standard-schema）
SSV="$(node -pe "require('$NPX/node_modules/@standard-schema/spec/package.json').version")"
mkdir -p "node_modules/.pnpm/@standard-schema+spec@$SSV/node_modules/@standard-schema"
ln -s "$NPX/node_modules/@standard-schema/spec" "node_modules/.pnpm/@standard-schema+spec@$SSV/node_modules/@standard-schema/spec"
```

完成后 `dev_self_test` 预期 8/8 PASS（构建 → 注入 → 热重载 → 节流 → 预检拦截 → 卸载 → patch 合法性）。
注意：若日后重装 DSH（npx 缓存哈希变化），第 3、4 步的链接会失效，需要重新执行。

## 12. 设置中多出重复且空白的「⚙️ 插件」菜单

- **原因**：上游 `dsh-super-injector` 注册了一个实验性的 `settings.section` 前端插槽，固定命名为 `'插件'`（与 DSH 原生插件设置冲突），且其前端组件缺少 DOM 挂载逻辑导致点开后页面空白。
- **本 fork 处理**：安装脚本在装配时会自动剥离注入器 `package.json` 中的 `dsh.client` 字段，保留全部核心后端注入、热重载与 Agent 工具能力，避免前端出现多余的空白设置项。
- **已安装环境修复**：重新执行 `./install.sh`（或手动删除 `~/.dsh/local-plugins/dsh-super-injector/package.json` 中的 `dsh.client` 配置块）并重启 DSH 即可。
