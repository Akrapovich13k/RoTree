# Changelog

All notable changes to RoTree are listed here. The repo follows
[Semantic Versioning](https://semver.org).

## Unreleased

### Fixed
- **`rotree_rojo_compare` can now actually find your project.** Two gaps closed:
  - `rotree mcp-config` / `rotree mcp-install` accept `--rojo-project <path>` and
    bake it into the generated MCP server invocation, so the explicit project path
    (or `ROTREE_ROJO_PROJECT`) is honoured when the AI client launches the server —
    previously there was no way to pass it in that context.
  - Auto-discovery now scans sub-directories **recursively** (breadth-first, up to
    3 levels deep, shallowest wins) instead of only the immediate children, so a
    `default.project.json` nested a few folders down (e.g. `packages/game/`) is
    found without configuration. The resolved path shows up in `rotree_status`.
- **`rotree_get_instance` no longer dumps an entire subtree.** On a large
  Model/Folder it serialized every descendant (hundreds of KB) and blew the MCP
  token budget. The structural `node` is now bounded by `maxDepth` (default 1) and
  `maxChildren` (default 50); omitted nodes are reported via `_truncated` /
  `_childrenOmitted` / `_childCount`. The target's own properties/attributes/tags
  are unchanged.

### Changed
- `rotree_get_tree` and `rotree_get_instance` share one tree-bounding helper
  (`boundTreeNode`); `rotree_get_tree` output is unchanged.

## v0.2.0 — 2026-06-08

### Added
- **Configurable Rojo project location** — `rotree compare` / `rotree mcp`
  accept `--rojo-project <path>` (a `*.project.json` file or its folder; also
  the `ROTREE_ROJO_PROJECT` env var). When omitted, the project is now
  discovered robustly: workspace root → parent directories → immediate
  sub-folders → any `*.project.json`. The chosen file is logged, and
  `rotree_rojo_compare` returns the resolved `projectFile`.
- **`rotree_get_tags` filtering & pagination** — defaults to a compact
  `{ tag: count }` summary instead of dumping the whole tag→paths map
  (which could exceed the MCP token budget). Pass `tag` (exact or prefix)
  for the paths, with `limit`/`offset`.
- **`rotree_get_attributes` instance filter** — new `instancePath` returns the
  attributes of one instance (or a sub-tree) the same way `rotree_get_instance`
  takes a path, and `keyPrefix` filters by attribute key name. The old `path`
  parameter is kept as a deprecated alias.
- **`rotree_list_gui` aggregation** — `summary: true` returns
  `{ className: count }` plus the total; `pathPrefix` scopes to one branch.
- **Export freshness** — `rotree_status` now reports how long ago the export
  was made and flags it as `stale` past a threshold (`--stale-days`, default 3);
  `rotree_get_summary` prepends a read-time freshness banner.

### Fixed
- **GUI properties now captured** — the property scan starved GUI: a 5000-cap
  per-root DFS exhausted its budget inside `Workspace` and returned before
  reaching `StarterGui`. It now does a fair breadth-first walk across all roots
  and always captures GUI / UI / script / remote / value instances, so
  `rotree_get_instance` returns Text, Size, colours, UIStroke/UIGradient, etc.
- **Version drift** — `AI_CONTEXT.md` was hard-coded to "RoTree v0.1.0" while the
  rest of the export reported 0.1.2. The context generator now uses
  `Config.PLUGIN_VERSION`, the single source of truth.
- **Richer attribute capture** — Model/Folder attributes of type
  CFrame / BrickColor / UDim / NumberRange / Rect / Font are now serialized
  into structured JSON instead of a lossy `tostring()`.

### Changed
- MCP tool `description`s rewritten to describe their parameters accurately —
  in particular the previously ambiguous `path` on `rotree_get_attributes`.

## v0.1.2 — 2026-05-25

### Fixed
- **Port collision with Rojo** — `rotree`'s default port moved from
  `34872` (which Rojo also uses) to **`34873`**, so the two tools can
  run side-by-side without stealing each other's POSTs.

### Breaking
- Old plugins built from v0.1.0/v0.1.1 still try to reach port 34872.
  After upgrading the CLI, **rebuild and reinstall `RoTree.rbxm`** from
  the v0.1.2 release (the rebuilt plugin defaults to 34873). Or, as a
  one-time workaround, keep the old plugin and run
  `rotree mcp --port 34872`.

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
