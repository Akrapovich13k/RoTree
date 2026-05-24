# RoTree plugin (Roblox Studio)

Luau source for the RoTree Studio plugin. Talks to the VS Code extension over `http://localhost:34872`.

## Build with Rojo

```bash
rojo build default.project.json -o RoTree.rbxm
```

Drop `RoTree.rbxm` into your Studio Plugins folder, restart Studio.

## Layout

```
src/
├── init.server.luau       Plugin entry — toolbar, button, widget, wiring
├── Config.luau            Constants: port, version, critical patterns
├── UI/
│   ├── Theme.luau         Colors, fonts, spacing (Apple-inspired)
│   ├── Components.luau    Card, Button, StatLine builders
│   ├── MainWindow.luau    Full widget layout
│   └── PatchPreview.luau  Modal-like patch review
├── Services/
│   ├── ExportService.luau     Orchestrator
│   ├── ScriptScanner.luau     Walks scripts + sources
│   ├── GuiScanner.luau        Walks GUIs
│   ├── RemoteScanner.luau     Walks remotes
│   ├── PartScanner.luau       Summarizes parts/meshes
│   ├── AttributeScanner.luau  Reads attributes
│   ├── TagScanner.luau        Reads CollectionService tags
│   ├── HttpBridge.luau        SOLE network point
│   ├── PatchService.luau      SOLE mutation point
│   ├── BackupService.luau     Snapshots before patches
│   └── ContextGenerator.luau  Builds CLAUDE_CONTEXT.md
└── Utils/
    ├── PathUtils.luau
    └── Ignore.luau
```

## Auditable boundaries

- **Only** `Services/HttpBridge.luau` calls `HttpService:RequestAsync`.
- **Only** `Services/PatchService.luau` writes to `Instance` properties or calls `:Destroy`.

If you fork or audit, look there first.
