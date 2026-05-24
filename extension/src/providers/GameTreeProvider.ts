import * as vscode from "vscode";
import { ExportReader } from "../services/ExportReader";
import { TreeNode } from "../types";

class GameTreeItem extends vscode.TreeItem {
  constructor(public readonly node: TreeNode) {
    super(
      node.name,
      (node.children?.length ?? 0) > 0
        ? vscode.TreeItemCollapsibleState.Collapsed
        : vscode.TreeItemCollapsibleState.None,
    );
    this.description = node.className;
    this.tooltip = node.fullPath;
    this.iconPath = GameTreeItem.iconFor(node);
    this.contextValue = node.isScript ? "script" : node.className;
  }

  private static iconFor(n: TreeNode): vscode.ThemeIcon {
    if (n.isScript) return new vscode.ThemeIcon("file-code");
    if (n.isGui) return new vscode.ThemeIcon("symbol-color");
    if (n.isRemote) return new vscode.ThemeIcon("plug");
    if (n.isPart) return new vscode.ThemeIcon("symbol-array");
    if (n.isModel) return new vscode.ThemeIcon("symbol-namespace");
    return new vscode.ThemeIcon("symbol-folder");
  }
}

export class GameTreeProvider implements vscode.TreeDataProvider<GameTreeItem> {
  private readonly emitter = new vscode.EventEmitter<GameTreeItem | undefined>();
  readonly onDidChangeTreeData = this.emitter.event;

  constructor(private readonly reader: ExportReader) {}

  refresh(): void {
    this.emitter.fire(undefined);
  }

  getTreeItem(el: GameTreeItem): vscode.TreeItem {
    return el;
  }

  async getChildren(el?: GameTreeItem): Promise<GameTreeItem[]> {
    if (!el) {
      const tree = await this.reader.tree();
      return (tree ?? []).map((n) => new GameTreeItem(n));
    }
    return (el.node.children ?? []).map((n) => new GameTreeItem(n));
  }
}
