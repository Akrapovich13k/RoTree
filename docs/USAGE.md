# Using RoTree

## Daily workflow

You can drive RoTree from a terminal (like Rojo) **or** from VS Code. Pick one.

### From a terminal

```bash
cd ~/MyRobloxGame
rotree serve
```

Leave that running. In Roblox Studio: **RoTree → Export Game Tree**. `.rotree/` populates next to your code. Read `.rotree/AI_CONTEXT.md` with your AI.

### From VS Code

1. **Open your Roblox project folder in VS Code.**
2. Run **RoTree: Start Bridge** (Command Palette). Status bar lights up green.
3. In Roblox Studio, open the place you're working on.
4. Click the **RoTree** toolbar button to open the window.
5. Hit **Export Game Tree**.
6. In VS Code, open the **RoTree** sidebar (the leaf icon).
7. Browse Game Tree, Scripts, Remotes, GUI.
8. Open `.rotree/AI_CONTEXT.md` — that's the file your AI reads.
9. Ask your AI to analyze, propose changes, or generate patches.

## Export modes (from the plugin window)

| Button                  | What it sends                                                              |
|-------------------------|----------------------------------------------------------------------------|
| **Export Game Tree**    | Full export: tree + scripts + GUI + remotes + parts + tags + attributes    |
| **Export Selected**     | Same shape, but rooted at your Studio selection                            |
| **Export Scripts**      | Only scripts + their sources                                               |
| **Export Remotes**      | Only RemoteEvents/Functions/Bindables + a "uses" map                       |
| **Export GUI**          | Only StarterGui and ScreenGuis                                             |
| **Generate Context**    | Re-runs the Markdown generator (no full re-scan)                           |
| **Open Export Folder**  | Reveals `.rotree/` in your file manager (via VS Code)                      |
| **Apply Patch**         | Lists pending patches in `.rotree/patches/` and lets you apply one         |

There is also a **Safe Mode** checkbox at the top: when on, scripts marked sensitive in `.rotreeignore` are exported with `Source: null` (paths still shown, code redacted).

## Files RoTree writes

```
.rotree/
├── game-tree.json           full instance tree (no source)
├── scripts-map.json         every script with Source, lines, deps
├── remotes-map.json         every remote with parent service
├── gui-map.json             every ScreenGui with full layout
├── services-map.json        per-service summary
├── collection-tags.json     { tag: [paths] }
├── attributes-map.json      { path: { key: value } }
├── summary.md               human-readable export summary
├── AI_CONTEXT.md            the file you point your AI at
├── last-export-info.json    timestamp, place name, plugin version
├── patches/                 incoming patches from your AI / you
│   └── 2026-05-24-fix-shop.json
└── backups/
    └── 2026-05-24-pre-patch-fix-shop.json
```

## CLI commands

| Command             | What it does                                                    |
|---------------------|-----------------------------------------------------------------|
| `rotree serve`      | Start the bridge (like `rojo serve`). Ctrl+C to stop.           |
| `rotree mcp`        | Run as an MCP server over stdio (for Claude Code, Claude Desktop). |
| `rotree mcp-config` | Print a config snippet to copy into your MCP client config.     |
| `rotree build`      | Build `RoTree.rbxm` from `plugin/` via Rojo.                    |
| `rotree context`    | Regenerate `.rotree/AI_CONTEXT.md` from the last export.    |
| `rotree compare`    | Print a Rojo ↔ Studio diff in the terminal.                     |
| `rotree init`       | Scaffold a `.rotreeignore` in the current directory.            |
| `rotree version`    | Print version.                                                  |
| `rotree help`       | Show usage.                                                     |

All commands accept `--cwd <dir>`, `--output <dir>`, and (for `serve`) `--port <n>`.

## MCP tools (what the AI can call)

When you wire `rotree mcp` into Claude Code or Claude Desktop, the AI gets these tools — it pulls only what it needs, no token-burning reads of the whole tree:

