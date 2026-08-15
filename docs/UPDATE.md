# 更新与回滚

## 1. 更新流程（用户视角）

```bash
git pull                     # 拉到新版本（含 versions.json 变更）
./update.sh                  # 受控升级 + health check
```

`update.sh` 等价于 `install.sh --update`，流程：

```
读取 versions.json
    ↓
检查当前安装版本
    ↓
更新 injector（版本不一致 → 备份 → 安装锁定 Release → 重新装配 profile）
    ↓
更新 router（版本不一致 → 备份 → 安装锁定 preset）
    ↓
保留旧配置备份（*.bak.<时间戳>）
    ↓
执行 health check
```

## 2. 版本发布流程（仓库维护者视角）

个人仓库是"受控升级"模型，**不自动跟随 upstream main**：

```
发现 upstream 新版本（Release / changelog）
    ↓
查看 changelog，确认值得升级
    ↓
修改 versions.json（新版本号）
    ↓
本地安装测试（./install.sh 或 ./update.sh）
    ↓
./check.sh 通过
    ↓
commit + push
```

## 3. 回滚

### Router

升级前旧 preset 自动备份在：

```
${DSH_HOME}/.agent-presets/router-standard.bak.<时间戳>
```

恢复：

```bash
cd ~/.dsh/.agent-presets
rm -rf router-standard
mv router-standard.bak.<时间戳> router-standard
```

### Injector

旧版本自动备份在：

```
${DSH_HOME}/local-plugins/dsh-super-injector.bak.<时间戳>
```

恢复：

```bash
cd ~/.dsh/local-plugins
rm -rf dsh-super-injector
mv dsh-super-injector.bak.<时间戳> dsh-super-injector
dsh plugin --profile web add ~/.dsh/local-plugins/dsh-super-injector
```

### 回滚后

- 重启 DSH，新会话验证 `dev_plugin_status` / `dev_router_status`
- `./check.sh` 会显示已安装版本与 versions.json 锁定版本的差异

## 4. 备份清理

安装器只新增备份、从不删除。确认环境稳定后手动清理旧备份：

```bash
ls ~/.dsh/.agent-presets/router-standard.bak.* ~/.dsh/local-plugins/dsh-super-injector.bak.*
# 确认无需回滚后：
rm -rf ~/.dsh/.agent-presets/router-standard.bak.* ~/.dsh/local-plugins/dsh-super-injector.bak.*
```
