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
  console.log("  context      Regenerate .rotree/CLAUDE_CONTEXT.md from the last export.");
  console.log("  compare      Diff the Studio export against your default.project.json.");
  console.log("  init         Scaffold a .rotreeignore in the current directory.");
  console.log("  mcp-config   Print a config snippet for Claude Code / Claude Desktop.");
  console.log("  version      Print the RoTree version.");
  console.log("  help         Show this help.");
  console.log("");
  console.log("Options:");
  console.log("  --port <n>          Port to listen on (default 34872)");
  console.log("  --cwd <dir>         Workspace root (default: current directory)");
  console.log("  --output <dir>      Subfolder for exports (default: .rotree)");
  console.log("");
  console.log("Examples:");
  console.log("  rotree serve");
  console.log("  rotree serve --port 34900");
  console.log("  rotree mcp --cwd ~/MyGame");
  console.log("  rotree build --plugin ./plugin --out RoTree.rbxm");
  console.log("");
}

async function commandMcp(args: ParsedArgs): Promise<void> {
  const workspaceRoot = path.resolve(
    typeof args.flags.cwd === "string" ? args.flags.cwd : process.cwd(),
  );
  const exportFolderName =
    typeof args.flags.output === "string" ? args.flags.output : ".rotree";
  await startMcpServer({ workspaceRoot, exportFolderName });
}

function commandMcpConfig(args: ParsedArgs): void {
  const cwd = typeof args.flags.cwd === "string"
    ? path.resolve(args.flags.cwd)
    : process.cwd();
  const config = {
    mcpServers: {
      rotree: {
        command: "rotree",
        args: ["mcp", "--cwd", cwd],
      },
    },
  };
  console.log("");
  console.log(color(BOLD, "Copy this into your Claude Code or Claude Desktop MCP config:"));
  console.log("");
  console.log(JSON.stringify(config, null, 2));
  console.log("");
  console.log(color(DIM, "Claude Code: ~/.claude/mcp.json (or your project's .mcp.json)"));
  console.log(color(DIM, "Claude Desktop: ~/Library/Application Support/Claude/claude_desktop_config.json (macOS)"));
  console.log(color(DIM, "                 %APPDATA%\\Claude\\claude_desktop_config.json (Windows)"));
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
  const rojo = new RojoComparator(workspaceRoot, reader);
  const context = new ContextBuilder(reader, rojo);
  return { workspaceRoot, exportFolderName, reader, patches, rojo, context };
}

async function commandServe(args: ParsedArgs): Promise<void> {
  banner();
  const port = parseInt(
    typeof args.flags.port === "string" ? args.flags.port : "34872",
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
    log("warn", "no default.project.json found in workspace");
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
