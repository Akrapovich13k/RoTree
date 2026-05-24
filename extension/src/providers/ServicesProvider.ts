import * as vscode from "vscode";
import { ExportReader } from "../services/ExportReader";

interface ServiceSummary {
  children: number;
  classes: Record<string, number>;
}

class ServiceItem extends vscode.TreeItem {
  constructor(public readonly name: string, public readonly summary: ServiceSummary) {
    super(name, vscode.TreeItemCollapsibleState.Collapsed);
    this.description = `${summary.children} instances`;
    this.iconPath = new vscode.ThemeIcon("symbol-folder");
  }
}

class ClassItem extends vscode.TreeItem {
  constructor(public readonly className: string, public readonly count: number) {
    super(className, vscode.TreeItemCollapsibleState.None);
    this.description = String(count);
    this.iconPath = new vscode.ThemeIcon("symbol-class");
  }
}

type Node = ServiceItem | ClassItem;

export class ServicesProvider implements vscode.TreeDataProvider<Node> {
  private readonly emitter = new vscode.EventEmitter<Node | undefined>();
  readonly onDidChangeTreeData = this.emitter.event;

  constructor(private readonly reader: ExportReader) {}

  refresh(): void {
    this.emitter.fire(undefined);
  }

  getTreeItem(el: Node): vscode.TreeItem {
    return el;
  }

  async getChildren(el?: Node): Promise<Node[]> {
    const map = await this.reader.readJson<Record<string, ServiceSummary>>("services-map.json");
    if (!map) return [];
    if (!el) {
      return Object.entries(map).map(([name, summary]) => new ServiceItem(name, summary));
    }
    if (el instanceof ServiceItem) {
      return Object.entries(el.summary.classes)
        .sort((a, b) => b[1] - a[1])
        .map(([cls, count]) => new ClassItem(cls, count));
    }
    return [];
  }
}
