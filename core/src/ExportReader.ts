import * as path from "path";
import * as fs from "fs/promises";
import {
  ExportPayload,
  BackupPayload,
  ScriptEntry,
  RemoteEntry,
  GuiEntry,
  TreeNode,
  LastExportInfo,
} from "./types";

export interface ExportReaderOptions {
  workspaceRoot: string;
  exportFolderName?: string;
}

export class ExportReader {
  private readonly workspaceRoot: string;
  private readonly exportFolderName: string;

  constructor(opts: ExportReaderOptions) {
    this.workspaceRoot = opts.workspaceRoot;
    this.exportFolderName = opts.exportFolderName ?? ".rotree";
  }

  get folder(): string {
    return path.join(this.workspaceRoot, this.exportFolderName);
  }

  async ensureFolder(): Promise<void> {
    await fs.mkdir(this.folder, { recursive: true });
    await fs.mkdir(path.join(this.folder, "patches"), { recursive: true });
    await fs.mkdir(path.join(this.folder, "backups"), { recursive: true });
  }

  async writeExport(p: ExportPayload): Promise<void> {
    await this.ensureFolder();

    if (p.tree && p.tree.length > 0) {
      await this.writeJson("game-tree.json", p.tree);
    }
    if (p.scripts && p.scripts.length > 0) {
      await this.writeJson("scripts-map.json", p.scripts);
    }
    if (p.remotes && p.remotes.length > 0) {
      await this.writeJson("remotes-map.json", p.remotes);
    }
    if (p.gui && p.gui.length > 0) {
      await this.writeJson("gui-map.json", p.gui);
    }
    if (p.parts && p.parts.length > 0) {
      await this.writeJson("parts-map.json", p.parts);
    }
    if (p.attributes && Object.keys(p.attributes).length > 0) {
      await this.writeJson("attributes-map.json", p.attributes);
    }
    if (p.tags && Object.keys(p.tags).length > 0) {
      await this.writeJson("collection-tags.json", p.tags);
    }
    if (p.properties && Object.keys(p.properties).length > 0) {
      await this.writeJson("instance-properties.json", p.properties);
    }

    if (p.tree && p.tree.length > 0) {
      const services: Record<string, { children: number; classes: Record<string, number> }> = {};
      for (const node of p.tree) {
        services[node.name] = this.countChildren(node);
      }
      await this.writeJson("services-map.json", services);
    }

    const info: LastExportInfo = {
      placeName: p.placeName,
      placeId: p.placeId,
      pluginVersion: p.pluginVersion,
      exportedAt: p.exportedAt,
      kind: p.kind,
      stats: p.stats,
    };
    await this.writeJson("last-export-info.json", info);

    if (p.aiContext) {
      await fs.writeFile(
        path.join(this.folder, "AI_CONTEXT.md"),
        p.aiContext,
        "utf8",
      );
    }
    await fs.writeFile(
      path.join(this.folder, "summary.md"),
      this.buildSummary(p),
      "utf8",
    );
  }

  async writeBackup(p: BackupPayload): Promise<void> {
    await this.ensureFolder();
    const safeId = p.patchId.replace(/[^a-z0-9._-]+/gi, "_");
    const stamp = p.exportedAt.replace(/[:]/g, "-");
    const file = path.join(this.folder, "backups", `${stamp}-pre-${safeId}.json`);
    await fs.writeFile(file, JSON.stringify(p, null, 2), "utf8");
  }

  async readIgnoreFile(): Promise<string> {
    const candidates = [".rotreeignore", ".rotree/ignore"];
    for (const c of candidates) {
      const full = path.join(this.workspaceRoot, c);
      try {
        return await fs.readFile(full, "utf8");
      } catch {
        // continue
      }
    }
    return "";
  }

  async readJson<T>(name: string): Promise<T | null> {
    try {
      const buf = await fs.readFile(path.join(this.folder, name), "utf8");
      return JSON.parse(buf) as T;
    } catch {
      return null;
    }
  }

  async lastExportInfo(): Promise<LastExportInfo | null> {
    return this.readJson<LastExportInfo>("last-export-info.json");
  }

  async tree(): Promise<TreeNode[] | null> {
    return this.readJson<TreeNode[]>("game-tree.json");
  }

  async scripts(): Promise<ScriptEntry[] | null> {
    return this.readJson<ScriptEntry[]>("scripts-map.json");
  }

  async remotes(): Promise<RemoteEntry[] | null> {
    return this.readJson<RemoteEntry[]>("remotes-map.json");
  }

  async gui(): Promise<GuiEntry[] | null> {
    return this.readJson<GuiEntry[]>("gui-map.json");
  }

  private async writeJson(name: string, data: unknown): Promise<void> {
    const full = path.join(this.folder, name);
    await fs.writeFile(full, JSON.stringify(data, null, 2), "utf8");
  }

  private countChildren(node: TreeNode): {
    children: number;
    classes: Record<string, number>;
  } {
    const classes: Record<string, number> = {};
    let total = 0;
    const walk = (n: TreeNode) => {
      total++;
      classes[n.className] = (classes[n.className] ?? 0) + 1;
      for (const c of n.children ?? []) walk(c);
    };
    walk(node);
    return { children: total, classes };
  }

  private buildSummary(p: ExportPayload): string {
    const lines: string[] = [];
    lines.push(`# RoTree export summary`, "");
    lines.push(`- Place: **${p.placeName}** (id ${p.placeId})`);
    lines.push(`- Exported: ${p.exportedAt}`);
    lines.push(`- Plugin version: ${p.pluginVersion}`);
    lines.push(`- Kind: ${p.kind}`);
    if (p.safeMode) lines.push(`- Safe mode: **on**`);
    lines.push("");
    lines.push(`## Stats`);
    lines.push("");
    for (const [k, v] of Object.entries(p.stats)) {
      lines.push(`- ${k}: **${v}**`);
    }
    return lines.join("\n");
  }
}
