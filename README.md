# RoTree

**Roblox Game Tree Bridge** — a local, secure bridge between Roblox Studio and VS Code so your AI can understand your entire game without ever modifying it without your confirmation.

```
┌─────────────────────────┐        HTTP POST          ┌──────────────────────────┐
│  Roblox Studio          │   localhost:34872         │   rotree serve   (CLI)   │
│  RoTree Plugin (Luau)   │ ────────────────────────► │         OR               │
│  scans game tree        │                           │   RoTree (VS Code ext.)  │
└─────────────────────────┘                           │   → writes .rotree/      │
                                                      └──────────────────────────┘
                                                          both use @rotree/core
```

## What it does

- Scans your full Roblox game tree (Workspace, ReplicatedStorage, ServerScriptService, GUI, Remotes, Tools, etc.)
- Exports everything to a local `.rotree/` folder as readable JSON + Markdown
- Generates a `AI_CONTEXT.md` so your AI understands your architecture
- **MCP server** (`rotree mcp`): exposes the tree as tools so Claude Code / Claude Desktop / any MCP client / any MCP client can pull only what it needs (no token waste)
- **Watch mode** in the Studio plugin: re-exports automatically when the DataModel changes (event-driven + debounced, never on a timer)
- Compares Studio state with your Rojo project (if any)
- Lets your AI propose patches that **you** review and apply manually

## What it never does

- ❌ Send your game over the internet
- ❌ Store API keys in the plugin
- ❌ Modify your game without an explicit click + confirmation
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

That's it. Requires Node.js 18+. Drops a single `rotree` binary into `~/.local/bin` (or `%LOCALAPPDATA%\rotree\bin` on Windows).

Then in Roblox Studio you still need to install the plugin once — see [`docs/INSTALLATION.md`](docs/INSTALLATION.md).

## Quick start

**From a terminal, like Rojo:**
```bash
cd ~/MyRobloxGame
rotree serve         # listens on http://localhost:34872
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
