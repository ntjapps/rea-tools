# rea-tools

[REA (Reverse Engineer Anything)](https://github.com/ntjapps/rea) for Claude Code on hosts without Node, loaded
**on demand only**: a Claude Code skill (its one-line description is all a session carries until a reverse-engineering
task needs it) plus a `rea` CLI that runs in a memory-capped Docker container. The REA MCP server is deliberately not
registered.

| File | What it is |
|---|---|
| `Dockerfile` | Pinned images. `base`: Node 24 + `rea-agents` + procps (static JavaScript/Electron, .NET, Go, Rust, WASM, SQLite, packages). `native`: base + JDK 21 + Ghidra 12.1.4 + jadx-headless-mcp 0.7.1 (native binaries, Android APKs). Every download is checked against its SHA-256. |
| `rea` | The CLI wrapper. Builds `local/rea:<version>` or `local/rea:<version>-native` on first use, picks the native image for `--provider ghidra` and Android/APK/JADX commands (or `REA_NATIVE=1`), mounts `/home/GitProjects`, `/tmp` and the current directory at the same paths, and caps the container (`REA_MEMORY`, default 1500m base / 2g native; `REA_CPUS`, default 2). |
| `install-skill.sh` | Installs the `reverse-engineer-anything` skill from the `ntjapps/rea` fork at a pinned commit into `$CLAUDE_CONFIG_DIR/skills`, with this host's section (`claude/host-section.md`) inserted at the top. |
| `claude/host-section.md` | The host rules the skill follows: no MCP registration, use the `rea` CLI, memory checks, one heavy job at a time, no browser/Electron/process/device capture without an explicit instruction. |

## Setup

```bash
git clone https://github.com/ntjapps/rea-tools.git /home/GitProjects/rea-tools
/home/GitProjects/rea-tools/install-skill.sh          # skill, pinned commit
rea --version                                        # via stack-config/rea (on PATH); builds the base image once
REA_NATIVE=1 rea --version                           # builds the native image (Ghidra, JADX) once
```

`stack-config/rea` only forwards to `/home/GitProjects/rea-tools/rea`.

## Use

```bash
rea analyze-javascript-application /absolute/path/to/app --json
rea inspect /absolute/path/to/binary --provider ghidra --json
rea --help
```

Check `grep MemAvailable /proc/meminfo` first (at least 1 GB, about 2.2 GB for Ghidra) and run one REA job at a time.

## GitHub workflows (manual only)

Both run only from the Actions tab (`workflow_dispatch`); there are no push, tag or schedule triggers, and builds use
plain buildx (no Blacksmith).

- **Build REA images** (`build-images.yaml`): builds `base`, `native` or both and, on `main` with *publish* ticked,
  pushes `ghcr.io/ntjapps/rea-tools:<version>` and `:<version>-native`. The `rea` wrapper pulls these when the local
  image is missing and builds locally otherwise.
- **Check scripts** (`check.yaml`): `bash -n` and shellcheck on `rea` and `install-skill.sh`.

Branches: `main` (default) and `dev`; work goes into `dev`, `main` is promoted from it.

## Update

- REA: bump `REA_VERSION` in the `Dockerfile`, then `REA_REBUILD=1 rea --version` (and `REA_NATIVE=1 REA_REBUILD=1 rea --version`).
- Ghidra or JADX: change the URL and SHA-256 ARGs together, then rebuild the native image.
- Skill: `./install-skill.sh <fork commit>`.
