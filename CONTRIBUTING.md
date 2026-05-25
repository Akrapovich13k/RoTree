# Contributing to RoTree

Thanks for considering a contribution. RoTree is MIT-licensed — by submitting
a PR you agree your contribution is offered under the same license.

## Quick start

```bash
git clone https://github.com/Akrapovich13k/RoTree.git
cd RoTree
npm install
npm run build          # builds core, cli, extension
npm run lint           # type-checks all workspaces
```

To rebuild the single-file CLI bundle after a code change:

```bash
npm run bundle -w @rotree/cli
```

That regenerates `cli/dist/rotree.js`. Commit it together with your source
changes — the one-line installer downloads it directly.

## Project layout

| Path        | What's in there                                                      |
|-------------|----------------------------------------------------------------------|
| `core/`     | Shared TS modules (HTTP server, file IO, Rojo, context). No vscode.  |
| `cli/`      | `rotree` CLI + MCP server. Imports `@rotree/core`.                   |
| `extension/`| VS Code extension. Imports `@rotree/core`.                           |
| `plugin/`   | Roblox Studio plugin in Luau, buildable with Rojo.                   |
| `docs/`     | Architecture, install, usage, security, plugin preview.              |

## Conventions

- TypeScript: `tsc --noEmit` must pass cleanly. No `any` unless escaping
  Roblox/MCP-untyped boundaries.
- Luau: `--!strict` at the top of every module. Use `pcall` at Studio
  boundaries (reading instance properties, network).
- Security-critical files (`plugin/src/Services/HttpBridge.luau`,
  `plugin/src/Services/PatchService.luau`) keep their single-responsibility
  property: **only** these touch the network and **only** these mutate the
  DataModel. PRs that broaden that surface need a strong justification.

## Reporting issues

Please include:

- RoTree version (`rotree version`)
- Plugin version (footer of the Studio window)
- Steps to reproduce
- Studio Output log if relevant
- Any error from `rotree serve` / `rotree mcp` stdout

## Cutting a release

Releases ship five standalone binaries (Linux x64/arm64, macOS Intel/ARM,
Windows x64) so users who don't want to install Node can grab `rotree`
directly. The build happens in CI on tag push.

```bash
# 1. Bump version in core/package.json, cli/package.json,
#    extension/package.json, plugin/src/Config.luau.
# 2. Update CHANGELOG.md: move Unreleased entries under the new version.
# 3. Commit + tag.
git commit -am "Release v0.2.0"
git tag v0.2.0
git push && git push --tags
```

`.github/workflows/release.yml` then:
- Installs Node + Bun
- Builds + bundles
- `bun build --compile` against five targets
- Creates a GitHub Release with auto-generated notes, all five binaries,
  the JS bundle, and `SHA256SUMS.txt`

The one-line installers (`install.sh` / `install.ps1`) start downloading
the new version on the next user install.

## Security

If you find a security issue, please **don't** open a public issue — see
[SECURITY.md](SECURITY.md) for how to report it privately.
