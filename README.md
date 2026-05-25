# RoTree

**Roblox Game Tree Bridge** — a local, secure bridge between Roblox Studio and VS Code so your AI can understand your entire game without ever modifying it without your confirmation.

```
┌─────────────────────────┐        HTTP POST          ┌──────────────────────────┐
│  Roblox Studio          │   localhost:34873         │   rotree serve   (CLI)   │
│  RoTree Plugin (Luau)   │ ────────────────────────► │         OR               │
│  scans game tree        │                           │   RoTree (VS Code ext.)  │
└─────────────────────────┘                           │   → writes .rotree/      │
                                                      └──────────────────────────┘
                                                          both use @rotree/core
```

## What it does

- **Full game tree export** — Workspace, ReplicatedStorage, ServerScriptService, GUI, Remotes, Tools, Tags, Attributes, every Instance class.
- **All properties captured** — ~50 ClassNames covered with inheritance (BaseParts, GUI, Lights, Sounds, Constraints, Particles, Humanoid, Camera, Workspace settings, UI helpers, Value objects…).
- **`AI_CONTEXT.md`** — auto-generated Markdown summary your AI reads first to understand your architecture.
- **MCP server** (`rotree mcp`) — 17 tools so Claude Code / Claude Desktop / Codex / any MCP client pulls **only what it needs** (no token waste).
- **Watch mode** — re-exports automatically when the DataModel changes (event-driven + debounced, never on a timer).
- **Studio Output stream** — the plugin captures `LogService.MessageOut` (Print, Info, Warning, Error) and the AI can read it on demand via `rotree_get_output`.
- **AI can modify the game** (opt-in) — create / modify / delete any Instance via `rotree_apply_patch`. Critical paths (DataStore, leaderstats, MarketplaceService, anti-cheat) are always refused.
- **Backup before every patch** + Ctrl+Z support via `ChangeHistoryService`.
- **Rojo-aware** — diffs Studio state against your `default.project.json`.
- **`.rotreeignore`** — hide sensitive scripts/folders from the AI; `critical:` prefix elevates to double-confirm.

Full list and history: [`CHANGELOG.md`](CHANGELOG.md).

## What it never does

- ❌ Send your game over the internet
- ❌ Store API keys in the plugin
- ❌ Modify your game without your toggle being on (and never for critical systems)
- ❌ Touch DataStores, leaderstats, purchases without a special warning

## Install

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/Akrapovich13k/RoTree/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/Akrapovich13k/RoTree/main/install.ps1 | iex
```

That's it. Drops `rotree` into `~/.local/bin` (or `%LOCALAPPDATA%\rotree\bin` on Windows).

- **Node.js installed?** → small 290 KB JS bundle, fastest install.
- **No Node.js?** → standalone binary (~50 MB, no runtime needed).

The installer picks automatically. Force one with
`ROTREE_MODE=binary curl … | bash` or `ROTREE_MODE=bundle …`.

Then in Roblox Studio you still need to install the plugin once — see [`docs/INSTALLATION.md`](docs/INSTALLATION.md).

## Quick start

**From a terminal, like Rojo:**
```bash
cd ~/MyRobloxGame
rotree serve         # listens on http://localhost:34873
```

In Roblox Studio: turn on **Watch mode** in the RoTree window. Now every change in your DataModel auto-exports — no clicking.

**Hooking Claude Code / Claude Desktop / any MCP client (MCP):**
```bash
rotree mcp-config --cwd ~/MyRobloxGame
```

Copy the printed JSON into your MCP config. your AI now has tools like `rotree_get_script("ServerScriptService.Shop")` and `rotree_search("leaderstats")`. It pulls only what it needs.

**From VS Code:**
```
Command Palette → RoTree: Start Bridge
```

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how the bridge is built
- [`docs/INSTALLATION.md`](docs/INSTALLATION.md) — step-by-step install
- [`docs/USAGE.md`](docs/USAGE.md) — daily workflow with your AI
- [`docs/SECURITY.md`](docs/SECURITY.md) — what's protected and why

## Project layout

```
plugin/         Roblox Studio plugin (Luau, buildable with Rojo)
core/           Shared TypeScript core (HTTP, file IO, Rojo, context)
cli/            `rotree` CLI (rotree serve / build / context / compare / init)
extension/      VS Code extension (uses core, adds sidebar + commands)
docs/           Architecture & guides
.rotreeignore   Per-project ignore list (created on first export)
.rotree/        Export folder (auto-generated, gitignore'd by default)
```

The CLI and the VS Code extension share the **same** `@rotree/core` package — identical filesystem layout, identical security boundaries.

## License

MIT — see [LICENSE](LICENSE).