| Tool                  | Returns                                                           |
|-----------------------|-------------------------------------------------------------------|
| `rotree_status`       | Place name, last-export timestamp, stats. Call first.             |
| `rotree_get_tree`     | A subtree by `path` + `maxDepth`. No source.                      |
| `rotree_list_scripts` | Lightweight script list (name, path, lines). Filter optional.     |
| `rotree_get_script`   | One script's full source by path.                                 |
| `rotree_list_remotes` | All RemoteEvents / RemoteFunctions / Bindables.                   |
| `rotree_list_gui`     | Top-level ScreenGuis / SurfaceGuis.                               |
| `rotree_search`       | Substring search across name/path/class. Kind filter optional.    |
| `rotree_get_context`  | The AI_CONTEXT.md content.                                    |
| `rotree_get_summary`  | The summary.md content.                                           |
| `rotree_get_attributes` | Attributes map (optionally filtered by path prefix).            |
| `rotree_get_tags`     | CollectionService tag map.                                        |
| `rotree_get_instance` | **Full property bag** for one instance (Position, Color, Material, Text, Source, attributes, tags…). |
| `rotree_get_properties` | Bulk properties by path prefix.                                 |
| `rotree_rojo_compare` | Diff vs `default.project.json`.                                   |
| `rotree_write_patch`  | Save a patch into `.rotree/patches/`. **Does not apply it.**      |
| `rotree_apply_patch`  | **Apply to live game** — only if user toggled "Allow AI auto-apply" in plugin. Critical patches always refused (use `rotree_write_patch`). |

## Patch ops the AI can use

When the AI calls `rotree_write_patch` or `rotree_apply_patch`, each operation in the `ops` array is one of:

| Op               | Required fields                          | Optional      | What it does                                       |
|------------------|------------------------------------------|---------------|----------------------------------------------------|
| `setSource`      | `path`, `source`                         |               | Replace a script's Source                          |
| `setProperties`  | `path`, `props`                          |               | Set arbitrary properties on an existing instance   |
| `createInstance` | `parentPath`, `className`                | `name`, `props`, `source` | Create **any** Instance class (Part, Model, Frame, Light, RemoteEvent, Tool, …) |
| `createScript`   | `parentPath`, `name`, `className`        | `source`      | Shortcut for `Script` / `LocalScript` / `ModuleScript` |
| `createFolder`   | `parentPath`, `name`                     |               | Create a Folder                                    |
| `rename`         | `path`, `name`                           |               | Rename an instance                                 |
| `delete`         | `path`                                   |               | Destroy an instance                                |

### Property value shapes

The AI passes properties in the same JSON shapes that `rotree_get_instance` returns. The plugin reconstructs Roblox types:

| Roblox type      | JSON shape                                                              |
|------------------|-------------------------------------------------------------------------|
| `Vector3`        | `{x, y, z}` or `[x, y, z]`                                              |
| `Vector2`        | `{x, y}` or `[x, y]`                                                    |
| `Color3`         | `{r, g, b}` or `[r, g, b]` (auto-detected if all in [0,1])              |
| `UDim`           | `{scale, offset}`                                                       |
| `UDim2`          | `{x: {scale, offset}, y: {scale, offset}}` or `[sx, ox, sy, oy]`        |
| `CFrame`         | `{components: [12 numbers]}`                                            |
| `BrickColor`     | `{name}` or `{name, number}`                                            |
| `NumberRange`    | `{min, max}` (numbers)                                                  |
| `Rect`           | `{min: {x, y}, max: {x, y}}`                                            |
| `Ray`            | `{origin: {x,y,z}, direction: {x,y,z}}`                                 |
| `NumberSequence` | `{keypoints: [{time, value, envelope?}]}`                               |
| `ColorSequence`  | `{keypoints: [{time, value: {r,g,b}}]}`                                 |
| `EnumItem`       | Plain string (e.g. `"Neon"`) or `{__enum, value}`                       |

### Limits

