# Changelog

All notable changes to RoTree are listed here. The repo follows
[Semantic Versioning](https://semver.org).

## Unreleased

_(empty — open a PR and add your entry here under Added / Changed / Fixed / Removed.)_

## v0.1.1 — 2026-05-25

### Added
- **`move` patch op** — the AI can reparent any instance (e.g. drag a
  Part from `Workspace.OldFolder` to `Workspace.NewFolder`). Takes
  `path` + `parentPath`, plus an optional `name` to rename in the same
  op. Refuses circular moves (moving an instance into one of its own
  descendants). Now in both `rotree_write_patch` and
  `rotree_apply_patch` schemas.

## v0.1.0 — 2026-05-25

First public release. Ships:

- Standalone binaries for Linux x64/ARM, macOS Intel/ARM, Windows x64.
- JS bundle (290 KB) for users who already have Node 18+.
- Roblox Studio plugin `RoTree.rbxm` (drop into your Plugins folder).

### Added
- **Standalone binaries (no Node required at runtime)** — new
  `.github/workflows/release.yml` builds cross-platform binaries via
  `bun build --compile` from a single Linux runner. Targets:
  `rotree-linux-x64`, `rotree-linux-arm64`, `rotree-darwin-x64`,
  `rotree-darwin-arm64`, `rotree-windows-x64.exe`. Uploaded to the
  GitHub Release on every `v*` tag push, with `SHA256SUMS.txt`.
- **Dual-mode installers** — `install.sh` and `install.ps1` now pick
  automatically: standalone binary if Node isn't installed, JS bundle
  if Node ≥ 18 is. Force one with `ROTREE_MODE=binary|bundle|auto`.
  Pin a release with `ROTREE_VERSION=v0.1.0`. The bash installer
  cross-fades back to the JS bundle when a binary download fails.
- **`rotree mcp-install` command** — auto-patches the MCP config of
  Claude Desktop AND Claude Code (project `.mcp.json` + user
  `~/.claude.json`) in one call. No more copy-pasting JSON. Idempotent,
  merges with existing servers, makes a `.rotree-backup` first. Flags:
  `--client claude-desktop | claude-code | claude-code-user | all`,
  `--cwd <dir>`, `--name <serverName>`.
- **Friendlier `install.sh`** — when Node is missing, prints platform-
  specific install commands (brew / apt-get / dnf / pacman / fnm).
  When run from a TTY (not piped), prompts to auto-configure MCP at
  the end so the install is a single flow.
- **`CHANGELOG.md`** + a clearer **Features** section in the README,
  including the new Studio Output stream.
- **Studio Output stream** — the plugin captures `LogService.MessageOut`
  (Print, Info, Warning, Error) and batches it to the bridge every 1.5 s.
  Persisted to `.rotree/output.jsonl`. New MCP tools `rotree_get_output`
  (limit / level / filter / sinceElapsed) and `rotree_clear_output`.
- **`createInstance` patch op** — the AI can now create **any** Roblox
  Instance class (Part, Model, Frame, RemoteEvent, Light, Sound, …) with
  full property bags. JSON shapes from `PropertyScanner` round-trip
  through a new `PropertyDeserializer` (Vector3/Color3/CFrame/UDim2/
  Enum/etc.).
- **AI auto-apply (opt-in)** — toggle in the plugin's Patch Safety card.
  When on, the plugin polls every 2 s for AI-queued patches and applies
  non-critical ones automatically. Critical paths (DataStore, leaderstats,
  MarketplaceService, anti-cheat, >20 deletes) are always refused.
- **`rotree mcp` server** — stdio MCP for Claude Code / Claude Desktop /
  any MCP client. Tools: status, get_tree, list_scripts, get_script,
  list_remotes, list_gui, search, get_instance, get_properties,
  get_attributes, get_tags, get_context, get_summary, rojo_compare,
  write_patch, apply_patch.
- **Watch mode** in the plugin — event-driven `DescendantAdded/Removing`
  subscriptions, debounced 3 s, never on a timer. Quiet game = zero work.
- **Full property capture** — `PropertyDump.luau` covers ~50 ClassNames
  with inheritance (BaseParts, GUI, Sounds, Lights, Constraints,
  Particles, Humanoid, Camera, Workspace, Value objects, UI helpers…).
- **Apple-inspired plugin UI** — DockWidget with cards, light/dark mode,
  Apple-style toggles. Faithful HTML preview at `docs/preview/`.
- **`@rotree/core` shared package** — same logic runs in both the CLI
  and the VS Code extension.
- **`rotree` CLI** — `serve`, `mcp`, `mcp-config`, `build`, `context`,
  `compare`, `init`, `version`, `help`. Bundled to a single 290 KB JS
  file via esbuild.
- **One-line installers** — `install.sh` and `install.ps1` download the
  bundle directly into `~/.local/bin/rotree`.
- **VS Code extension** — sidebar with Game Tree / Scripts / Remotes /
  GUI / Services / Rojo / AI Context.
- **`.rotreeignore`** — gitignore-style file with a `critical:` prefix
  to elevate paths to double-confirm.
- **Plugin security boundaries** — `HttpBridge.luau` is the only file
  that touches the network; `PatchService.luau` is the only file that
  mutates the DataModel. Backup before every patch.

### Renamed
- `CLAUDE_CONTEXT.md` → `AI_CONTEXT.md` (works with any AI agent —
  Claude, Codex, GPT, Gemini, …). The JSON wire field `claudeContext`
  was renamed to `aiContext` in the same commit.

## How to contribute to this file

When you add a user-facing change, prepend an entry under
`Unreleased` in one of the categories: **Added**, **Changed**, **Fixed**,
**Removed**. On a release tag the section gets renamed to the version
and a fresh `Unreleased` is started.
