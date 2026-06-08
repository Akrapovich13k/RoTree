#!/usr/bin/env node
import * as path from "path";
import * as fs from "fs/promises";
import { spawn } from "child_process";
import {
  HttpServer,
  ExportReader,
  ContextBuilder,
  RojoComparator,
  PatchManager,
  ROTREE_VERSION,
  ExportPayload,
  BackupPayload,
} from "@rotree/core";
import { startMcpServer } from "./mcp";

interface ParsedArgs {
  command?: string;
  flags: Record<string, string | boolean>;
  positional: string[];
}

function parseArgs(argv: string[]): ParsedArgs {
  const flags: Record<string, string | boolean> = {};
  const positional: string[] = [];
  let command: string | undefined;

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const eq = a.indexOf("=");
      if (eq >= 0) {
        flags[a.slice(2, eq)] = a.slice(eq + 1);
      } else {
        const next = argv[i + 1];
        if (next && !next.startsWith("-")) {
          flags[a.slice(2)] = next;
          i++;
        } else {
          flags[a.slice(2)] = true;
        }
      }
    } else if (a.startsWith("-") && a.length > 1) {
      const next = argv[i + 1];
      if (next && !next.startsWith("-")) {
        flags[a.slice(1)] = next;
        i++;
      } else {
        flags[a.slice(1)] = true;
      }
    } else if (!command) {
      command = a;
    } else {
      positional.push(a);
    }
  }
  return { command, flags, positional };
}

const RESET = "\x1b[0m";
const DIM = "\x1b[2m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";

function color(c: string, s: string): string {
  return process.stdout.isTTY ? `${c}${s}${RESET}` : s;
}

function banner(): void {
  console.log(color(BOLD, `RoTree v${ROTREE_VERSION}`));
}

function help(): void {
  banner();
  console.log("");
  console.log("Usage: rotree <command> [options]");
  console.log("");
  console.log("Commands:");
  console.log("  serve        Start the local bridge for the Roblox Studio plugin.");
  console.log("  mcp          Start the MCP server (for Claude Code, Claude Desktop, ...).");
  console.log("  build        Build the RoTree plugin (.rbxm) via Rojo.");
  console.log("  context      Regenerate .rotree/AI_CONTEXT.md from the last export.");
  console.log("  compare      Diff the Studio export against your default.project.json.");
  console.log("  init         Scaffold a .rotreeignore in the current directory.");
  console.log("  mcp-config   Print a config snippet for Claude Code / Claude Desktop.");
  console.log("  mcp-install  Auto-write that snippet into your AI client's config (no copy-paste).");
  console.log("  version      Print the RoTree version.");
  console.log("  help         Show this help.");
  console.log("");
  console.log("Options:");
  console.log("  --port <n>            Port to listen on (default 34873)");
  console.log("  --cwd <dir>           Workspace root (default: current directory)");
  console.log("  --output <dir>        Subfolder for exports (default: .rotree)");
  console.log("  --rojo-project <p>    Path to a Rojo project file or its folder");
  console.log("                        (default: auto-discover near --cwd)");
  console.log("  --stale-days <n>      Warn when an export is older than n days (mcp; default 3)");
  console.log("");
  console.log("Examples:");
  console.log("  rotree serve");
  console.log("  rotree serve --port 34900");
  console.log("  rotree mcp --cwd ~/MyGame");
  console.log("  rotree mcp-install --cwd ~/MyGame --rojo-project ~/MyGame/game/default.project.json");
  console.log("  rotree build --plugin ./plugin --out RoTree.rbxm");
  console.log("");
}

async function commandMcp(args: ParsedArgs): Promise<void> {
  const workspaceRoot = path.resolve(
    typeof args.flags.cwd === "string" ? args.flags.cwd : process.cwd(),
  );
  const exportFolderName =
    typeof args.flags.output === "string" ? args.flags.output : ".rotree";
  const port = parseInt(
    typeof args.flags.port === "string" ? args.flags.port : "34873",
    10,
  );
  const noServe = args.flags["no-serve"] === true;
  const rojoProjectPath = rojoProjectFlag(args);
  const staleAfterDays =
    typeof args.flags["stale-days"] === "string"
      ? parseInt(args.flags["stale-days"], 10)
      : undefined;
  await startMcpServer({
    workspaceRoot,
    exportFolderName,
    port,
    noServe,
    rojoProjectPath,
    staleAfterDays,
  });
}

