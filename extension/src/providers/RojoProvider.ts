import * as vscode from "vscode";
import { RojoComparator, RojoDiff } from "../services/RojoComparator";

class RojoItem extends vscode.TreeItem {
  constructor(label: string, description: string, icon?: string) {
    super(label, vscode.TreeItemCollapsibleState.None);
    this.description = description;
    if (icon) this.iconPath = new vscode.ThemeIcon(icon);
  }
}

class RojoSection extends vscode.TreeItem {
  constructor(label: string, public readonly items: RojoItem[]) {
    super(label, vscode.TreeItemCollapsibleState.Collapsed);
    this.description = `${items.length}`;
    this.iconPath = new vscode.ThemeIcon("git-compare");
  }
}

type Node = RojoSection | RojoItem;

export class RojoProvider implements vscode.TreeDataProvider<Node> {
  private readonly emitter = new vscode.EventEmitter<Node | undefined>();
  readonly onDidChangeTreeData = this.emitter.event;

  constructor(private readonly rojo: RojoComparator) {}

  refresh(): void {
    this.emitter.fire(undefined);
  }

  getTreeItem(el: Node): vscode.TreeItem {
    return el;
  }

  async getChildren(el?: Node): Promise<Node[]> {
    if (el instanceof RojoSection) return el.items;
    if (!(await this.rojo.detect())) {
      return [new RojoItem("Rojo not detected", "no default.project.json", "info")];
    }
    const diff: RojoDiff | null = await this.rojo.compare();
    if (!diff) {
      return [new RojoItem("Rojo project unreadable", "", "warning")];
    }
    return [
      new RojoSection(
        "Only in Studio",
        diff.onlyInStudio.map((p) => new RojoItem(p, "missing from Rojo", "arrow-right")),
      ),
      new RojoSection(
        "Only in Rojo",
        diff.onlyInRojo.map((p) => new RojoItem(p, "missing from Studio", "arrow-left")),
      ),
      new RojoSection(
        "Different source",
        diff.differentSource.map((d) => new RojoItem(d.path, d.rojoFile, "git-pull-request")),
      ),
    ];
  }
}
