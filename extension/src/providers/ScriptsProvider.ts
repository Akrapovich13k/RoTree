import * as path from "path";
import * as fs from "fs/promises";
import * as vscode from "vscode";
import { ExportReader, ScriptEntry } from "@rotree/core";

class ScriptItem extends vscode.TreeItem {
  constructor(public readonly entry: ScriptEntry, sourceFile: string) {
    super(entry.name, vscode.TreeItemCollapsibleState.None);
    this.description = `${entry.className} · ${entry.lines} lines${entry.redacted ? " · redacted" : ""}`;
    this.tooltip = entry.fullPath;
    this.iconPath = new vscode.ThemeIcon("file-code");
    if (!entry.redacted) {
      this.command = {
        command: "vscode.open",
        title: "Open script",
        arguments: [vscode.Uri.file(sourceFile)],
      };
    }
  }
}

export class ScriptsProvider implements vscode.TreeDataProvider<ScriptItem> {
  private readonly emitter = new vscode.EventEmitter<ScriptItem | undefined>();
  readonly onDidChangeTreeData = this.emitter.event;

  constructor(private readonly reader: ExportReader) {}

  refresh(): void {
    this.emitter.fire(undefined);
  }

  getTreeItem(el: ScriptItem): vscode.TreeItem {
    return el;
  }

  async getChildren(): Promise<ScriptItem[]> {
    const scripts = (await this.reader.scripts()) ?? [];
    const sourcesDir = path.join(this.reader.folder, "_sources");
    await fs.mkdir(sourcesDir, { recursive: true });

    const items: ScriptItem[] = [];
    for (const s of scripts) {
      const ext = s.className === "LocalScript" ? ".client.luau"
        : s.className === "Script" ? ".server.luau"
        : ".luau";
      const file = path.join(sourcesDir, s.fullPath.replace(/[^a-z0-9._-]+/gi, "_") + ext);
      if (s.source && !s.redacted) {
        try { await fs.writeFile(file, s.source, "utf8"); } catch { /* ignore */ }
      }
      items.push(new ScriptItem(s, file));
    }
    return items;
  }
}
