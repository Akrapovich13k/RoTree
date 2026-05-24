# RoTree

**Roblox Game Tree Bridge** — a local, secure bridge between Roblox Studio and VS Code so Claude can understand your entire game without ever modifying it without your confirmation.

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
- Generates a `CLAUDE_CONTEXT.md` so Claude understands your architecture
- Compares Studio state with your Rojo project (if any)
- Lets Claude propose patches that **you** review and apply manually

## What it never does

- ❌ Send your game over the internet
- ❌ Store API keys in the plugin
- ❌ Modify your game without an explicit click + confirmation
- ❌ Touch DataStores, leaderstats, purchases without a special warning

## Quick start

You can run the bridge two ways — pick whichever you prefer.

**From a terminal, like Rojo:**
```bash
cd ~/MyRobloxGame
rotree serve         # listens on http://localhost:34872
```

**From VS Code:**
```
Command Palette → RoTree: Start Bridge
```

Either way, in Roblox Studio you then click **RoTree → Export Game Tree**, and the export appears in `.rotree/` next to your code.

Full install steps in [`docs/INSTALLATION.md`](docs/INSTALLATION.md).

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how the bridge is built
- [`docs/INSTALLATION.md`](docs/INSTALLATION.md) — step-by-step install
- [`docs/USAGE.md`](docs/USAGE.md) — daily workflow with Claude
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
