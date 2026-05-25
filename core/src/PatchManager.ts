import * as path from "path";
import * as fs from "fs/promises";
import { ExportReader } from "./ExportReader";
import { Patch } from "./types";

export class PatchManager {
  constructor(private readonly reader: ExportReader) {}

  private get folder(): string {
    return path.join(this.reader.folder, "patches");
  }

  async list(): Promise<{ id: string; title: string }[]> {
    try {
      const entries = await fs.readdir(this.folder);
      const out: { id: string; title: string }[] = [];
      for (const e of entries) {
        if (!e.endsWith(".json")) continue;
        const id = e.slice(0, -".json".length);
        const patch = await this.read(id);
        if (patch) out.push({ id, title: patch.title ?? id });
      }
      return out;
    } catch {
      return [];
    }
  }

  async read(id: string): Promise<Patch | null> {
    const file = path.join(this.folder, this.safeName(id) + ".json");
    try {
      const buf = await fs.readFile(file, "utf8");
      return JSON.parse(buf) as Patch;
    } catch {
      return null;
    }
  }

  async write(patch: Patch): Promise<string> {
    await fs.mkdir(this.folder, { recursive: true });
    const file = path.join(this.folder, this.safeName(patch.id) + ".json");
    await fs.writeFile(file, JSON.stringify(patch, null, 2), "utf8");
    return file;
  }

  private safeName(id: string): string {
    return id.replace(/[^a-z0-9._-]+/gi, "_");
  }
}
