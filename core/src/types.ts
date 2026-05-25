// JSON shapes shared between the plugin (Luau) and TypeScript consumers.
// See docs/ARCHITECTURE.md.

export type ExportKind =
  | "full"
  | "selected"
  | "safe"
  | "scripts"
  | "remotes"
  | "gui"
  | "backup"
  | "openFolder";

export interface TreeNode {
  name: string;
  className: string;
  fullPath: string;
  isScript: boolean;
  isGui: boolean;
  isRemote: boolean;
  isPart: boolean;
  isModel: boolean;
  tags?: string[];
  children?: TreeNode[];
}

export interface ScriptEntry {
  name: string;
  className: "Script" | "LocalScript" | "ModuleScript";
  fullPath: string;
  source: string | null;
  lines: number;
  bytes: number;
  requires: string[];
  remotes: string[];
  services: string[];
  empty: boolean;
  redacted: boolean;
}

export interface GuiEntry {
  name: string;
  className: string;
  fullPath: string;
  size?: number[];
  position?: number[];
  anchorPoint?: number[];
  backgroundColor?: number[];
  backgroundTransparency?: number;
  text?: string;
  image?: string;
  visible?: boolean;
  zIndex?: number;
  children: string[];
}

export interface RemoteEntry {
  name: string;
  className: string;
  fullPath: string;
  parentService: string;
}

export interface PartEntry {
  name: string;
  className: string;
  fullPath: string;
  position?: number[];
  size?: number[];
  orientation?: number[];
  color?: number[];
  material?: string;
  anchored?: boolean;
  canCollide?: boolean;
  transparency?: number;
  shape?: string;
}

export interface ExportStats {
  instances: number;
  scripts: number;
  remotes: number;
  gui: number;
  parts: number;
  modules: number;
}

export interface ExportPayload {
  kind: ExportKind;
  placeName: string;
  placeId: number;
  gameId?: number;
  exportedAt: string;
  pluginVersion: string;
  safeMode?: boolean;
  tree: TreeNode[];
  scripts: ScriptEntry[];
  remotes: RemoteEntry[];
  gui: GuiEntry[];
  parts?: PartEntry[];
  attributes?: Record<string, Record<string, unknown>>;
  tags?: Record<string, string[]>;
  properties?: Record<string, Record<string, unknown>>;
  stats: ExportStats;
  claudeContext?: string;
}

export interface ApplyResult {
  id: string;
  success: boolean;
  applied: number;
  failed: number;
  error?: string;
}

export interface BackupSnapshot {
  path: string;
  className: string;
  name: string;
  source?: string;
  parent?: string;
}

export interface BackupPayload {
  kind: "backup";
  patchId: string;
  exportedAt: string;
  snapshots: BackupSnapshot[];
}

export interface PatchOp {
  op:
    | "setSource"
    | "setProperties"
    | "createFolder"
    | "createScript"
    | "rename"
    | "delete";
  path?: string;
  parentPath?: string;
  name?: string;
  className?: string;
  source?: string;
  props?: Record<string, unknown>;
}

export interface Patch {
  id: string;
  title: string;
  description?: string;
  critical?: boolean;
  ops: PatchOp[];
}

export interface LastExportInfo {
  placeName: string;
  placeId: number;
  pluginVersion: string;
  exportedAt: string;
  kind: string;
  stats: ExportStats;
}
