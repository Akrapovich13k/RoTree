# @rotree/core

Shared TypeScript core used by both the **CLI** (`rotree serve`) and the
**VS Code extension**. Zero dependencies, zero editor-specific code — just
Node's standard library.

## Exports

```ts
import {
  HttpServer,        // loopback HTTP listener for the Roblox plugin
  ExportReader,      // reads & writes .rotree/*
  ContextBuilder,    // builds CLAUDE_CONTEXT.md
  RojoComparator,    // diffs Studio export vs default.project.json
  PatchManager,      // lists/reads/writes patches
  ROTREE_VERSION,
} from "@rotree/core";
```

The HTTP server only binds to `127.0.0.1` and rejects requests whose
`X-RoTree-Version` header doesn't share the same major version.