function commandMcpConfig(args: ParsedArgs): void {
  const cwd = typeof args.flags.cwd === "string"
    ? path.resolve(args.flags.cwd)
    : process.cwd();
  const mcpArgs = ["mcp", "--cwd", cwd];
  const rojoProject = rojoProjectFlag(args);
  if (rojoProject) mcpArgs.push("--rojo-project", path.resolve(rojoProject));
  const config = {
    mcpServers: {
      rotree: {
        command: "rotree",
        args: mcpArgs,
      },
    },
  };
  console.log("");
  console.log(color(BOLD, "Copy this into your Claude Code or Claude Desktop MCP config:"));
  console.log("");
  console.log(JSON.stringify(config, null, 2));
  console.log("");
  console.log(color(DIM, "Or skip the copy-paste entirely:  rotree mcp-install"));
  console.log("");
}

// ── Resolve the well-known MCP config file paths for each client. ─────
function claudeDesktopConfigPath(): string {
  const home = require("os").homedir();
  if (process.platform === "darwin") {
    return path.join(home, "Library", "Application Support", "Claude", "claude_desktop_config.json");
  }
  if (process.platform === "win32") {
    const appdata = process.env.APPDATA || path.join(home, "AppData", "Roaming");
    return path.join(appdata, "Claude", "claude_desktop_config.json");
  }
  return path.join(home, ".config", "Claude", "claude_desktop_config.json");
}

function claudeCodeUserConfigPath(): string {
  const home = require("os").homedir();
  return path.join(home, ".claude.json");
}

function claudeCodeProjectConfigPath(cwd: string): string {
  return path.join(cwd, ".mcp.json");
}

async function patchMcpConfigFile(file: string, serverName: string, entry: Record<string, unknown>): Promise<"created" | "updated" | "unchanged"> {
  await fs.mkdir(path.dirname(file), { recursive: true });
  let existing: any = {};
  try {
    existing = JSON.parse(await fs.readFile(file, "utf8"));
  } catch {
    // file doesn't exist or is invalid — start fresh
    existing = {};
  }
  if (!existing.mcpServers || typeof existing.mcpServers !== "object") {
    existing.mcpServers = {};
  }
  const prev = JSON.stringify(existing.mcpServers[serverName] ?? null);
  const next = JSON.stringify(entry);
  if (prev === next) return "unchanged";
  // Backup once
  try {
    await fs.copyFile(file, file + ".rotree-backup");
  } catch {
    // file might not exist — that's fine, the next write creates it
  }
  existing.mcpServers[serverName] = entry;
  await fs.writeFile(file, JSON.stringify(existing, null, 2) + "\n", "utf8");
  return prev === "null" ? "created" : "updated";
}

async function commandMcpInstall(args: ParsedArgs): Promise<void> {
  const cwd = typeof args.flags.cwd === "string"
    ? path.resolve(args.flags.cwd)
    : process.cwd();
  const client = (typeof args.flags.client === "string" ? args.flags.client : "all").toLowerCase();
  const name = typeof args.flags.name === "string" ? args.flags.name : "rotree";

  const mcpArgs = ["mcp", "--cwd", cwd];
  const rojoProject = rojoProjectFlag(args);
  if (rojoProject) mcpArgs.push("--rojo-project", path.resolve(rojoProject));
  const entry: Record<string, unknown> = {
    command: "rotree",
    args: mcpArgs,
  };

  banner();
  log("info", `workspace: ${color(CYAN, cwd)}`);

  const targets: { label: string; file: string }[] = [];
  if (client === "all" || client === "claude-desktop") {
    targets.push({ label: "Claude Desktop", file: claudeDesktopConfigPath() });
  }
  if (client === "all" || client === "claude-code-user") {
    targets.push({ label: "Claude Code (user)", file: claudeCodeUserConfigPath() });
  }
  if (client === "all" || client === "claude-code" || client === "claude-code-project") {
    targets.push({ label: "Claude Code (project .mcp.json)", file: claudeCodeProjectConfigPath(cwd) });
  }

  for (const t of targets) {
    try {
      const status = await patchMcpConfigFile(t.file, name, entry);
      if (status === "unchanged") {
        log("info", `${t.label}: already configured (${t.file})`);
      } else {
        log("info", `${t.label}: ${status} ${color(CYAN, t.file)}`);
      }
    } catch (err) {
      log("warn", `${t.label}: ${(err as Error).message}`);
    }
  }

  console.log("");
  console.log(color(BOLD, "Done. Restart your AI client and you'll see the rotree tools."));
  console.log(color(DIM, "Re-run with --cwd <other dir> per project, or --client claude-desktop to target one."));
  console.log("");
}

