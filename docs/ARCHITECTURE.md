# RoTree Architecture

## Overview

RoTree is two programs talking over a localhost HTTP connection.

```
┌──────────────────────────────────────────────┐
│  ROBLOX STUDIO (Luau, plugin)                │
│                                              │
│  ┌────────────┐   ┌─────────────────────┐   │
│  │ Toolbar +  │──►│ MainWindow (widget) │   │
│  │ button     │   │ Apple-like UI       │   │
│  └────────────┘   └──────────┬──────────┘   │
│                              │              │
│         ┌────────────────────┴───────┐      │
│         ▼                            ▼      │
│  ┌─────────────┐            ┌──────────────┐│
│  │ Scanners    │            │ PatchService ││
│  │ - scripts   │            │ - preview    ││
│  │ - GUI       │            │ - backup     ││
│  │ - remotes   │            │ - apply      ││
│  │ - parts     │            └──────────────┘│
│  │ - tags      │                            │
│  │ - attrs     │                            │
│  └──────┬──────┘                            │
│         ▼                                   │
│  ┌──────────────┐                           │
│  │ HttpBridge   │ ── POST localhost:34873 ──┼──┐
│  └──────────────┘                           │  │
└──────────────────────────────────────────────┘  │
                                                  │
┌──────────────────────────────────────────────┐  │
│  VS CODE (TypeScript, extension)             │  │
│                                              │  │
│  ┌──────────────┐ ◄────────────────────────┐ │  │
│  │ HttpServer   │  receives export ◄───────┼─┼──┘
│  └──────┬───────┘                          │ │
│         ▼                                  │ │
│  ┌──────────────┐                          │ │
│  │ ExportReader │ ── writes .rotree/       │ │
│  └──────┬───────┘                          │ │
│         ▼                                  │ │
│  ┌──────────────────────────────────────┐  │ │
│  │ Sidebar (TreeDataProviders)          │  │ │
│  │ Game Tree · Scripts · Remotes · GUI  │  │ │
│  │ Services · Rojo · AI Context     │  │ │
│  └──────────────────────────────────────┘  │ │
│         ▼                                  │ │
│  ┌──────────────┐                          │ │
│  │ ContextBuilder │── writes AI_CONTEXT.md
│  └──────────────┘                          │ │
└──────────────────────────────────────────────┘
```

## Why HTTP localhost

Roblox Studio plugins cannot write to arbitrary files on disk. They can:
- Call `HttpService:RequestAsync` to a local URL
- Open script documents in Studio

