import * as path from "path";
import * as vscode from "vscode";
import { HttpServer } from "../server/HttpServer";
import { ExportReader } from "../services/ExportReader";
import { ContextBuilder } from "../services/ContextBuilder";
import { RojoComparator } from "../services/RojoComparator";
import { PatchManager } from "../services/PatchManager";

export interface Refreshable {
  refresh(): void;
}

export interface CommandDeps {
  server: HttpServer;
  reader: ExportReader;
  context: ContextBuilder;
  rojo: RojoComparator;
  patches: PatchManager;
  refreshers: Refreshable[];
}

function refreshAll(deps: CommandDeps): void {
  for (const r of deps.refreshers) r.refresh();
}

function openFile(folder: string, name: string): Thenable<void> {
  return vscode.commands.executeCommand(
    "vscode.open",
    vscode.Uri.file(path.join(folder, name)),
  );
}

export function registerCommands(
  ctx: vscode.ExtensionContext,
  deps: CommandDeps,
): void {
  const register = (id: string, fn: (...args: unknown[]) => unknown) => {
    ctx.subscriptions.push(vscode.commands.registerCommand(id, fn));
  };

  register("rotree.startBridge", async () => {
    const port = vscode.workspace.getConfiguration("rotree").get<number>("port", 34872);
    try {
      await deps.server.start(port);
      vscode.window.showInformationMessage(`RoTree bridge listening on ${port}.`);
    } catch (err) {
      vscode.window.showErrorMessage(
        `RoTree: failed to start bridge on ${port}: ${(err as Error).message}`,
      );
    }
  });

  register("rotree.stopBridge", async () => {
    await deps.server.stop();
    vscode.window.showInformationMessage("RoTree bridge stopped.");
  });

  register("rotree.refresh", () => {
    refreshAll(deps);
    vscode.window.showInformationMessage("RoTree views refreshed.");
  });

  register("rotree.openGameTree",   () => openFile(deps.reader.folder, "game-tree.json"));
  register("rotree.showScriptMap",  () => openFile(deps.reader.folder, "scripts-map.json"));
  register("rotree.showRemotesMap", () => openFile(deps.reader.folder, "remotes-map.json"));
  register("rotree.showGuiMap",     () => openFile(deps.reader.folder, "gui-map.json"));
  register("rotree.openSummary",    () => openFile(deps.reader.folder, "summary.md"));

  register("rotree.createContext", async () => {
    const out = await deps.context.writeContextFile();
    await vscode.commands.executeCommand("vscode.open", vscode.Uri.file(out));
  });

  register("rotree.compareRojo", async () => {
    const detected = await deps.rojo.detect();
    if (!detected) {
      vscode.window.showWarningMessage("RoTree: no default.project.json found.");
      return;
    }
    const diff = await deps.rojo.compare();
    if (!diff) {
      vscode.window.showErrorMessage("RoTree: could not parse Rojo project.");
      return;
    }
    const lines: string[] = [];
    lines.push("# Rojo ↔ Studio diff", "");
    lines.push(`## Only in Studio (${diff.onlyInStudio.length})`, "");
    for (const p of diff.onlyInStudio) lines.push(`- ${p}`);
    lines.push("", `## Only in Rojo (${diff.onlyInRojo.length})`, "");
    for (const p of diff.onlyInRojo) lines.push(`- ${p}`);
    lines.push("", `## Different source (${diff.differentSource.length})`, "");
    for (const d of diff.differentSource) lines.push(`- ${d.path} ⇄ ${d.rojoFile}`);
    const doc = await vscode.workspace.openTextDocument({
      language: "markdown",
      content: lines.join("\n"),
    });
    await vscode.window.showTextDocument(doc);
  });

  register("rotree.openFolder", async () => {
    await deps.reader.ensureFolder();
    const uri = vscode.Uri.file(deps.reader.folder);
    await vscode.commands.executeCommand("revealFileInOS", uri);
  });

  register("rotree.previewPatch", async () => {
    const list = await deps.patches.list();
    if (list.length === 0) {
      vscode.window.showInformationMessage("RoTree: no patches in .rotree/patches/");
      return;
    }
    const pick = await vscode.window.showQuickPick(
      list.map((p) => ({ label: p.title, description: p.id })),
      { placeHolder: "Pick a patch to preview" },
    );
    if (!pick) return;
    const file = path.join(deps.reader.folder, "patches", pick.description + ".json");
    await vscode.commands.executeCommand("vscode.open", vscode.Uri.file(file));
  });
}
