# RoTree — VS Code extension

The VS Code half of [RoTree](../README.md). Runs a local HTTP server that
receives exports from the Roblox Studio plugin, writes them to `.rotree/`,
and shows them in a sidebar.

## Develop

```bash
npm install
npm run watch    # in one terminal
# In VS Code: press F5 to launch the Extension Development Host
```

## Build a .vsix

```bash
npm run build
npm run package
code --install-extension rotree-0.1.0.vsix
```

## Layout

```
src/
├── extension.ts                 activation, command wiring
├── types.ts                     shared payload + patch interfaces
├── server/HttpServer.ts         loopback HTTP listener
├── services/
│   ├── ExportReader.ts          read .rotree/* on demand
│   ├── ContextBuilder.ts        regenerate AI_CONTEXT.md
│   ├── RojoComparator.ts        compare with default.project.json
│   └── PatchManager.ts          list / read patches
├── providers/                   sidebar TreeDataProviders
└── commands/index.ts            all RoTree: ... commands
```

## Configuration

| Setting                  | Default   | What it does                                |
|--------------------------|-----------|---------------------------------------------|
| `rotree.port`            | `34873`   | Localhost port for the bridge               |
| `rotree.autoStartBridge` | `true`    | Start the server when a workspace opens     |
| `rotree.exportFolder`    | `.rotree` | Where to write exports inside the workspace |
