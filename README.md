# RoTree

**Roblox Game Tree Bridge** — a local, secure bridge between Roblox Studio and VS Code so Claude can understand your entire game without ever modifying it without your confirmation.

```
┌─────────────────────────┐        HTTP POST          ┌──────────────────────────┐
│  Roblox Studio          │   localhost:34872         │  VS Code                 │
│  RoTree Plugin (Luau)   │ ────────────────────────► │  RoTree Extension (TS)   │
│  scans game tree        │                           │  writes .rotree/         │
└─────────────────────────┘                           └──────────────────────────┘
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

1. Install the plugin in Roblox Studio — see [`docs/INSTALLATION.md`](docs/INSTALLATION.md)
2. Install the VS Code extension
3. Open your game folder in VS Code → run `RoTree: Start Bridge`
4. In Studio, click **RoTree → Export Game Tree**
5. Open `.rotree/CLAUDE_CONTEXT.md` and let Claude read your game

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how the bridge is built
- [`docs/INSTALLATION.md`](docs/INSTALLATION.md) — step-by-step install
- [`docs/USAGE.md`](docs/USAGE.md) — daily workflow with Claude
- [`docs/SECURITY.md`](docs/SECURITY.md) — what's protected and why

## Project layout

```
plugin/         Roblox Studio plugin (Luau, buildable with Rojo)
extension/      VS Code extension (TypeScript)
docs/           Architecture & guides
.rotreeignore   Per-project ignore list (created on first export)
.rotree/        Export folder (auto-generated, gitignore'd by default)
```

## License

MIT — see [LICENSE](LICENSE).
