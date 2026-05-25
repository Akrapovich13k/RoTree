import * as vscode from "vscode";
import {
  HttpServer,
  ExportReader,
  ContextBuilder,
  RojoComparator,
  PatchManager,
  ExportPayload,
  BackupPayload,
} from "@rotree/core";
import { GameTreeProvider } from "./providers/GameTreeProvider";
import { ScriptsProvider } from "./providers/ScriptsProvider";
import { RemotesProvider } from "./providers/RemotesProvider";
import { GuiProvider } from "./providers/GuiProvider";
import { ServicesProvider } from "./providers/ServicesProvider";
import { RojoProvider } from "./providers/RojoProvider";
import { ContextProvider } from "./providers/ContextProvider";
import { registerCommands, Refreshable } from "./commands";

let statusItem: vscode.StatusBarItem;

export async function activate(ctx: vscode.ExtensionContext): Promise<void> {
  const folder = vscode.workspace.workspaceFolders?.[0];
  if (!folder) {
    vscode.window.showWarningMessage("RoTree: open a folder before using the extension.");
    return;
  }
  const root = folder.uri.fsPath;
  const exportFolderName = vscode.workspace
    .getConfiguration("rotree")
    .get<string>("exportFolder", ".rotree");

  const reader = new ExportReader({ workspaceRoot: root, exportFolderName });
  await reader.ensureFolder();
  const rojo = new RojoComparator(root, reader);
  const context = new ContextBuilder(reader, rojo);
  const patches = new PatchManager(reader);

  const gameTree = new GameTreeProvider(reader);
  const scripts = new ScriptsProvider(reader);
  const remotes = new RemotesProvider(reader);
  const gui = new GuiProvider(reader);
  const services = new ServicesProvider(reader);
  const rojoView = new RojoProvider(rojo);
  const contextView = new ContextProvider(reader);

  ctx.subscriptions.push(
    vscode.window.registerTreeDataProvider("rotree.gameTree", gameTree),
    vscode.window.registerTreeDataProvider("rotree.scripts", scripts),
    vscode.window.registerTreeDataProvider("rotree.remotes", remotes),
    vscode.window.registerTreeDataProvider("rotree.gui", gui),
    vscode.window.registerTreeDataProvider("rotree.services", services),
    vscode.window.registerTreeDataProvider("rotree.rojo", rojoView),
    vscode.window.registerTreeDataProvider("rotree.context", contextView),
  );

  const refreshers: Refreshable[] = [
    gameTree, scripts, remotes, gui, services, rojoView, contextView,
  ];

  statusItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  statusItem.text = "$(circle-slash) RoTree";
  statusItem.command = "rotree.startBridge";
  statusItem.show();
  ctx.subscriptions.push(statusItem);

  const server = new HttpServer({
    reader,
    patches,
    onExport: async (p: ExportPayload | BackupPayload) => {
      if (p.kind === "backup") {
        const backup = p as BackupPayload;
        await reader.writeBackup(backup);
        vscode.window.showInformationMessage(`RoTree: backup saved for patch ${backup.patchId}.`);
        return;
      }
      const payload = p as ExportPayload;
      await reader.writeExport(payload);
      for (const r of refreshers) r.refresh();
      vscode.window.showInformationMessage(
        `RoTree: received ${payload.kind} export of ${payload.placeName}.`,
      );
    },
    onOpenFolder: async () => {
      await vscode.commands.executeCommand("rotree.openFolder");
    },
    log: (msg, level) => {
      if (level === "error") console.error(`[RoTree] ${msg}`);
      else console.log(`[RoTree] ${msg}`);
    },
  });

  ctx.subscriptions.push({
    dispose: () => {
      void server.stop();
    },
  });

  registerCommands(ctx, {
    server,
    reader,
    context,
    rojo,
    patches,
    refreshers,
    onBridgeStateChanged: (online: boolean, port?: number) => {
      if (online) {
        statusItem.text = `$(plug) RoTree: ${port}`;
        statusItem.command = "rotree.stopBridge";
      } else {
        statusItem.text = "$(circle-slash) RoTree";
        statusItem.command = "rotree.startBridge";
      }
    },
  });

  const auto = vscode.workspace.getConfiguration("rotree").get<boolean>("autoStartBridge", true);
  if (auto) {
    await vscode.commands.executeCommand("rotree.startBridge");
  }
}

export function deactivate(): void {
  // Disposables registered via ctx.subscriptions handle cleanup.
}
