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

## Verification

After restarting DSH, run these in a new session:

1. `dev_plugin_status` → Verify `dsh-super-injector` is active
2. `dev_self_test` → PASS
3. Preset Selection → Choose `Router Standard (experimental)` or `Router Deep (experimental)`
4. `dev_router_status` → Verify router preset is active and running

## License

MIT. Credits: xiaobright/modeltest (V4.1b evaluation), xiaobright/dsh-anchored-standard (anchoring mechanism).