function ts(): string {
  const d = new Date();
  return d.toTimeString().split(" ")[0];
}

function log(level: "info" | "warn" | "error", msg: string): void {
  const tag =
    level === "error" ? color(RED, "error")
    : level === "warn" ? color(YELLOW, "warn")
    : color(GREEN, "info");
  const stamp = color(DIM, ts());
  console.log(`${stamp} ${tag} ${msg}`);
}

// `--rojo-project` (or `--project`) points at a Rojo project file or its
// directory. Falls back to the ROTREE_ROJO_PROJECT env var, then auto-discovery.
function rojoProjectFlag(args: ParsedArgs): string | undefined {
  const flag = args.flags["rojo-project"] ?? args.flags.project;
  if (typeof flag === "string") return flag;
  if (process.env.ROTREE_ROJO_PROJECT) return process.env.ROTREE_ROJO_PROJECT;
  return undefined;
}

function buildContext(args: ParsedArgs): {
  workspaceRoot: string;
  exportFolderName: string;
  reader: ExportReader;
  patches: PatchManager;
  rojo: RojoComparator;
  context: ContextBuilder;
} {
  const workspaceRoot = path.resolve(
    typeof args.flags.cwd === "string" ? args.flags.cwd : process.cwd(),
  );
  const exportFolderName =
    typeof args.flags.output === "string" ? args.flags.output : ".rotree";
  const reader = new ExportReader({ workspaceRoot, exportFolderName });
  const patches = new PatchManager(reader);
  const rojo = new RojoComparator(workspaceRoot, reader, {
    projectPath: rojoProjectFlag(args),
    log: (msg) => log("info", msg),
  });
  const context = new ContextBuilder(reader, rojo);
  return { workspaceRoot, exportFolderName, reader, patches, rojo, context };
}

