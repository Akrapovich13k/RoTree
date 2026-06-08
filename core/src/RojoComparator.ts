import * as path from "path";
import * as fs from "fs/promises";
import { ExportReader } from "./ExportReader";
import { ScriptEntry } from "./types";

interface RojoNode {
  $className?: string;
  $path?: string;
  [child: string]: unknown;
}

interface RojoProject {
  name?: string;
  tree?: RojoNode;
}

export interface RojoDiff {
  onlyInStudio: string[];
  onlyInRojo: string[];
  differentSource: { path: string; rojoFile: string }[];
}

export interface RojoComparatorOptions {
  /**
   * Explicit path to a Rojo project. May point at a `*.project.json` file
   * directly, or at a directory that contains one. When omitted, the
   * comparator auto-discovers a project around `workspaceRoot`.
   */
  projectPath?: string;
  /** How many parent directories to walk up while auto-discovering. */
  maxParentLevels?: number;
  /**
   * How deep to recurse into sub-directories while auto-discovering. The
   * Rojo code often lives a few folders below the export workspace (e.g.
   * `workspaceRoot/packages/game/default.project.json`), so we scan further
   * than the immediate children. Defaults to 3.
   */
  maxScanDepth?: number;
  /** Optional logger — used to announce which project file was selected. */
  log?: (msg: string) => void;
}

/**
 * Compares the Studio export against a Rojo project on disk.
 *
 * The Rojo project is no longer assumed to live exactly at
 * `workspaceRoot/default.project.json`. It can be supplied explicitly, or is
 * discovered robustly by looking in the workspace root, then walking up parent
 * directories, then scanning sub-directories (bounded recursion). The resolved path is
 * cached and the list of locations we looked at is kept for error messages.
 */
export class RojoComparator {
  private readonly explicitProjectPath?: string;
  private readonly maxParentLevels: number;
  private readonly maxScanDepth: number;
  private readonly log: (msg: string) => void;

  private resolvedFile: string | null | undefined; // undefined = not resolved yet
  private searched: string[] = [];

  constructor(
    private readonly workspaceRoot: string,
    private readonly reader: ExportReader,
    options: RojoComparatorOptions = {},
  ) {
    this.explicitProjectPath = options.projectPath;
    this.maxParentLevels = options.maxParentLevels ?? 5;
    this.maxScanDepth = options.maxScanDepth ?? 3;
    this.log = options.log ?? (() => {});
  }

  /** Absolute path to the resolved project file, or null if none was found. */
  async projectFile(): Promise<string | null> {
    if (this.resolvedFile !== undefined) return this.resolvedFile;
    this.searched = [];
    const found = await this.discover();
    this.resolvedFile = found;
    if (found) {
      this.log(`using Rojo project: ${found}`);
    }
    return found;
  }

  /** Locations the comparator inspected during the last resolution attempt. */
  searchedLocations(): string[] {
    return [...this.searched];
  }

  /** Human-readable summary of where we looked (for error messages). */
  async describeSearch(): Promise<string> {
    await this.projectFile();
    if (this.searched.length === 0) return "(no candidate locations)";
    return this.searched.map((p) => `  - ${p}`).join("\n");
  }

  async detect(): Promise<boolean> {
    return (await this.projectFile()) !== null;
  }

  async loadProject(): Promise<RojoProject | null> {
    const file = await this.projectFile();
    if (!file) return null;
    try {
      const buf = await fs.readFile(file, "utf8");
      return JSON.parse(buf) as RojoProject;
    } catch {
      return null;
    }
  }

  async compare(): Promise<RojoDiff | null> {
    const file = await this.projectFile();
    const project = await this.loadProject();
    if (!file || !project || !project.tree) return null;

    // Rojo `$path` entries are relative to the project file, not the workspace.
    const projectDir = path.dirname(file);
    const rojoScripts = await this.collectRojoScripts(project.tree, "", projectDir);
    const studio = (await this.reader.scripts()) ?? [];
    const studioMap = new Map<string, ScriptEntry>(studio.map((s) => [s.fullPath, s]));

    const diff: RojoDiff = {
      onlyInStudio: [],
      onlyInRojo: [],
      differentSource: [],
    };

    for (const [studioPath, studioScript] of studioMap.entries()) {
      const rojoMatch = rojoScripts.find((r) => r.fullPath === studioPath);
      if (!rojoMatch) {
        diff.onlyInStudio.push(studioPath);
      } else {
        try {
          const onDisk = await fs.readFile(rojoMatch.file, "utf8");
          if (studioScript.source && onDisk.trim() !== studioScript.source.trim()) {
            diff.differentSource.push({ path: studioPath, rojoFile: rojoMatch.file });
          }
        } catch {
          // file missing on disk
        }
      }
    }

    for (const r of rojoScripts) {
      if (!studioMap.has(r.fullPath)) {
        diff.onlyInRojo.push(r.fullPath);
      }
    }

    return diff;
  }

  // ── Discovery ──────────────────────────────────────────────────────────

