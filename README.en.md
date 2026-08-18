# dsh-routing-suite — Personal DSH Distribution & Routing Suite

[中文](README.md) | English

> A personal distribution based on [yjh051108/dsh-routing-suite](https://github.com/yjh051108/dsh-routing-suite) (fork: LightDevCoder/dsh-routing-suite).
> Upstream is retained as `upstream`, and community improvements are synchronized as needed (see [docs/UPSTREAM.md](docs/UPSTREAM.md)).

## Quick Start (macOS / Linux)

```bash
git clone --recurse-submodules https://github.com/LightDevCoder/dsh-routing-suite.git
cd dsh-routing-suite
chmod +x install.sh
./install.sh
```

After installation → **Restart DSH (web service)** → Select `Router Standard (experimental)` or `Router Deep (experimental)` preset in a new session.

For Windows users using [install.ps1](install.ps1) (PowerShell):

```powershell
git clone --recurse-submodules https://github.com/LightDevCoder/dsh-routing-suite.git
cd dsh-routing-suite
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## What is this

A **long-term personal DSH distribution / bootstrap repository**. It does not rewrite component internals, but stably packages:

```
DSH + dsh-super-injector + dsh-router-standard (Standard & Deep)
```

into a **reproducible, upgradeable, and rollback-ready** personal workspace:

| Layer | Content | Responsibility |
|---|---|---|
| Upstream Components | [dsh-super-injector](https://github.com/yjh051108/dsh-super-injector) · [dsh-router-standard](https://github.com/yjh051108/dsh-router-standard) | Keep upstream, do not fork, preserve internal logic |
| Personal Distribution Layer | `install.sh` / `install.ps1` / `update.sh` / `check.sh` / `versions.json` / `docs/` | Version locking, installation, update, verification, docs |

## Key Features

- **Version Locking**: Strictly locked via `versions.json` (injector **v0.3.3** / router **v0.2.0**).
- **Dual Presets**: Installs both `Router Standard` (RL-interface restoration) and `Router Deep` (deep-think-first mode).
- **One-Click Install**: Supports macOS/Linux (`install.sh`) and Windows (`install.ps1`) with automatic dependency preflight checks.
- **Idempotent Re-install & Safe Backup**: Auto-backs up existing versions before reinstalling/upgrading.
- **Controlled Upgrades**: Run `./update.sh` to safely upgrade to locked versions.
- **Health Checks**: Run `./check.sh` anytime to verify CLI, directories, registration, and presets.
- **Clean UI**: Automatically strips unready client slot declarations from the injector to prevent duplicate blank plugin settings pages.

## Preset Descriptions

| Preset | Use Cases | Mechanism & Features |
|---|---|---|
| **`Router Standard (experimental)`** | Rapid daily dev, bug fixes, refactoring | **RL-Interface Restoration**: Single minimal persona sentence + core tool set (`read`/`edit`/`glob`/`grep`), rapid think-act feedback loops. |
| **`Router Deep (experimental)`** | Complex architecture, hard bugs, deep design | **Deep-Think-First Mode** (renamed from `router-spec`): Classified persona + full prompt sections, allowing long first-turn reasoning chains. |

> Both presets automatically restore the full Standard tool surface after the first durable tool call (`tool/call`), retain session modes across turns, and provide `dev_router_status` diagnostics.

## Verification

After restarting DSH, run these in a new session:

```
dev_plugin_status
dev_self_test
dev_router_status
```

Expected output:

```
dev_plugin_status
→ dsh-super-injector active

dev_self_test
→ PASS

dev_router_status
→ Shows mode / band / persona / core tools for the active preset
```

Run health checks anytime:

```
DSH CLI                OK
DSH_HOME               /Users/.../.dsh
Injector files         OK
Injector registration  OK
Router Standard        OK
Router Deep            OK
Injector version       OK
Router Std ver         OK
Router Deep ver        OK

Environment ready.
```

## Rollback

- **Router**: Pre-upgrade presets are backed up to `${DSH_HOME}/.agent-presets/router-standard.bak.<timestamp>` and `router-deep.bak.<timestamp>`. To restore: delete the current directory and rename the backup folder.
- **Injector**: Old versions are backed up to `${DSH_HOME}/local-plugins/dsh-super-injector.bak.<timestamp>`.
- See [docs/UPDATE.md](docs/UPDATE.md) for full rollback details.

## Upstream Sources

| Role | Repository |
|---|---|
| Suite Upstream | [yjh051108/dsh-routing-suite](https://github.com/yjh051108/dsh-routing-suite) |
| Injector Upstream | [yjh051108/dsh-super-injector](https://github.com/yjh051108/dsh-super-injector) |
| Router Upstream | [yjh051108/dsh-router-standard](https://github.com/yjh051108/dsh-router-standard) |

## Repository Structure

```
dsh-routing-suite/
├── README.md
├── README.en.md
├── LICENSE
├── NOTICE
├── versions.json        # Version lock (single source of truth)
├── install.sh           # macOS/Linux installer
├── install.ps1          # Windows installer
├── update.sh            # Controlled upgrade script
├── check.sh             # Health check script
├── injector/            # submodule @ v0.3.3
├── preset/              # submodule @ v0.2.0
└── docs/
    ├── INSTALL.md
    ├── UPDATE.md
    ├── TROUBLESHOOTING.md
    └── UPSTREAM.md
```

## Documentation

- [docs/INSTALL.md](docs/INSTALL.md) — Detailed installation guide
- [docs/UPDATE.md](docs/UPDATE.md) — Updates and rollbacks
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — Troubleshooting
- [docs/UPSTREAM.md](docs/UPSTREAM.md) — Upstream relationships and sync workflow

## License

MIT. Credits: xiaobright/modeltest (V4.1b evaluation), xiaobright/dsh-anchored-standard (anchoring mechanism).
