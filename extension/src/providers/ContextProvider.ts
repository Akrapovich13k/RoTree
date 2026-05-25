import * as path from "path";
import * as vscode from "vscode";
import { ExportReader } from "@rotree/core";

class ContextItem extends vscode.TreeItem {
  constructor(label: string, file: string, icon: string) {
    super(label, vscode.TreeItemCollapsibleState.None);
    this.iconPath = new vscode.ThemeIcon(icon);
    this.command = {
      command: "vscode.open",
      title: "Open",
      arguments: [vscode.Uri.file(file)],
    };
  }
}

export class ContextProvider implements vscode.TreeDataProvider<ContextItem> {
  private readonly emitter = new vscode.EventEmitter<ContextItem | undefined>();
  readonly onDidChangeTreeData = this.emitter.event;

  constructor(private readonly reader: ExportReader) {}

  refresh(): void {
    this.emitter.fire(undefined);
  }

  getTreeItem(el: ContextItem): vscode.TreeItem {
    return el;
  }

  getChildren(): ContextItem[] {
    const f = this.reader.folder;
    return [
      new ContextItem("AI_CONTEXT.md", path.join(f, "AI_CONTEXT.md"), "book"),
      new ContextItem("summary.md", path.join(f, "summary.md"), "preview"),
      new ContextItem("game-tree.json", path.join(f, "game-tree.json"), "json"),
      new ContextItem("scripts-map.json", path.join(f, "scripts-map.json"), "json"),
      new ContextItem("remotes-map.json", path.join(f, "remotes-map.json"), "json"),
      new ContextItem("gui-map.json", path.join(f, "gui-map.json"), "json"),
      new ContextItem("services-map.json", path.join(f, "services-map.json"), "json"),
      new ContextItem("attributes-map.json", path.join(f, "attributes-map.json"), "json"),
      new ContextItem("collection-tags.json", path.join(f, "collection-tags.json"), "json"),
      new ContextItem("last-export-info.json", path.join(f, "last-export-info.json"), "json"),
    ];
  }
}