async function commandServe(args: ParsedArgs): Promise<void> {
  banner();
  const port = parseInt(
    typeof args.flags.port === "string" ? args.flags.port : "34873",
    10,
  );
  const { workspaceRoot, reader, patches } = buildContext(args);
  await reader.ensureFolder();

  log("info", `workspace: ${color(CYAN, workspaceRoot)}`);
  log("info", `writing to ${color(CYAN, path.relative(workspaceRoot, reader.folder) || "./")}`);

  const server = new HttpServer({
    reader,
    patches,
    onExport: async (p: ExportPayload | BackupPayload) => {
      if (p.kind === "backup") {
        await reader.writeBackup(p as BackupPayload);
        log("info", `backup stored for patch ${(p as BackupPayload).patchId}`);
        return;
      }
      const payload = p as ExportPayload;
      await reader.writeExport(payload);
      log(
        "info",
        `${color(BOLD, payload.kind)} export · ${payload.placeName} · ${payload.stats.instances} instances · ${payload.stats.scripts} scripts`,
      );
    },
    onOpenFolder: async () => {
      log("info", `plugin asked to reveal ${reader.folder}`);
    },
    log: (msg, level) => log(level, msg),
  });

  try {
    await server.start(port);
  } catch (err) {
    log("error", `failed to bind port ${port}: ${(err as Error).message}`);
    process.exit(1);
  }

  console.log("");
  console.log(`${color(GREEN, "✓")} bridge ready · ${color(BOLD, `http://localhost:${port}`)}`);
  console.log(`${color(DIM, "Open Roblox Studio, click RoTree → Export Game Tree.")}`);
  console.log(`${color(DIM, "Press Ctrl+C to stop.")}`);
  console.log("");

  const shutdown = async () => {
    console.log("");
    log("info", "shutting down…");
    await server.stop();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

async function commandContext(args: ParsedArgs): Promise<void> {
  const { context } = buildContext(args);
  const out = await context.writeContextFile();
  log("info", `wrote ${out}`);
}

async function commandCompare(args: ParsedArgs): Promise<void> {
  const { rojo } = buildContext(args);
  if (!(await rojo.detect())) {
    log("warn", "no Rojo project found. Looked in:");
    console.log(await rojo.describeSearch());
    log("warn", "Pass --rojo-project <path> to point at it explicitly.");
    process.exit(1);
  }
  const diff = await rojo.compare();
  if (!diff) {
    log("error", "could not parse Rojo project");
    process.exit(1);
  }
  console.log("");
  console.log(color(BOLD, `Only in Studio (${diff.onlyInStudio.length})`));
  for (const p of diff.onlyInStudio) console.log(`  ${color(YELLOW, "→")} ${p}`);
  console.log("");
  console.log(color(BOLD, `Only in Rojo (${diff.onlyInRojo.length})`));
  for (const p of diff.onlyInRojo) console.log(`  ${color(CYAN, "←")} ${p}`);
  console.log("");
  console.log(color(BOLD, `Different source (${diff.differentSource.length})`));
  for (const d of diff.differentSource) console.log(`  ${color(RED, "≠")} ${d.path}  ${color(DIM, d.rojoFile)}`);
  console.log("");
}

async function commandInit(args: ParsedArgs): Promise<void> {
  const { workspaceRoot } = buildContext(args);
  await fs.mkdir(workspaceRoot, { recursive: true });
  const target = path.join(workspaceRoot, ".rotreeignore");
  try {
    await fs.access(target);
    log("warn", `.rotreeignore already exists at ${target}`);
    return;
  } catch {
    // doesn't exist — write it
  }
  const sample = `# RoTree ignore list (gitignore-style).
# Normal lines redact Source in Safe Mode. Prefix with "critical:" to require
# DOUBLE confirmation before any patch can touch the matched path.

# Don't ship anti-cheat source code
ServerScriptService/Anticheat/**

# Secrets folder
ReplicatedStorage/Secrets/**

# Critical patterns
critical: ServerScriptService/DataStore/**
critical: **/leaderstats/**
`;
  await fs.writeFile(target, sample, "utf8");
  log("info", `wrote ${target}`);
}

async function commandBuild(args: ParsedArgs): Promise<void> {
  const pluginDir = path.resolve(
    typeof args.flags.plugin === "string" ? args.flags.plugin : "./plugin",
  );
  const out = typeof args.flags.out === "string" ? args.flags.out : "RoTree.rbxm";
  log("info", `building ${pluginDir}/default.project.json → ${out}`);
  await new Promise<void>((resolve, reject) => {
    const child = spawn("rojo", ["build", "default.project.json", "-o", out], {
      cwd: pluginDir,
      stdio: "inherit",
    });
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`rojo build exited with code ${code}`));
    });
  }).catch((err: Error) => {
    log("error", err.message);
    log("info", "Install Rojo first: https://rojo.space");
    process.exit(1);
  });
  log("info", "build complete");
}

function commandVersion(): void {
  console.log(`rotree v${ROTREE_VERSION}`);
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  switch (args.command) {
    case undefined:
    case "help":
    case "-h":
    case "--help":
      help();
      return;
    case "version":
    case "-v":
    case "--version":
      commandVersion();
      return;
    case "serve":
      await commandServe(args);
      return;
    case "mcp":
      await commandMcp(args);
      return;
    case "mcp-config":
      commandMcpConfig(args);
      return;
    case "mcp-install":
      await commandMcpInstall(args);
      return;
    case "context":
      await commandContext(args);
      return;
    case "compare":
      await commandCompare(args);
      return;
    case "init":
      await commandInit(args);
      return;
    case "build":
      await commandBuild(args);
      return;
    default:
      console.error(color(RED, `unknown command: ${args.command}`));
      help();
      process.exit(1);
  }
}

main().catch((err: Error) => {
  console.error(color(RED, `error: ${err.message}`));
  process.exit(1);
});