- Up to **20 `delete` ops** per patch. Beyond that = critical = manual confirmation.
- Critical paths (DataStore, leaderstats, MarketplaceService, anti-cheat) are always refused by auto-apply.

## AI auto-apply

By default, the AI can only **propose** changes (`rotree_write_patch` → user reviews + clicks Apply in Studio). To let the AI **modify the game directly**, you must:

1. Have `rotree mcp` running (it embeds the HTTP bridge — no need for a separate `rotree serve`).
2. In the Studio plugin window → Patch Safety card → toggle **"Allow AI auto-apply (non-critical only)"** on.

Once both are on:
- The plugin polls the bridge every 2 s for queued patches.
- The AI calls `rotree_apply_patch(...)` → patch is queued → plugin picks it up → backup snapshot → applies → reports result back to the AI within ~12 s.
- Critical patches (DataStore, leaderstats, MarketplaceService, anti-cheat, bulk deletes) are **always refused** by auto-apply and routed to the manual queue instead.
- Every applied patch goes through Studio's ChangeHistoryService → you can **Ctrl+Z** to undo.

Plus MCP resources (`rotree://context`, `rotree://tree`, `rotree://scripts`, ...) for clients that prefer file-style access.

## Watch mode (auto-export)

In the Studio plugin window, toggle **Watch mode** on. From then on:

- The plugin listens to `DescendantAdded` / `DescendantRemoving` on every root service.
- When you change something, an export is **scheduled** to run after a short debounce (3 s by default).
- If you do 10 edits in 2 seconds, only **one** export runs — at the end of the burst.
- Quiet game = zero CPU, zero exports. Not a timer.
- Minimum interval between auto-exports: 5 s.

Combine Watch mode + `rotree mcp` and your AI always sees the current state, automatically, without you clicking anything.

## VS Code commands

| Command                                  | What it does                                              |
|------------------------------------------|-----------------------------------------------------------|
| `RoTree: Start Bridge`                   | Starts the HTTP server                                    |
| `RoTree: Stop Bridge`                    | Stops the HTTP server                                     |
| `RoTree: Open Game Tree`                 | Opens `game-tree.json`                                    |
| `RoTree: Refresh`                        | Re-reads `.rotree/` and refreshes the sidebar             |
| `RoTree: Show Script Map`                | Opens `scripts-map.json`                                  |
| `RoTree: Show Remotes Map`               | Opens `remotes-map.json`                                  |
| `RoTree: Show GUI Map`                   | Opens `gui-map.json`                                      |
| `RoTree: Create AI Context`          | Rewrites `AI_CONTEXT.md`                              |
| `RoTree: Compare With Rojo Project`      | Opens a diff against your `default.project.json` sources  |
| `RoTree: Open Summary`                   | Opens `summary.md`                                        |
| `RoTree: Open Export Folder`             | Reveals `.rotree/` in OS file manager                     |
| `RoTree: Preview Patch`                  | Opens a patch file with a diff view                       |

## `.rotreeignore`

A plain-text file at your workspace root. Same syntax as `.gitignore`. Examples:

```
# don't ship script sources for these
ServerScriptService/Anticheat/**
ReplicatedStorage/Secrets/**

# huge maps you don't want in the export
Workspace/Map_Old/**

# specific instance by full path
Workspace.Hidden.SuperSecretCommand
```

The plugin asks VS Code for this list on each export (via `GET /rotree/ignore`).

## Using the export with your AI

Open `.rotree/AI_CONTEXT.md` in your AI agent (Claude Code, Codex, Cursor, etc.), or just say:

> "Read `.rotree/AI_CONTEXT.md` and `.rotree/game-tree.json`. I want to add a new shop tab. Propose a plan, don't write any code yet."

your AI can read every file under `.rotree/` because it's just JSON and Markdown.

When the AI proposes a patch, ask:

> "Write the patch into `.rotree/patches/add-shop-tab.json` using the RoTree patch schema."

Then in Roblox Studio: **RoTree → Apply Patch → select the file → review → confirm**.
