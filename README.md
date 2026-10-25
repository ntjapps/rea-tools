# rea-tools

[REA (Reverse Engineer Anything)](https://github.com/ntjapps/rea) for Claude Code on hosts without Node, loaded
**on demand only**: a Claude Code skill (its one-line description is all a session carries until a reverse-engineering
task needs it) plus a `rea` CLI that runs in a memory-capped Docker container. The REA MCP server is deliberately not
registered.

| File | What it is |
|---|---|
| `Dockerfile` | Pinned images. `base`: Node 26 + `rea-agents` + procps (static JavaScript/Electron, .NET, Go, Rust, WASM, SQLite, packages). `native`: base + JDK 27 + Ghidra 12.2 + jadx-headless-mcp 0.8.0 (native binaries, Android APKs). Every download is checked against its SHA-256. |
| `rea` | The CLI wrapper. Builds `local/rea:<version>` or `local/rea:<version>-native` on first use, picks the native image for `--provider ghidra` and Android/APK/JADX commands (or `REA_NATIVE=1`), mounts `/home/GitProjects`, `/tmp` and the current directory at the same paths, caps the container (`REA_MEMORY`, default 1500m base / 2g native; `REA_CPUS`, default 2), and passes REA's own `REA_*` settings (e.g. `REA_GHIDRA_DISABLED_ANALYZERS`) into the container. |
| `install-skill.sh` | Installs the `reverse-engineer-anything` skill from the `ntjapps/rea` fork at a pinned commit into `$CLAUDE_CONFIG_DIR/skills`, with this host's section (`claude/host-section.md`) inserted at the top. |
| `claude/host-section.md` | The host rules the skill follows: no MCP registration, use the `rea` CLI, memory checks, one heavy job at a time, no browser/Electron/process/device capture without an explicit instruction. |

## How it fits together

```
Claude Code session
  └─ skill "reverse-engineer-anything"  (~/.claude/skills; loaded only when a task needs it)
       └─ Bash: rea <command> ... --json
            └─ stack-config/rea  ->  rea-tools/rea  (wrapper)
                 └─ capped container (--memory/--cpus): local/rea:<version>[-native], REA CLI inside
                      sees /home/GitProjects, /tmp and $PWD at the same absolute paths
```

No Node, Ghidra or Java on the host, and no MCP server: Claude calls the REA CLI through Bash, one capped container per
command. REA's state (analysis snapshots, config) persists in `~/.local/share/rea-docker` (`REA_STATE`), mounted as the
container's home.

## Setup (Claude Code + REA in a container)

Prerequisites: Docker, `gh` logged in (the skill installer reads the `ntjapps/rea` fork through the GitHub API) and
`python3`.

1. **Clone and put `rea` on PATH.**

   ```bash
   git clone https://github.com/ntjapps/rea-tools.git /home/GitProjects/rea-tools
   command -v rea          # /home/GitProjects/stack-config/rea on hosts with stack-config on PATH
   ```

   `stack-config/rea` only forwards to `/home/GitProjects/rea-tools/rea`. On a host without stack-config, link the
   wrapper instead: `ln -s /home/GitProjects/rea-tools/rea ~/.local/bin/rea`.

2. **Install the skill** (pinned fork commit plus `claude/host-section.md`; an existing copy is backed up first):

   ```bash
   /home/GitProjects/rea-tools/install-skill.sh
   ```

3. **Get the images** (once per REA version). Check `free -m` first. The wrapper pulls
   `ghcr.io/ntjapps/rea-tools:<version>[-native]` when available and otherwise builds locally (about 1 min base, 2 min
   native):

   ```bash
   rea --version                 # base image: JavaScript/Electron, .NET, Go, Rust, WASM, SQLite, packages
   REA_NATIVE=1 rea --version    # native image: + JDK 27, Ghidra, JADX
   ```

   If the GHCR package is private, log Docker in first, otherwise the wrapper silently builds locally:
   `gh auth token | docker login ghcr.io -u <github-user> --password-stdin` (the token needs `read:packages`).

4. **Check REA inside the container:**

   ```bash
   REA_NATIVE=1 rea doctor --json
   ```

   Expected: `node`, `ghidra*` and `jadx` are `ok`. `hopper`, `ida-registration` and `skill:identity` report false by
   design (not installed; the skill lives in Claude Code, not in the container). Do not run `rea setup` to "fix" them.

5. **Optional: allow `rea` without prompts.** In `~/.claude/settings.json` add `"Bash(rea:*)"` to
   `permissions.allow`.

6. **Start a new Claude Code session.** Skills load at session start; `reverse-engineer-anything` should appear in the
   skill list.

## Use from Claude Code

Ask for the task in plain words; the skill loads on demand and Claude runs `rea` through Bash:

- "Reverse engineer `/home/GitProjects/x/app.asar` and explain how login works."
- "Decompile `main` in `/tmp/samples/tool` with Ghidra."
- "What changed between `/tmp/a.apk` and `/tmp/b.apk`?"

Or invoke it explicitly: `/reverse-engineer-anything <task>`.

Rules the skill follows on this host (from `claude/host-section.md`):

- **Paths:** targets must be absolute paths under `/home/GitProjects`, `/tmp` or the session's current directory;
  nothing else is mounted in the container. Copy a target there first.
- **One heavy job at a time:** memory is checked before each run; Ghidra/JADX runs are treated like a test suite.
- **No live capture without an explicit instruction:** browser/Electron/native-UI/process capture, adb device actions
  and network capture run only when you ask for them in that message.
- **No MCP registration:** missing REA MCP tools are expected; Claude uses the CLI.

## Use directly

```bash
rea analyze-javascript-application /absolute/path/to/app --json
rea inspect /absolute/path/to/binary --provider ghidra --json
rea inspect-go-binary /absolute/path/to/go-binary --json
rea --help                       # all commands; rea <command> --help for flags
```

Check `grep MemAvailable /proc/meminfo` first (at least 1 GB, about 2.2 GB for Ghidra) and run one REA job at a time.

Ghidra on a large binary (measured: an 11.8 MB Rust binary) runs out of the 2g native cap during auto-analysis, mostly in
the decompiler worker processes, and is OOM-killed inside the container (`Ghidra exited before bridge startup`,
`SIGKILL`). Disable switch analysis instead of raising the cap; with this it completed at 2g in about 5 minutes, close to
REA's 330 s startup limit:

```bash
REA_GHIDRA_DISABLED_ANALYZERS="Decompiler Switch Analysis" rea inspect /abs/path/big-binary --provider ghidra --json
```

Small binaries need nothing extra (a 97 KB ELF: about 40 s). Every `REA_*` variable other than the wrapper's own
(`REA_MEMORY`, `REA_CPUS`, `REA_NATIVE`, `REA_REBUILD`, `REA_STATE`, `REA_TOOLS_DIR`) is passed into the container.

## GitHub workflows (manual only)

Both run only from the Actions tab (`workflow_dispatch`); there are no push, tag or schedule triggers, and builds use
plain buildx (no Blacksmith).

- **Build REA images** (`build-images.yaml`): builds `base`, `native` or both and, on `main` with *publish* ticked,
  pushes `ghcr.io/ntjapps/rea-tools:<version>` and `:<version>-native`. The `rea` wrapper pulls these when the local
  image is missing and builds locally otherwise.
- **Check scripts** (`check.yaml`): `bash -n` and shellcheck on `rea` and `install-skill.sh`.

Branches: `main` (default) and `dev`; work goes into `dev`, `main` is promoted from it.

## Releases and tags

- No release tags: `main` is the release. Work branches off `dev`, PRs go into `dev`, and `dev` -> `main` happens only by promotion when the owner says so. Do not create `v*` tags here.
- The image version comes from `REA_VERSION` in the `Dockerfile`, not from a git tag. The owner publishes `ghcr.io/ntjapps/rea-tools` by dispatching `build-images.yaml` on `main` and installs with the Setup and Update steps below; deploys are never run by CI.

## Update

- REA: bump `REA_VERSION` in the `Dockerfile`, then `REA_REBUILD=1 rea --version` (and `REA_NATIVE=1 REA_REBUILD=1 rea --version`).
- Ghidra or JADX: change the URL and SHA-256 ARGs together, then rebuild the native image.
- Skill: `./install-skill.sh <fork commit>`, then start a new Claude Code session. Re-run it after
  `claude/host-section.md` changes too.

## Remove

```bash
rm -rf ~/.claude/skills/reverse-engineer-anything ~/.claude/skills/reverse-engineer-anything.bak-*
docker rmi local/rea:<version> local/rea:<version>-native
rm -rf ~/.local/share/rea-docker      # REA state
```
