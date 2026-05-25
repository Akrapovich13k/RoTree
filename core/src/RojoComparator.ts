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

export class RojoComparator {
  constructor(
    private readonly workspaceRoot: string,
    private readonly reader: ExportReader,
  ) {}

  async detect(): Promise<boolean> {
    try {
      await fs.access(path.join(this.workspaceRoot, "default.project.json"));
      return true;
    } catch {
      return false;
    }
  }

  async loadProject(): Promise<RojoProject | null> {
    try {
      const buf = await fs.readFile(
        path.join(this.workspaceRoot, "default.project.json"),
        "utf8",
      );
      return JSON.parse(buf) as RojoProject;
    } catch {
      return null;
    }
  }

  async compare(): Promise<RojoDiff | null> {
    const project = await this.loadProject();
    if (!project || !project.tree) return null;

    const rojoScripts = await this.collectRojoScripts(project.tree, "");
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

  private async collectRojoScripts(
    node: RojoNode,
    prefix: string,
  ): Promise<{ fullPath: string; file: string }[]> {
    const out: { fullPath: string; file: string }[] = [];

    const recurse = async (current: RojoNode, currentPath: string) => {
      if (current.$path) {
        const fsPath = path.resolve(this.workspaceRoot, current.$path);
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
