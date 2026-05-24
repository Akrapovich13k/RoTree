# Using RoTree

## Daily workflow

1. **Open your Roblox project folder in VS Code.**
2. Run **RoTree: Start Bridge** (Command Palette). Status bar lights up green.
3. In Roblox Studio, open the place you're working on.
4. Click the **RoTree** toolbar button to open the window.
5. Hit **Export Game Tree**.
6. In VS Code, open the **RoTree** sidebar (the leaf icon).
7. Browse Game Tree, Scripts, Remotes, GUI.
8. Open `.rotree/CLAUDE_CONTEXT.md` — that's the file Claude reads.
9. Ask Claude to analyze, propose changes, or generate patches.

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
├── CLAUDE_CONTEXT.md        the file you point Claude at
├── last-export-info.json    timestamp, place name, plugin version
├── patches/                 incoming patches from Claude/you
│   └── 2026-05-24-fix-shop.json
└── backups/
    └── 2026-05-24-pre-patch-fix-shop.json
```

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
| `RoTree: Create Claude Context`          | Rewrites `CLAUDE_CONTEXT.md`                              |
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

## Using the export with Claude

Open `.rotree/CLAUDE_CONTEXT.md` in your Claude Code session, or just say:

> "Read `.rotree/CLAUDE_CONTEXT.md` and `.rotree/game-tree.json`. I want to add a new shop tab. Propose a plan, don't write any code yet."

Claude can read every file under `.rotree/` because it's just JSON and Markdown.

When Claude proposes a patch, ask:

> "Write the patch into `.rotree/patches/add-shop-tab.json` using the RoTree patch schema."

Then in Roblox Studio: **RoTree → Apply Patch → select the file → review → confirm**.