  private async discover(): Promise<string | null> {
    // 1. Explicit path wins.
    if (this.explicitProjectPath) {
      const abs = path.isAbsolute(this.explicitProjectPath)
        ? this.explicitProjectPath
        : path.resolve(this.workspaceRoot, this.explicitProjectPath);
      const fromExplicit = await this.fromCandidate(abs);
      if (fromExplicit) return fromExplicit;
      // Explicit but missing — still record it so the error is actionable.
      return null;
    }

    // 2. Workspace root, then walk up parents.
    let dir = this.workspaceRoot;
    for (let level = 0; level <= this.maxParentLevels; level++) {
      const hit = await this.defaultProjectIn(dir);
      if (hit) return hit;
      const parent = path.dirname(dir);
      if (parent === dir) break; // reached filesystem root
      dir = parent;
    }

    // 3. Sub-directories of the workspace root, recursing up to `maxScanDepth`
    //    (breadth-first, shallowest wins). Handy when the export folder sits at
    //    the repo root but the Rojo code lives a few folders down (e.g.
    //    `game/`, `src/`, `packages/game/`).
    const subHit = await this.scanSubdirs(this.workspaceRoot);
    if (subHit) return subHit;

    // 4. Last resort: any `*.project.json` directly in the workspace root.
    const anyHit = await this.anyProjectIn(this.workspaceRoot);
    if (anyHit) return anyHit;

    return null;
  }

  /** Resolve a candidate that may be a file or a directory. */
  private async fromCandidate(candidate: string): Promise<string | null> {
    let stat: import("fs").Stats | undefined;
    try {
      stat = await fs.stat(candidate);
    } catch {
      this.searched.push(candidate);
      return null;
    }
    if (stat.isFile()) {
      this.searched.push(candidate);
      return candidate;
    }
    if (stat.isDirectory()) {
      const inDir = await this.defaultProjectIn(candidate);
      if (inDir) return inDir;
      return this.anyProjectIn(candidate);
    }
    return null;
  }

  private async defaultProjectIn(dir: string): Promise<string | null> {
    const candidate = path.join(dir, "default.project.json");
    this.searched.push(candidate);
    try {
      const stat = await fs.stat(candidate);
      if (stat.isFile()) return candidate;
    } catch {
      // not here
    }
    return null;
  }

  private async anyProjectIn(dir: string): Promise<string | null> {
    let entries: string[];
    try {
      entries = await fs.readdir(dir);
    } catch {
      return null;
    }
    const projects = entries.filter((e) => e.endsWith(".project.json")).sort();
    // Prefer default.project.json (already tried above), then alphabetical.
    for (const p of projects) {
      const full = path.join(dir, p);
      if (!this.searched.includes(full)) this.searched.push(full);
      if (projects.length > 1) {
        this.log(`multiple Rojo projects in ${dir}; using ${p}`);
      }
      return full;
    }
    return null;
  }

  private async scanSubdirs(root: string): Promise<string | null> {
    const skip = new Set([
      "node_modules",
      ".git",
      ".rotree",
      "out",
      "dist",
      "build",
      ".vscode",
    ]);

    // Breadth-first by depth so a shallower project is preferred over a deeper
    // one. `frontier` holds the directories whose children we examine next.
    let frontier: string[] = [root];
    for (let depth = 1; depth <= this.maxScanDepth && frontier.length > 0; depth++) {
      const next: string[] = [];
      for (const dir of frontier) {
        let entries: import("fs").Dirent[];
        try {
          entries = await fs.readdir(dir, { withFileTypes: true });
        } catch {
          continue;
        }
        const subdirs = entries
          .filter((e) => e.isDirectory() && !e.name.startsWith(".") && !skip.has(e.name))
          .sort((a, b) => a.name.localeCompare(b.name));
        for (const e of subdirs) {
          const childDir = path.join(dir, e.name);
          const hit = await this.defaultProjectIn(childDir);
          if (hit) return hit;
          next.push(childDir);
        }
      }
      frontier = next;
    }
    return null;
  }

  private async collectRojoScripts(
    node: RojoNode,
    prefix: string,
    projectDir: string,
  ): Promise<{ fullPath: string; file: string }[]> {
    const out: { fullPath: string; file: string }[] = [];

    const recurse = async (current: RojoNode, currentPath: string) => {
      if (current.$path) {
        const fsPath = path.resolve(projectDir, current.$path);
        const found = await this.walkFs(fsPath, currentPath);
        out.push(...found);
      }
      for (const [key, val] of Object.entries(current)) {
        if (key.startsWith("$")) continue;
        if (typeof val !== "object" || val === null) continue;
        const child = val as RojoNode;
        const childPath = currentPath ? `${currentPath}.${key}` : key;
        await recurse(child, childPath);
      }
    };

    await recurse(node, prefix);
    return out;
  }

  private async walkFs(
    fsPath: string,
    instancePath: string,
  ): Promise<{ fullPath: string; file: string }[]> {
    const out: { fullPath: string; file: string }[] = [];

    let stat: import("fs").Stats;
    try {
      stat = await fs.stat(fsPath);
    } catch {
      return out;
    }

    if (stat.isFile()) {
      if (fsPath.endsWith(".lua") || fsPath.endsWith(".luau")) {
        out.push({ fullPath: instancePath, file: fsPath });
      }
      return out;
    }

    if (stat.isDirectory()) {
      const entries = await fs.readdir(fsPath);
      for (const e of entries) {
        if (e === "init.lua" || e === "init.luau") {
          out.push({ fullPath: instancePath, file: path.join(fsPath, e) });
          continue;
        }
        if (e === "init.server.lua" || e === "init.server.luau") {
          out.push({ fullPath: instancePath, file: path.join(fsPath, e) });
          continue;
        }
        if (e === "init.client.lua" || e === "init.client.luau") {
          out.push({ fullPath: instancePath, file: path.join(fsPath, e) });
          continue;
        }
        const base = e
          .replace(/\.server\.(lua|luau)$/, "")
          .replace(/\.client\.(lua|luau)$/, "")
          .replace(/\.(lua|luau)$/, "");
        const childPath = instancePath ? `${instancePath}.${base}` : base;
        const sub = await this.walkFs(path.join(fsPath, e), childPath);
        out.push(...sub);
      }
    }
    return out;
  }
}
