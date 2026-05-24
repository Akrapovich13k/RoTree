import * as vscode from "vscode";
import { ExportReader } from "../services/ExportReader";
import { RemoteEntry } from "../types";

class RemoteItem extends vscode.TreeItem {
  constructor(public readonly entry: RemoteEntry) {
    super(entry.name, vscode.TreeItemCollapsibleState.None);
    this.description = `${entry.className} · ${entry.parentService}`;
    this.tooltip = entry.fullPath;
    this.iconPath = new vscode.ThemeIcon("plug");
  }
}

export class RemotesProvider implements vscode.TreeDataProvider<RemoteItem> {
  private readonly emitter = new vscode.EventEmitter<RemoteItem | undefined>();
  readonly onDidChangeTreeData = this.emitter.event;

  constructor(private readonly reader: ExportReader) {}

  refresh(): void {
    this.emitter.fire(undefined);
  }

  getTreeItem(el: RemoteItem): vscode.TreeItem {
    return el;
  }

  async getChildren(): Promise<RemoteItem[]> {
    const remotes = (await this.reader.remotes()) ?? [];
    return remotes.map((r) => new RemoteItem(r));
  }
}
