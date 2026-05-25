import * as path from "path";
import * as fs from "fs/promises";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import {
  ExportReader,
  ContextBuilder,
  RojoComparator,
  PatchManager,
  HttpServer,
  TreeNode,
  ScriptEntry,
  GuiEntry,
  ExportPayload,
  BackupPayload,
  Patch,
  ROTREE_VERSION,
} from "@rotree/core";

const TOOLS = [
  {
    name: "rotree_status",
    description:
      "Get the freshness and stats of the current RoTree export (place name, exported-at timestamp, instance/script/remote/gui counts). Cheap. Call this first.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "rotree_get_tree",
    description:
      "Return a subtree of the Roblox DataModel as JSON. Supply `path` to focus (e.g. 'ServerScriptService' or 'ReplicatedStorage.Remotes'). Use `maxDepth` to limit traversal. Does NOT include script source — use `rotree_get_script` for that.",
    inputSchema: {
      type: "object",
      properties: {
        path: {
          type: "string",
          description:
            "Dot-separated path from a service root, e.g. 'ServerScriptService.Modules'. Omit for the full root list.",
        },
        maxDepth: {
          type: "integer",
          description: "Maximum depth to descend. Defaults to 3.",
          minimum: 1,
          maximum: 20,
        },
      },
      additionalProperties: false,
    },
  },
  {
    name: "rotree_list_scripts",
    description:
      "List every script in the export with name, full path, class (Script/LocalScript/ModuleScript), and line count. Source is NOT included — call `rotree_get_script` for that. Optional `filter` substring matches against the full path.",
    inputSchema: {
      type: "object",
      properties: {
        filter: { type: "string", description: "Case-insensitive substring filter on fullPath." },
        kind: {
          type: "string",
          enum: ["Script", "LocalScript", "ModuleScript"],
          description: "Limit to one className.",
        },
      },
      additionalProperties: false,
    },
  },
  {
    name: "rotree_get_script",
    description:
      "Return a single script with its full source. `path` is the dot-separated fullPath (e.g. 'ServerScriptService.ShopServer'). Returns null if not found or redacted.",
    inputSchema: {
      type: "object",
      properties: { path: { type: "string" } },
      required: ["path"],
      additionalProperties: false,
    },
  },
  {
    name: "rotree_list_remotes",
    description: "List every RemoteEvent / RemoteFunction / BindableEvent / BindableFunction.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "rotree_list_gui",
    description:
      "List ScreenGuis and their immediate children. For full nested GUI layout, ask for the file via the `rotree://gui` resource.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "rotree_search",
    description:
      "Search the export by name or class. Returns instances whose name OR fullPath OR className contains the query (case-insensitive). Lightweight — names + paths only.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string" },
        kind: {
          type: "string",
          enum: ["all", "script", "remote", "gui", "part", "model"],
          description: "Filter by entity kind. Default 'all'.",
        },
        limit: { type: "integer", default: 50 },
      },
      required: ["query"],
      additionalProperties: false,
    },
  },
  {
    name: "rotree_get_context",
    description:
      "Return the contents of CLAUDE_CONTEXT.md — a Markdown overview of the game. Cheap, ~5-15 KB.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "rotree_get_summary",
    description: "Return the contents of summary.md — bullet-list export stats.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "rotree_get_attributes",
    description: "Return the attributes map. Optional `path` filters to entries whose key starts with the given prefix.",
    inputSchema: {
      type: "object",
      properties: { path: { type: "string" } },
      additionalProperties: false,
    },
  },
  {
    name: "rotree_get_tags",
    description: "Return the CollectionService tag map: { tag: [instance paths] }.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "rotree_rojo_compare",
    description:
      "If the workspace contains a default.project.json, diff the Studio export against it. Returns { onlyInStudio, onlyInRojo, differentSource }.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "rotree_get_instance",
    description:
      "Return ALL captured properties for a single instance: tree node info, attributes, and the full property bag (Position, Size, Color, Material, Text, Source, etc.). Use this when you need to know every property of one specific object.",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Dot-separated fullPath, e.g. 'Workspace.Shop.Trigger'." },
      },
      required: ["path"],
      additionalProperties: false,
    },
  },
  {
    name: "rotree_get_properties",
    description:
      "Bulk property fetch. Returns { path: { prop: value } } for all paths matching a `pathPrefix`. Without the prefix returns everything (can be large — prefer `rotree_get_instance` for one object).",
    inputSchema: {
      type: "object",
      properties: {
        pathPrefix: { type: "string", description: "Only entries whose fullPath starts with this string." },
      },
      additionalProperties: false,
    },
  },
  {
    name: "rotree_write_patch",
    description:
      "Save a RoTree patch JSON to .rotree/patches/<id>.json so the user can apply it via the Studio plugin (Apply Patch button). DOES NOT modify the live game. Use this for changes you want the user to review first. Supports the same ops as rotree_apply_patch (setSource, setProperties, createInstance, createScript, createFolder, rename, delete).",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string", description: "Filename-safe identifier (e.g. 'fix-shop-typo')." },
        title: { type: "string" },
        description: { type: "string" },
        critical: { type: "boolean", default: false },
        ops: {
          type: "array",
          items: {
            type: "object",
            properties: {
              op: {
                type: "string",
                enum: ["setSource", "setProperties", "createFolder", "createScript", "createInstance", "rename", "delete"],
              },
              path: { type: "string" },
              parentPath: { type: "string" },
              name: { type: "string" },
              className: { type: "string" },
              source: { type: "string" },
              props: { type: "object" },
            },
            required: ["op"],
            additionalProperties: false,
          },
        },
      },
      required: ["id", "title", "ops"],
      additionalProperties: false,
    },
  },
  {
    name: "rotree_apply_patch",
    description:
      "Apply a patch to the live Roblox game. ONLY works if the user has enabled 'Allow AI auto-apply' in the RoTree plugin. " +
      "Supported ops:\n" +
      "  - setSource: change Source of a Script/LocalScript/ModuleScript (needs path, source)\n" +
      "  - setProperties: set props on an existing instance (needs path, props)\n" +
      "  - createInstance: create ANY instance class (needs parentPath, className; optional name, props, source)\n" +
      "  - createScript: shortcut for Script/LocalScript/ModuleScript (needs parentPath, name, className; optional source)\n" +
      "  - createFolder: create a Folder (needs parentPath, name)\n" +
      "  - rename: rename an instance (needs path, name)\n" +
      "  - delete: destroy an instance (needs path)\n" +
      "Properties must be passed in the same JSON shapes that PropertyScanner emits: Vector3 = {x,y,z}, Color3 = {r,g,b}, UDim2 = {x:{scale,offset}, y:{scale,offset}}, CFrame = {components:[12 nums]}, enums = plain string or {__enum, value}. Arrays of 3 numbers are accepted as Vector3 (or Color3 if all in [0,1]). " +
      "Critical patches (DataStore, leaderstats, MarketplaceService, anti-cheat, >20 deletes) are always refused — those must go through `rotree_write_patch` for manual review. " +
      "A backup snapshot is created automatically before any apply, and every change goes through Studio's ChangeHistoryService so the user can Ctrl+Z. " +
      "If auto-apply is off or Studio isn't responding, the patch is saved as a pending patch instead.",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string" },
        title: { type: "string" },
        description: { type: "string" },
        critical: { type: "boolean", default: false },
        ops: {
          type: "array",
          items: {
            type: "object",
            properties: {
              op: {
                type: "string",
                enum: ["setSource", "setProperties", "createFolder", "createScript", "createInstance", "rename", "delete"],
              },
              path: { type: "string" },
              parentPath: { type: "string" },
              name: { type: "string" },
              className: { type: "string" },
              source: { type: "string" },
              props: { type: "object" },
            },
            required: ["op"],
            additionalProperties: false,
          },
        },
      },
      required: ["id", "title", "ops"],
      additionalProperties: false,
    },
  },
];