We pick HTTP localhost — same approach as [Rojo](https://rojo.space) — because it lets the **VS Code extension** own the filesystem write. The plugin only ever sends data; the extension decides what hits disk.

## Communication contract

The plugin sends a single POST per export:

```
POST http://localhost:34873/rotree/export
Content-Type: application/json
X-RoTree-Version: 0.1.0

{
  "kind": "full" | "selected" | "safe" | "scripts" | "remotes" | "gui",
  "placeName": "...",
  "placeId": 0,
  "exportedAt": "2026-05-24T12:00:00Z",
  "tree": [ ...root services... ],
  "scripts": [ ... ],
  "remotes": [ ... ],
  "gui": [ ... ],
  "tags": { tag: [paths] },
  "attributes": { path: { key: value } },
  "stats": { instances, scripts, remotes, gui, parts, modules }
}
```

The server splits this payload into the files documented in [`docs/USAGE.md`](USAGE.md).

For patches, the reverse flow is:
1. VS Code (or your AI via VS Code) writes `.rotree/patches/<id>.json`
2. The plugin's "Apply Patch" button does `GET http://localhost:34873/rotree/patches/<id>`
3. Studio shows a preview, asks confirmation, creates a backup, applies.

## File layout

| Path                                | Owner       | Purpose                                          |
|-------------------------------------|-------------|--------------------------------------------------|
| `plugin/src/init.server.luau`       | Plugin      | Plugin entry: toolbar, widget, wiring            |
| `plugin/src/UI/`                    | Plugin      | All UI code, isolated from logic                 |
| `plugin/src/Services/`              | Plugin      | Scanners + HTTP bridge + patch service           |
| `plugin/src/Services/HttpBridge`    | Plugin      | The single network point                         |
| `plugin/src/Services/PatchService`  | Plugin      | The single mutation point (gated)                |
| `core/src/HttpServer.ts`            | Core (TS)   | Receives export, validates, writes               |
| `core/src/ExportReader.ts`          | Core (TS)   | Splits payload to `.rotree/*` files              |
| `core/src/ContextBuilder.ts`        | Core (TS)   | Builds `AI_CONTEXT.md`                       |
| `core/src/RojoComparator.ts`        | Core (TS)   | Diffs Studio export vs `default.project.json`    |
| `core/src/PatchManager.ts`          | Core (TS)   | Patch file IO                                    |
| `cli/src/index.ts`                  | CLI         | `rotree` binary — wraps core for terminal use    |
| `extension/src/extension.ts`        | Extension   | VS Code wrapper — wraps core for sidebar use     |
| `extension/src/providers/`          | Extension   | Tree views in the sidebar                        |
| `extension/src/commands/`           | Extension   | VS Code command handlers                         |

The CLI and the extension are **thin shells** over `@rotree/core`. Same behavior, same security guarantees, different surfaces.

## Security boundaries

1. **Network boundary** — `HttpBridge.luau` is the only file that calls `HttpService:RequestAsync`. Everything else is sandboxed.
2. **Mutation boundary** — `PatchService.luau` is the only file that writes back to the DataModel. It refuses patches without a fresh user confirmation.
3. **Critical-system list** — `PatchService` keeps a hardcoded list of "critical" services (DataStores, leaderstats, MarketplaceService, RemoteEvents marked critical) that require **double confirmation**.
4. **No remote code execution** — patches contain `Source` strings that replace `Script.Source`. They never invoke `loadstring` or run unsigned bytecode.
5. **HTTPS not required** — because traffic is loopback only.

## Plugin module map

| Module                              | Job                                                |
|-------------------------------------|----------------------------------------------------|
| `Config`                            | Constants: port, version, critical class names     |
| `UI/Theme`                          | Colors, spacing, fonts (Apple-inspired)            |
| `UI/Components`                     | Card, Button, StatLine, primitive UI builders      |
| `UI/MainWindow`                     | The full widget layout                             |
| `UI/PatchPreview`                   | Modal-like view of an incoming patch               |
| `Services/ExportService`            | Orchestrates a scan + send                         |
| `Services/ScriptScanner`            | Walks scripts, returns sources + dependencies      |
| `Services/GuiScanner`               | Walks GUIs, returns layout properties              |
| `Services/RemoteScanner`            | Walks RemoteEvents/Functions/Bindables             |
| `Services/PartScanner`              | Summarizes parts/meshes/models                     |
| `Services/AttributeScanner`         | Reads `GetAttributes` for every instance           |
| `Services/TagScanner`               | Reads `CollectionService:GetTagged`                |
| `Services/HttpBridge`               | Single network gateway                             |
| `Services/PatchService`             | Gated mutation point                               |
| `Services/BackupService`            | Snapshots before each patch                        |
| `Services/ContextGenerator`         | Produces a Markdown summary                        |
| `Utils/PathUtils`                   | `GetFullName` parsing, path joining                |
| `Utils/Ignore`                      | `.rotreeignore` matcher                            |

## Extension module map

| Module                              | Job                                                |
|-------------------------------------|----------------------------------------------------|
| `extension.ts`                      | Activation, command registration, server lifecycle |
| `types.ts`                          | Shared TS interfaces matching the JSON payload     |
| `server/HttpServer.ts`              | Listens on 34873, splits payload to files          |
| `services/ExportReader.ts`          | Loads files from `.rotree/` on demand              |
| `services/ContextBuilder.ts`        | Builds `AI_CONTEXT.md`                         |
| `services/RojoComparator.ts`        | Reads `default.project.json`, diffs vs export      |
| `services/PatchManager.ts`          | Writes patches to `.rotree/patches/`               |
| `providers/*Provider.ts`            | `vscode.TreeDataProvider` for each sidebar section |
| `commands/index.ts`                 | All `RoTree: ...` command implementations          |

## Limits of Roblox Studio

- `HttpService` must be enabled in **Game Settings → Security → Allow HTTP Requests** (or, for studio-only operations, the plugin scope works on most accounts). The plugin shows a clear error if requests are blocked.
- Plugins cannot read arbitrary disk files — that's why `.rotreeignore` lives in the extension, not the plugin (the extension just sends back the parsed ignore list on connect).
- Plugin UIs are built with `DockWidgetPluginGui` + Roblox UI instances; we can't use HTML/CSS. We approximate the Apple-inspired look with `UICorner`, `UIPadding`, `UIStroke`, and `UIGradient`.
- Script source is read via `script.Source`. Some Robux-protected ModuleScripts (rare) may refuse.

## MVP vs. later

**Shipped in v0.1 (this repo):**
- Full export (game tree, scripts, GUI, remotes, parts, attributes, tags)
- Apple-like UI, light + dark
- HTTP bridge
- VS Code sidebar with all sections
- `AI_CONTEXT.md` generation
- Rojo comparison
- Patch preview + apply with backup
- `.rotreeignore`

**Easy v0.2 additions:**
- Diff between two exports (the backup files are already JSON)
- Unused-remote detection (cross-reference `RemoteScanner` output with all script sources)
- Empty-script detection (already in `ScriptScanner`, just expose in UI)
- Selective re-export (already supported by the `kind` field, just add buttons)

**v0.3+:**
- Auto-watch: re-export on every save
- Dark mode toggle in extension webview
- Patch authoring assistant
