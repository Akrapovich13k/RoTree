# RoTree security model

RoTree's job is to give Claude visibility, not authority. This file lists every guarantee and how it's enforced.

## Guarantees

### 1. No outbound internet from the plugin

The plugin only makes HTTP requests to `http://localhost:<port>`. The default port is `34872`. The URL is built in a single file (`plugin/src/Config.luau`) and used by exactly one module (`plugin/src/Services/HttpBridge.luau`). Audit either to verify.

### 2. No API keys in the plugin

The plugin never contains any token, key, or credential. Claude integration happens **outside** the plugin — Claude reads files in `.rotree/`, which is your workspace.

### 3. No automatic mutation

The only file in the plugin that mutates the DataModel is `plugin/src/Services/PatchService.luau`. It refuses to apply a patch unless **all** of these are true:

- The plugin window is in foreground
- The user clicked **Apply Patch**
- The user confirmed the modal preview
- A backup was successfully written first

### 4. Critical-system double confirmation

A patch touching any of these paths or class names requires a **second** confirmation with the exact text "I understand":

- `DataStoreService`, `DataStore2`, `ProfileService`, `Suphi`'s DataStore
- Any instance named `leaderstats`
- `MarketplaceService`, `GamePass`, `DevProduct`
- Any RemoteEvent/RemoteFunction tagged `RoTreeCritical`
- Any script with the attribute `RoTreeCritical = true`
- Files matched by `.rotreeignore` with the `critical:` prefix

The list lives in `plugin/src/Config.luau` under `CRITICAL_PATTERNS` and is easy to extend.

### 5. Backups before every patch

`BackupService` writes a JSON snapshot of every instance the patch will touch into `.rotree/backups/<timestamp>-pre-<patchname>.json`. It's a static snapshot — no auto-restore, but you have the full source/properties to rebuild manually if needed.

### 6. No loadstring / no remote code

Patches are declarative: they set `Source` strings, `Name`, parent paths, basic properties. The plugin does not call `loadstring`, `require` arbitrary URLs, or execute received data as Luau.

### 7. No mass deletion without explicit opt-in

A patch with more than 5 `delete` ops (configurable in `Config.luau`) is rejected unless flagged `bulk: true` AND given a triple confirmation.

### 8. HTTP bridge is loopback-only

`HttpServer.ts` in the extension binds to `127.0.0.1` only — not `0.0.0.0`. No other machine on your network can connect.

### 9. CORS-locked

`HttpServer.ts` rejects requests whose `Origin` header is not empty or `http://localhost:*`. The plugin sends no `Origin`, so this is just defense-in-depth against a browser-based attacker.

### 10. Version handshake

Every request includes `X-RoTree-Version`. If the major version mismatches between plugin and extension, the request is rejected with a clear message instead of silently misbehaving.

## What's protected by default

These do not appear in the export at all unless you opt in:

- Files matched by `.rotreeignore`
- Scripts whose name matches `*_secret*` or `*_private*` (configurable)
- Attributes prefixed with `_secret_`

Their **paths** still appear in `game-tree.json` (so Claude can reason about structure) but their **source / values** are replaced with `null` and a `"_redacted": true` flag.

## What's NOT protected (be aware)

- Your scripts' source code, by default, is exported. If you don't want Claude to see anti-cheat logic, add it to `.rotreeignore`.
- The HTTP bridge accepts any local process on your machine. If another program on your machine sends a POST to `localhost:34872`, the extension will write the data. Mitigation: the extension validates payload shape and version; in practice, a malicious local process can already do worse things.

## Auditing the plugin

If you want to verify a built `RoTree.rbxm`:

1. Drag the file onto a blank place in Studio
2. The plugin source appears as a Folder under `Plugins`
3. Open `Services/HttpBridge.luau` — that's the only file with network access
4. Open `Services/PatchService.luau` — that's the only file with `Instance:Destroy`, `:ClearAllChildren`, or property writes outside scanners

If those two files match what's in this repo, the plugin is doing nothing else.
