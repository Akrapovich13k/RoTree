# rotree CLI

Local CLI to drive RoTree from a terminal — same role as `rojo serve` for Rojo.

## Install

```bash
# from the repo
cd cli
npm install --workspaces
npm run build
npm install -g .
```

Now `rotree` is on your PATH.

## Commands

```
rotree serve              Start the local bridge for the Studio plugin
rotree build              Build plugin/RoTree.rbxm via Rojo
rotree context            Regenerate .rotree/CLAUDE_CONTEXT.md
rotree compare            Diff Studio export ↔ default.project.json
rotree init               Scaffold a .rotreeignore
rotree version            Print the version
rotree help               Show usage
```

## Options

| Flag             | Default   | Purpose                                  |
|------------------|-----------|------------------------------------------|
| `--port <n>`     | `34872`   | Port for the bridge (serve)              |
| `--cwd <dir>`    | `$PWD`    | Workspace root                           |
| `--output <dir>` | `.rotree` | Export subfolder                         |
| `--plugin <dir>` | `./plugin`| Plugin source dir (build)                |
| `--out <file>`   | `RoTree.rbxm` | Build output filename                |

## Example session

```bash
$ cd ~/MyRobloxGame
$ rotree serve
RoTree v0.1.0
12:34:56 info workspace: /home/me/MyRobloxGame
12:34:56 info writing to .rotree
12:34:56 info bridge listening on http://localhost:34872

✓ bridge ready · http://localhost:34872
Open Roblox Studio, click RoTree → Export Game Tree.
Press Ctrl+C to stop.

12:35:10 info full export · MyGame · 142 instances · 6 scripts
```

The CLI uses the same `@rotree/core` modules as the VS Code extension —
identical behavior, identical filesystem layout, identical security
guarantees (loopback-only, version handshake, no internet).
