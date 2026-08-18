# Upstream 关系与同步策略

## 1. 三个 upstream

| 角色 | 仓库 | 本仓库中的角色 |
|---|---|---|
| suite upstream | [yjh051108/dsh-routing-suite](https://github.com/yjh051108/dsh-routing-suite) | git remote 中的 upstream；保留原始 fork 关系 |
| injector upstream | [yjh051108/dsh-super-injector](https://github.com/yjh051108/dsh-super-injector) | submodule `injector/`（锁定在 Release tag）；安装来源为 Release tgz |
| router upstream | [yjh051108/dsh-router-standard](https://github.com/yjh051108/dsh-router-standard) | submodule `preset/`（锁定在 Release tag）；安装来源为 submodule 或 Release tgz |

## 2. 版本锁定原则

- `versions.json` 是**唯一版本来源**：安装器/更新器/健康检查都读它
- submodule 指针锁定在对应 Release tag（`injector` → v0.3.3，`preset` → v0.2.0）
- 不直接无条件追踪两个组件 upstream 的 `main`
- upstream `main` 更新**不会**自动改变个人生产环境；是否升级由维护者查看 changelog 后决定（见 docs/UPDATE.md 的发布流程）

## 3. 同步 suite upstream

```bash
git fetch upstream
git log --oneline HEAD..upstream/main    # 先看 upstream 有哪些新改动
```

然后**逐个审阅**，决定吸收哪些：

```bash
git diff HEAD..upstream/main -- <文件>   # 看具体改动
git cherry-pick <commit>                 # 吸收单个 commit（推荐）
```

**不要**盲目 `git merge upstream/main`，尤其注意：

- 安装器（`install.sh` / `install.ps1`）以个人版本为准——upstream 对安装器的修改默认不直接覆盖
- 本仓库新增的文件（`versions.json`、`update.sh`、`check.sh`、`docs/`）upstream 没有对应物，同步时注意不要被上游改动替代
- 同步后更新 submodule 指针要对照 `versions.json`：只指向锁定 tag

## 4. 什么时候 fork 组件仓库

当前阶段**不 fork** `dsh-super-injector` / `dsh-router-standard`，继续使用原作者仓库：

| 组件 | fork 条件 |
|---|---|
| dsh-super-injector | 尽量长期保持 upstream |
| dsh-router-standard | 仅当实际使用中发现路由行为不符合个人工作方式，才单独建立 Router customization task 并 fork |

> 原则：个人仓库只负责"版本选择 / 安装 / 配置 / 更新 / 验证 / 文档"，不重写组件内部逻辑（spec/react/weak/mixed、Pro/Flash persona 路由均保持 upstream 行为）。

## 5. 组件升级检查清单

```
1. 查看 upstream Releases / CHANGELOG
2. 确认新版本是稳定 Release（非 rc/实验分支）
3. 更新 versions.json
4. 更新对应 submodule 指针到新 tag
5. 本地 ./install.sh 或 ./update.sh 实测
6. ./check.sh 全部 OK
7. 重启 DSH 验证 dev_plugin_status / dev_self_test / dev_router_status
8. commit + push
```
