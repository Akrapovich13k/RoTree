import * as http from "http";
import * as path from "path";
import * as fs from "fs/promises";
import {
  ExportPayload,
  BackupPayload,
  Patch,
  ApplyResult,
  LogEntry,
  LogLevel,
  LogPayload,
  OutputQuery,
} from "./types";
import { ExportReader } from "./ExportReader";
import { PatchManager } from "./PatchManager";

export const ROTREE_VERSION = "0.2.1";
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

interface QueuedPatch {
  patch: Patch;
  enqueuedAt: number;
  resolver: (result: ApplyResult) => void;
  rejecter: (err: Error) => void;
  resolved: boolean;
}

const MAX_LOG_RING = 10000;
const MAX_LOG_FILE_BYTES = 5 * 1024 * 1024; // 5 MB rotation threshold

export class HttpServer {
  private server?: http.Server;
  private readonly log: LogHandler;
  private currentPort?: number;
  private readonly autoApplyQueue: QueuedPatch[] = [];
  private readonly autoApplyPending = new Map<string, QueuedPatch>();
  private autoApplyOnlineAt = 0;

  private readonly logRing: LogEntry[] = [];
  private logFileWriting = false;

  constructor(private readonly opts: HttpServerOptions) {
    this.log = opts.log ?? (() => {});
  }

  getOutput(query: OutputQuery = {}): LogEntry[] {
    let out: LogEntry[] = this.logRing;
    if (query.level) out = out.filter((e) => e.level === query.level);
    if (query.filter) {
      const f = query.filter.toLowerCase();
      out = out.filter((e) => e.text.toLowerCase().includes(f));
    }
    if (query.sinceElapsed !== undefined) {
      const min = query.sinceElapsed;
      out = out.filter((e) => e.elapsed >= min);
    }
    const limit = query.limit ?? 200;
    if (out.length > limit) out = out.slice(-limit);
    return out;
  }

  clearOutput(): void {
    this.logRing.length = 0;
  }

  private async appendLogEntries(entries: LogEntry[]): Promise<void> {
    for (const e of entries) {
      this.logRing.push(e);
      if (this.logRing.length > MAX_LOG_RING) this.logRing.shift();
    }
    if (this.logFileWriting) return; // skip duplicate concurrent writes
    this.logFileWriting = true;
    try {
      const file = path.join(this.opts.reader.folder, "output.jsonl");
      await this.opts.reader.ensureFolder();
      try {
        const stat = await fs.stat(file);
        if (stat.size > MAX_LOG_FILE_BYTES) {
          await fs.rename(file, file + ".prev").catch(() => {});
        }
      } catch {
        // file may not exist yet
      }
      const lines = entries.map((e) => JSON.stringify(e)).join("\n") + "\n";
      await fs.appendFile(file, lines, "utf8");
    } catch (err) {
      this.log(`log persist failed: ${(err as Error).message}`, "warn");
    } finally {
      this.logFileWriting = false;
    }
  }

  get listening(): boolean {
    return this.server !== undefined;
  }

  get port(): number | undefined {
    return this.currentPort;
  }

  get autoApplyOnline(): boolean {
    // Plugin considered online if it polled within the last 6 seconds.
    return Date.now() - this.autoApplyOnlineAt < 6000;
  }

  queueAutoApply(patch: Patch, timeoutMs: number = 12000): Promise<ApplyResult> {
    return new Promise<ApplyResult>((resolve, reject) => {
      const entry: QueuedPatch = {
        patch,
        enqueuedAt: Date.now(),
        resolver: resolve,
        rejecter: reject,
        resolved: false,
      };
      this.autoApplyQueue.push(entry);
      this.autoApplyPending.set(patch.id, entry);
      setTimeout(() => {
        if (entry.resolved) return;
        entry.resolved = true;
        this.autoApplyPending.delete(patch.id);
        const i = this.autoApplyQueue.indexOf(entry);
        if (i >= 0) this.autoApplyQueue.splice(i, 1);
        reject(new Error("auto-apply timed out — plugin did not pick up the patch in time"));
      }, timeoutMs);
    });
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

      if (method === "GET" && url === "/rotree/auto-apply/next") {
        this.autoApplyOnlineAt = Date.now();
        const entry = this.autoApplyQueue.shift();
        if (!entry) {
          this.send(res, 200, { patch: null });
          return;
        }
        this.send(res, 200, { patch: entry.patch });
        return;
      }

      if (method === "POST" && url === "/rotree/auto-apply/result") {
        this.autoApplyOnlineAt = Date.now();
        const body = await this.readBody(req);
        const parsed = JSON.parse(body) as ApplyResult;
        const entry = this.autoApplyPending.get(parsed.id);
        if (entry && !entry.resolved) {
          entry.resolved = true;
          this.autoApplyPending.delete(parsed.id);
          entry.resolver(parsed);
        }
        this.send(res, 200, { ok: true });
        return;
      }

      if (method === "POST" && url === "/rotree/log") {
        const body = await this.readBody(req);
        const parsed = JSON.parse(body) as LogPayload;
        if (parsed && Array.isArray(parsed.entries) && parsed.entries.length > 0) {
          await this.appendLogEntries(parsed.entries);
        }
        this.send(res, 200, { ok: true, stored: parsed?.entries?.length ?? 0 });
        return;
      }

      if (method === "GET" && url.startsWith("/rotree/log/recent")) {
        const q = new URL(url, "http://localhost").searchParams;
        const limit = q.get("limit") ? parseInt(q.get("limit") as string, 10) : undefined;
        const level = (q.get("level") as LogLevel) || undefined;
        const filter = q.get("filter") || undefined;
        const sinceElapsed = q.get("sinceElapsed") ? parseFloat(q.get("sinceElapsed") as string) : undefined;
        const entries = this.getOutput({ limit, level, filter, sinceElapsed });
        this.send(res, 200, { entries });
        return;
      }

      if (method === "POST" && url === "/rotree/log/clear") {
        this.clearOutput();
        this.send(res, 200, { ok: true });
        return;
      }

      if (method === "GET" && url === "/rotree/auto-apply/status") {
        this.send(res, 200, {
          online: this.autoApplyOnline,
          queued: this.autoApplyQueue.length,
          pending: this.autoApplyPending.size,
        });
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
