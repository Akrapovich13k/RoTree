import * as http from "http";
import * as vscode from "vscode";
import { ExportPayload, BackupPayload, Patch } from "../types";
import { ExportReader } from "../services/ExportReader";
import { PatchManager } from "../services/PatchManager";

export const ROTREE_VERSION = "0.1.0";
export const ROTREE_MAJOR = "0";

type ExportHandler = (p: ExportPayload | BackupPayload) => Promise<void>;

export class HttpServer {
  private server?: http.Server;
  private statusItem: vscode.StatusBarItem;

  constructor(
    private readonly reader: ExportReader,
    private readonly patches: PatchManager,
    private readonly onExport: ExportHandler,
  ) {
    this.statusItem = vscode.window.createStatusBarItem(
      vscode.StatusBarAlignment.Right,
      100,
    );
    this.statusItem.text = "$(circle-slash) RoTree";
    this.statusItem.command = "rotree.startBridge";
    this.statusItem.show();
  }

  async start(port: number): Promise<void> {
    if (this.server) return;
    this.server = http.createServer((req, res) => this.handle(req, res));

    await new Promise<void>((resolve, reject) => {
      this.server!.once("error", reject);
      this.server!.listen(port, "127.0.0.1", () => resolve());
    });

    this.statusItem.text = `$(plug) RoTree: ${port}`;
    this.statusItem.command = "rotree.stopBridge";
  }

  async stop(): Promise<void> {
    if (!this.server) return;
    await new Promise<void>((resolve) => this.server!.close(() => resolve()));
    this.server = undefined;
    this.statusItem.text = "$(circle-slash) RoTree";
    this.statusItem.command = "rotree.startBridge";
  }

  dispose(): void {
    this.statusItem.dispose();
    void this.stop();
  }

  private isLoopback(req: http.IncomingMessage): boolean {
    const addr = req.socket.remoteAddress ?? "";
    return (
      addr === "127.0.0.1" ||
      addr === "::1" ||
      addr === "::ffff:127.0.0.1"
    );
  }

  private checkVersion(req: http.IncomingMessage): boolean {
    const v = req.headers["x-rotree-version"];
    if (typeof v !== "string") return false;
    return v.split(".")[0] === ROTREE_MAJOR;
  }

  private send(res: http.ServerResponse, status: number, body: unknown): void {
    const json = JSON.stringify(body);
    res.writeHead(status, {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(json),
    });
    res.end(json);
  }

  private async readBody(req: http.IncomingMessage): Promise<string> {
    return new Promise((resolve, reject) => {
      const chunks: Buffer[] = [];
      req.on("data", (c: Buffer) => chunks.push(c));
      req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
      req.on("error", reject);
    });
  }

  private async handle(
    req: http.IncomingMessage,
    res: http.ServerResponse,
  ): Promise<void> {
    if (!this.isLoopback(req)) {
      this.send(res, 403, { error: "loopback only" });
      return;
    }
    if (!this.checkVersion(req)) {
      this.send(res, 426, {
        error: `RoTree version mismatch. Extension expects major ${ROTREE_MAJOR}.x`,
      });
      return;
    }

    const url = req.url ?? "/";
    const method = req.method ?? "GET";

    try {
      if (method === "GET" && url === "/rotree/ping") {
        this.send(res, 200, { ok: true, version: ROTREE_VERSION });
        return;
      }

      if (method === "GET" && url === "/rotree/ignore") {
        const text = await this.reader.readIgnoreFile();
        this.send(res, 200, { text });
        return;
      }

      if (method === "GET" && url === "/rotree/patches") {
        const list = await this.patches.list();
        this.send(res, 200, list);
        return;
      }

      if (method === "GET" && url.startsWith("/rotree/patches/")) {
        const id = decodeURIComponent(url.slice("/rotree/patches/".length));
        const p = await this.patches.read(id);
        if (!p) {
          this.send(res, 404, { error: "not found" });
          return;
        }
        this.send(res, 200, p);
        return;
      }

      if (method === "POST" && url === "/rotree/export") {
        const body = await this.readBody(req);
        const parsed = JSON.parse(body) as ExportPayload | BackupPayload | { kind: "openFolder" };
        if (parsed.kind === "openFolder") {
          await vscode.commands.executeCommand("rotree.openFolder");
          this.send(res, 200, { ok: true });
          return;
        }
        await this.onExport(parsed as ExportPayload | BackupPayload);
        this.send(res, 200, { ok: true });
        return;
      }

      this.send(res, 404, { error: "unknown route" });
    } catch (err) {
      this.send(res, 500, { error: (err as Error).message });
    }
  }
}
