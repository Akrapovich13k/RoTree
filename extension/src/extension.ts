import * as vscode from "vscode";
import { HttpServer } from "./server/HttpServer";
import { ExportReader } from "./services/ExportReader";
import { ContextBuilder } from "./services/ContextBuilder";
import { RojoComparator } from "./services/RojoComparator";
import { PatchManager } from "./services/PatchManager";
import { GameTreeProvider } from "./providers/GameTreeProvider";
import { ScriptsProvider } from "./providers/ScriptsProvider";
import { RemotesProvider } from "./providers/RemotesProvider";
import { GuiProvider } from "./providers/GuiProvider";
import { ServicesProvider } from "./providers/ServicesProvider";
import { RojoProvider } from "./providers/RojoProvider";
import { ContextProvider } from "./providers/ContextProvider";
import { registerCommands, Refreshable } from "./commands";
import { ExportPayload, BackupPayload } from "./types";

export async function activate(ctx: vscode.ExtensionContext): Promise<void> {
  const folder = vscode.workspace.workspaceFolders?.[0];
  if (!folder) {
    vscode.window.showWarningMessage(
      "RoTree: open a folder before using the extension.",
    );
    return;
  }
  const root = folder.uri.fsPath;

  const reader = new ExportReader(root);
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

  const onExport = async (p: ExportPayload | BackupPayload) => {
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
  };

  const server = new HttpServer(reader, patches, onExport);
  ctx.subscriptions.push({ dispose: () => server.dispose() });

  registerCommands(ctx, {
    server, reader, context, rojo, patches, refreshers,
  });

  const auto = vscode.workspace.getConfiguration("rotree").get<boolean>("autoStartBridge", true);
  if (auto) {
    await vscode.commands.executeCommand("rotree.startBridge");
  }
}

export function deactivate(): void {
  // Disposables registered via ctx.subscriptions handle cleanup.
}
