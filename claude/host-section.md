## This host (read first; overrides the setup steps below)

- **On demand by design (user, 2026-10-16):** the REA MCP server is deliberately NOT registered, so no REA tools
  appear in the session. Do not run `rea-agents setup`, `claude mcp add`, `rea update` or `rea uninstall`, and do not
  treat the missing tools as a fault to repair. Use the CLI instead: it runs the same workflows.
- **CLI:** `rea <command> ... --json` (wrapper `rea` on PATH: `/home/GitProjects/stack-config/rea` forwards to `/home/GitProjects/rea-tools/rea`; the host has no Node,
  so never use `npx rea-agents`). It builds and runs a local image from the Dockerfile in `/home/GitProjects/rea-tools`
  (the `ntjapps/rea-tools` checkout): `local/rea:<version>` (base) or `local/rea:<version>-native` (JDK 27, Ghidra
  12.2, jadx-headless-mcp), chosen automatically for `--provider ghidra` and Android/APK/JADX commands or with
  `REA_NATIVE=1`. MCP tool names map to kebab-case commands (`analyze_javascript_application` ->
  `rea analyze-javascript-application`); `rea --help` and `rea <command> --help` list commands and flags. Pass absolute
  paths under `/home/GitProjects` or `/tmp` (mounted at the same path; the current directory is mounted too).
- **Memory:** the container is capped (`REA_MEMORY`, default 1500m base / 2g native; `REA_CPUS`, default 2). Check
  `grep MemAvailable /proc/meminfo` (>= 1 GB, >= 2.2 GB for Ghidra) first and run one REA job at a time; treat a
  Ghidra or JADX run like a test run (one heavy job host-wide).
- **Large native binaries (several MB):** Ghidra auto-analysis can be OOM-killed at the 2g cap (`Ghidra exited before
  bridge startup`, `SIGKILL`). Rerun with `REA_GHIDRA_DISABLED_ANALYZERS="Decompiler Switch Analysis"` (the wrapper passes
  `REA_*` settings into the container) rather than raising `REA_MEMORY`; only go above 2g with the user's approval and
  >= 1.5 GB host headroom left over.
- **Engines:** Ghidra (native binaries, `--provider ghidra`) and JADX (Android APKs) are in the native image. Hopper,
  IDA, Binwalk, WABT and tshark are not installed; ask the user before adding any.
- **Never without the user's explicit instruction in the current message:** browser, Electron, native-UI or process
  capture (`capture-browser-scenario` and the like run Playwright or the target itself), adb device actions, and any
  network capture.
- **Update:** change the pinned versions in `/home/GitProjects/rea-tools/Dockerfile`, then run any `rea` command with
  `REA_REBUILD=1` (and `REA_NATIVE=1` for the native image). Refresh this skill from the fork (`ntjapps/rea`,
  `.agents/skills/reverse-engineer-anything`; source commit in `.source-commit`), keeping this section.