function findInTree(nodes: TreeNode[], targetPath: string): TreeNode | null {
  const parts = targetPath.split(".");
  let current: TreeNode | undefined = nodes.find((n) => n.name === parts[0]);
  if (!current) return null;
  for (let i = 1; i < parts.length; i++) {
    const next: TreeNode | undefined = current.children?.find((n) => n.name === parts[i]);
    if (!next) return null;
    current = next;
  }
  return current;
}

function truncateTree(node: TreeNode, depth: number): TreeNode {
  const out: TreeNode = { ...node };
  if (depth <= 0) {
    if (node.children && node.children.length > 0) {
      (out as TreeNode & { _truncated?: number })._truncated = node.children.length;
      delete out.children;
    }
    return out;
  }
  if (out.children) {
    out.children = out.children.map((c) => truncateTree(c, depth - 1));
  }
  return out;
}

interface McpServerOptions {
  workspaceRoot: string;
  exportFolderName?: string;
  port?: number;
  noServe?: boolean;
}

function dbg(msg: string): void {
  // MCP stdio is reserved for JSON-RPC — log to stderr only.
  process.stderr.write(`[rotree mcp] ${msg}\n`);
}

export async function startMcpServer(opts: McpServerOptions): Promise<void> {
  const reader = new ExportReader({
    workspaceRoot: opts.workspaceRoot,
    exportFolderName: opts.exportFolderName,
  });
  await reader.ensureFolder();
  const rojo = new RojoComparator(opts.workspaceRoot, reader);
  const context = new ContextBuilder(reader, rojo);
  const patches = new PatchManager(reader);

  let httpServer: HttpServer | undefined;
  if (!opts.noServe) {
    httpServer = new HttpServer({
      reader,
      patches,
      onExport: async (p: ExportPayload | BackupPayload) => {
        if (p.kind === "backup") {
          await reader.writeBackup(p as BackupPayload);
          return;
        }
        await reader.writeExport(p as ExportPayload);
      },
      onOpenFolder: async () => {
        // No-op in MCP context — the AI doesn't reveal folders.
      },
      log: (msg, level) => {
        if (level !== "info") dbg(`[${level}] ${msg}`);
      },
    });
    const port = opts.port ?? 34872;
    try {
      await httpServer.start(port);
      dbg(`bridge listening on http://localhost:${port}`);
    } catch (err) {
      dbg(`could not start bridge on ${port}: ${(err as Error).message}`);
      dbg("MCP tools that read .rotree/ still work, but auto-apply won't.");
      httpServer = undefined;
    }
  }

  const server = new Server(
    { name: "rotree", version: ROTREE_VERSION },
    { capabilities: { tools: {}, resources: {} } },
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

  server.setRequestHandler(ListResourcesRequestSchema, async () => ({
    resources: [
      { uri: "rotree://context", name: "Claude Context", mimeType: "text/markdown" },
      { uri: "rotree://summary", name: "Export Summary", mimeType: "text/markdown" },
      { uri: "rotree://tree", name: "Game Tree", mimeType: "application/json" },
      { uri: "rotree://scripts", name: "Scripts Map", mimeType: "application/json" },
      { uri: "rotree://remotes", name: "Remotes Map", mimeType: "application/json" },
      { uri: "rotree://gui", name: "GUI Map", mimeType: "application/json" },
      { uri: "rotree://services", name: "Services Map", mimeType: "application/json" },
      { uri: "rotree://attributes", name: "Attributes Map", mimeType: "application/json" },
      { uri: "rotree://tags", name: "Collection Tags", mimeType: "application/json" },
    ],
  }));

  server.setRequestHandler(ReadResourceRequestSchema, async (req) => {
    const uri = req.params.uri;
    const map: Record<string, string> = {
      "rotree://context": "CLAUDE_CONTEXT.md",
      "rotree://summary": "summary.md",
      "rotree://tree": "game-tree.json",
      "rotree://scripts": "scripts-map.json",
      "rotree://remotes": "remotes-map.json",
      "rotree://gui": "gui-map.json",
      "rotree://services": "services-map.json",
      "rotree://attributes": "attributes-map.json",
      "rotree://tags": "collection-tags.json",
    };
    const file = map[uri];
    if (!file) throw new Error(`unknown resource: ${uri}`);
    const full = path.join(reader.folder, file);
    const text = await fs.readFile(full, "utf8").catch(() => "");
    const mime = file.endsWith(".md") ? "text/markdown" : "application/json";
    return { contents: [{ uri, mimeType: mime, text }] };
  });

  server.setRequestHandler(CallToolRequestSchema, async (req) => {
    const name = req.params.name;
    const args = (req.params.arguments ?? {}) as Record<string, unknown>;

    try {
      switch (name) {
        case "rotree_status": {
          const info = await reader.lastExportInfo();
          if (!info) {
            return textResult(
              "No RoTree export found in .rotree/. Run `rotree serve`, then click 'Export Game Tree' in Roblox Studio.",
            );
          }
          return jsonResult({
            placeName: info.placeName,
            placeId: info.placeId,
            exportedAt: info.exportedAt,
            pluginVersion: info.pluginVersion,
            kind: info.kind,
            stats: info.stats,
            workspaceRoot: opts.workspaceRoot,
            exportFolder: reader.folder,
          });
        }

        case "rotree_get_tree": {
          const tree = (await reader.tree()) ?? [];
          const targetPath = typeof args.path === "string" ? args.path : undefined;
          const maxDepth = typeof args.maxDepth === "number" ? args.maxDepth : 3;
          if (!targetPath) {
            return jsonResult(tree.map((n) => truncateTree(n, maxDepth)));
          }
          const node = findInTree(tree, targetPath);
          if (!node) return textResult(`path not found: ${targetPath}`);
          return jsonResult(truncateTree(node, maxDepth));
        }

        case "rotree_list_scripts": {
          const scripts = (await reader.scripts()) ?? [];
          const filter = typeof args.filter === "string" ? args.filter.toLowerCase() : undefined;
          const kind = typeof args.kind === "string" ? args.kind : undefined;
          const filtered = scripts.filter((s) => {
            if (kind && s.className !== kind) return false;
            if (filter && !s.fullPath.toLowerCase().includes(filter)) return false;
            return true;
          });
          return jsonResult(
            filtered.map((s: ScriptEntry) => ({
              name: s.name,
              className: s.className,
              fullPath: s.fullPath,
              lines: s.lines,
              redacted: s.redacted,
            })),
          );
        }

        case "rotree_get_script": {
          const target = String(args.path ?? "");
          const scripts = (await reader.scripts()) ?? [];
          const found = scripts.find((s) => s.fullPath === target);
          if (!found) return textResult(`script not found: ${target}`);
          if (found.redacted) return textResult(`script is redacted by .rotreeignore: ${target}`);
          return jsonResult(found);
        }

        case "rotree_list_remotes": {
          const remotes = (await reader.remotes()) ?? [];
          return jsonResult(remotes);
        }

        case "rotree_list_gui": {
          const gui = (await reader.gui()) ?? [];
          const top = gui.filter((g) => g.className === "ScreenGui" || g.className === "SurfaceGui" || g.className === "BillboardGui");
          return jsonResult(
            top.map((g: GuiEntry) => ({
              name: g.name,
              className: g.className,
              fullPath: g.fullPath,
              visible: g.visible,
              children: g.children,
            })),
          );
        }

        case "rotree_search": {
          const query = String(args.query ?? "").toLowerCase();
          const kind = (args.kind as string | undefined) ?? "all";
          const limit = (args.limit as number | undefined) ?? 50;
          if (!query) return textResult("empty query");

          const out: { kind: string; name: string; className: string; fullPath: string }[] = [];

          if (kind === "all" || kind === "script") {
            for (const s of (await reader.scripts()) ?? []) {
              if (matches(query, s.name, s.fullPath, s.className)) {
                out.push({ kind: "script", name: s.name, className: s.className, fullPath: s.fullPath });
              }
            }
          }
          if (kind === "all" || kind === "remote") {
            for (const r of (await reader.remotes()) ?? []) {
              if (matches(query, r.name, r.fullPath, r.className)) {
                out.push({ kind: "remote", name: r.name, className: r.className, fullPath: r.fullPath });
              }
            }
          }
          if (kind === "all" || kind === "gui") {
            for (const g of (await reader.gui()) ?? []) {
              if (matches(query, g.name, g.fullPath, g.className)) {
                out.push({ kind: "gui", name: g.name, className: g.className, fullPath: g.fullPath });
              }
            }
          }
          if (kind === "all" || kind === "part" || kind === "model") {
            const tree = (await reader.tree()) ?? [];
            walkTree(tree, (n: TreeNode) => {
              if (kind === "part" && !n.isPart) return;
              if (kind === "model" && !n.isModel) return;
              if (kind === "all" && !n.isPart && !n.isModel) return;
              if (matches(query, n.name, n.fullPath, n.className)) {
                out.push({
                  kind: n.isPart ? "part" : n.isModel ? "model" : "instance",
                  name: n.name,
                  className: n.className,
                  fullPath: n.fullPath,
                });
              }
            });
          }
          return jsonResult(out.slice(0, limit));
        }

        case "rotree_get_context": {
          const file = path.join(reader.folder, "CLAUDE_CONTEXT.md");
          const text = await fs.readFile(file, "utf8").catch(() => "");
          if (!text) {
            const built = await context.build();
            return textResult(built);
          }
          return textResult(text);
        }

        case "rotree_get_summary": {
          const file = path.join(reader.folder, "summary.md");
          const text = await fs.readFile(file, "utf8").catch(() => "(no summary yet)");
          return textResult(text);
        }

        case "rotree_get_attributes": {
          const attrs = (await reader.readJson<Record<string, Record<string, unknown>>>(
            "attributes-map.json",
          )) ?? {};
          const prefix = typeof args.path === "string" ? args.path : "";
          if (!prefix) return jsonResult(attrs);
          const filtered: Record<string, Record<string, unknown>> = {};
          for (const [k, v] of Object.entries(attrs)) {
            if (k.startsWith(prefix)) filtered[k] = v;
          }
          return jsonResult(filtered);
        }

        case "rotree_get_tags": {
          const tags = (await reader.readJson<Record<string, string[]>>("collection-tags.json")) ?? {};
          return jsonResult(tags);
        }

        case "rotree_rojo_compare": {
          if (!(await rojo.detect())) {
            return textResult("no default.project.json in workspace");
          }
          const diff = await rojo.compare();
          if (!diff) return textResult("could not parse Rojo project");
          return jsonResult(diff);
        }

        case "rotree_get_instance": {
          const target = String(args.path ?? "");
          if (!target) return textResult("path is required");
          const tree = (await reader.tree()) ?? [];
          const node = findInTree(tree, target);
          const properties = (await reader.readJson<Record<string, Record<string, unknown>>>(
            "instance-properties.json",
          )) ?? {};
          const attributes = (await reader.readJson<Record<string, Record<string, unknown>>>(
            "attributes-map.json",
          )) ?? {};
          const tags = (await reader.readJson<Record<string, string[]>>(
            "collection-tags.json",
          )) ?? {};

          // Figure out which tags include this path
          const ownTags: string[] = [];
          for (const [tag, paths] of Object.entries(tags)) {
            if (paths.includes(target)) ownTags.push(tag);
          }

          // If it's a script, attach source from scripts-map
          let source: string | null | undefined;
          const scripts = (await reader.scripts()) ?? [];
          const scriptEntry = scripts.find((s) => s.fullPath === target);
          if (scriptEntry) source = scriptEntry.source;

          return jsonResult({
            path: target,
            found: node !== null || properties[target] !== undefined,
            node,
            properties: properties[target] ?? {},
            attributes: attributes[target] ?? {},
            tags: ownTags,
            source,
          });
        }

        case "rotree_get_properties": {
          const all = (await reader.readJson<Record<string, Record<string, unknown>>>(
            "instance-properties.json",
          )) ?? {};
          const prefix = typeof args.pathPrefix === "string" ? args.pathPrefix : "";
          if (!prefix) return jsonResult(all);
          const filtered: Record<string, Record<string, unknown>> = {};
          for (const [k, v] of Object.entries(all)) {
            if (k.startsWith(prefix)) filtered[k] = v;
          }
          return jsonResult(filtered);
        }

        case "rotree_apply_patch": {
          const patch: Patch = {
            id: String(args.id),
            title: String(args.title),
            description: typeof args.description === "string" ? args.description : undefined,
            critical: args.critical === true,
            ops: Array.isArray(args.ops) ? (args.ops as Patch["ops"]) : [],
          };
          // Always write the patch file so it's reviewable + recoverable.
          const safeId = patch.id.replace(/[^a-z0-9._-]+/gi, "_");
          const dir = path.join(reader.folder, "patches");
          await fs.mkdir(dir, { recursive: true });
          await fs.writeFile(path.join(dir, safeId + ".json"), JSON.stringify(patch, null, 2), "utf8");

          if (!httpServer) {
            return textResult(
              `Patch saved to .rotree/patches/${safeId}.json. ` +
              `(No live bridge — start \`rotree serve\` or run \`rotree mcp\` without --no-serve to enable auto-apply.) ` +
              `Ask the user to apply via Studio → RoTree → Apply Patch.`,
            );
          }
          if (!httpServer.autoApplyOnline) {
            return textResult(
              `Patch saved to .rotree/patches/${safeId}.json. ` +
              `Auto-apply is OFF (toggle "Allow AI auto-apply" in the Studio plugin to enable). ` +
              `Ask the user to apply via Studio → RoTree → Apply Patch.`,
            );
          }

          try {
            const result = await httpServer.queueAutoApply(patch, 12000);
            return jsonResult({
              applied: true,
              result,
              backupFolder: ".rotree/backups/",
            });
          } catch (err) {
            return textResult(
              `Queued but no response in time: ${(err as Error).message}. ` +
              `Patch is still saved at .rotree/patches/${safeId}.json for manual review.`,
            );
          }
        }

        case "rotree_write_patch": {
          const patch = {
            id: String(args.id),
            title: String(args.title),
            description: typeof args.description === "string" ? args.description : undefined,
            critical: args.critical === true,
            ops: Array.isArray(args.ops) ? (args.ops as unknown[]) : [],
          };
          const safeId = patch.id.replace(/[^a-z0-9._-]+/gi, "_");
          const dir = path.join(reader.folder, "patches");
          await fs.mkdir(dir, { recursive: true });
          const file = path.join(dir, safeId + ".json");
          await fs.writeFile(file, JSON.stringify(patch, null, 2), "utf8");
          return textResult(
            `wrote patch to ${file}\n\nTell the user: in Roblox Studio click RoTree → Apply Patch to preview and (optionally) apply it. RoTree will NOT apply it automatically.`,
          );
        }
      }
      return textResult(`unknown tool: ${name}`);
    } catch (err) {
      return textResult(`error: ${(err as Error).message}`);
    }
  });

  const transport = new StdioServerTransport();
  await server.connect(transport);
}

function matches(query: string, ...fields: string[]): boolean {
  for (const f of fields) {
    if (f.toLowerCase().includes(query)) return true;
  }
  return false;
}

function walkTree(nodes: TreeNode[], visit: (n: TreeNode) => void): void {
  const stack: TreeNode[] = [...nodes];
  while (stack.length > 0) {
    const n = stack.pop() as TreeNode;
    visit(n);
    if (n.children) for (const c of n.children) stack.push(c);
  }
}

function textResult(text: string) {
  return { content: [{ type: "text" as const, text }] };
}

function jsonResult(data: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
}
