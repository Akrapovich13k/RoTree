import * as vscode from "vscode";
import { ExportReader, GuiEntry } from "@rotree/core";

class GuiItem extends vscode.TreeItem {
  constructor(public readonly entry: GuiEntry) {
    super(entry.name, vscode.TreeItemCollapsibleState.None);
    this.description = entry.className;
    this.tooltip = entry.fullPath;
    this.iconPath = new vscode.ThemeIcon("symbol-color");
  }
}

export class GuiProvider implements vscode.TreeDataProvider<GuiItem> {
  private readonly emitter = new vscode.EventEmitter<GuiItem | undefined>();
  readonly onDidChangeTreeData = this.emitter.event;

  constructor(private readonly reader: ExportReader) {}

  refresh(): void {
    this.emitter.fire(undefined);
  }

  getTreeItem(el: GuiItem): vscode.TreeItem {
    return el;
  }

  async getChildren(): Promise<GuiItem[]> {
    const gui = (await this.reader.gui()) ?? [];
    return gui.map((g) => new GuiItem(g));
  }
}
