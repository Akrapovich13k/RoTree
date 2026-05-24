import * as http from "http";
import { ExportPayload, BackupPayload } from "./types";
import { ExportReader } from "./ExportReader";
import { PatchManager } from "./PatchManager";

export const ROTREE_VERSION = "0.1.0";
export const ROTREE_MAJOR = "0";

export type ExportHandler = (p: ExportPayload | BackupPayload) => Promise<void>;
export type OpenFolderHandler = () => Promise<void>;
export type LogHandler = (msg: string, level: "info" | "warn" | "error") => void;

export interface HttpServerOptions {
  reader: ExportReader;
  patches: PatchManager;
  onExport: ExportHandler;
  onOpenFolder?: OpenFolderHandler;
  log?: LogHandler;
}

export class HttpServer {
  private server?: http.Server;
  private readonly log: LogHandler;
  private currentPort?: number;

  constructor(private readonly opts: HttpServerOptions) {
    this.log = opts.log ?? (() => {});
  }

  get listening(): boolean {
    return this.server !== undefined;
  }

  get port(): number | undefined {
    return this.currentPort;
  }

  async start(port: number): Promise<void> {
    if (this.server) return;
    this.server = http.createServer((req, res) => this.handle(req, res));

    await new Promise<void>((resolve, reject) => {
      this.server!.once("error", reject);
      this.server!.listen(port, "127.0.0.1", () => resolve());
    });
    this.currentPort = port;
    this.log(`bridge listening on http://localhost:${port}`, "info");
  }

  async stop(): Promise<void> {
    if (!this.server) return;
    await new Promise<void>((resolve) => this.server!.close(() => resolve()));
    this.server = undefined;
    this.currentPort = undefined;
    this.log("bridge stopped", "info");
  }

  private isLoopback(req: http.IncomingMessage): boolean {
    const addr = req.socket.remoteAddress ?? "";
    return addr === "127.0.0.1" || addr === "::1" || addr === "::ffff:127.0.0.1";
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

  private async handle(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
    if (!this.isLoopback(req)) {
      this.send(res, 403, { error: "loopback only" });
      return;
    }
    if (!this.checkVersion(req)) {
      this.send(res, 426, {
        error: `RoTree version mismatch. Expected major ${ROTREE_MAJOR}.x`,
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
        const text = await this.opts.reader.readIgnoreFile();
        this.send(res, 200, { text });
        return;
      }

      if (method === "GET" && url === "/rotree/patches") {
        const list = await this.opts.patches.list();
        this.send(res, 200, list);
        return;
      }

      if (method === "GET" && url.startsWith("/rotree/patches/")) {
        const id = decodeURIComponent(url.slice("/rotree/patches/".length));
        const p = await this.opts.patches.read(id);
        if (!p) {
          this.send(res, 404, { error: "not found" });
          return;
        }
        this.send(res, 200, p);
        return;
      }

      if (method === "POST" && url === "/rotree/export") {
        const body = await this.readBody(req);
        const parsed = JSON.parse(body) as
          | ExportPayload
          | BackupPayload
          | { kind: "openFolder" };
        if (parsed.kind === "openFolder") {
          if (this.opts.onOpenFolder) await this.opts.onOpenFolder();
          this.send(res, 200, { ok: true });
          return;
        }
        await this.opts.onExport(parsed as ExportPayload | BackupPayload);
        this.send(res, 200, { ok: true });
        return;
      }

      this.send(res, 404, { error: "unknown route" });
    } catch (err) {
      this.log(`request failed: ${(err as Error).message}`, "error");
      this.send(res, 500, { error: (err as Error).message });
    }
  }
}
