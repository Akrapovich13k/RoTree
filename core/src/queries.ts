// Pure, side-effect-free helpers shared by the MCP tools. Kept here (rather
// than inline in the MCP handlers) so they can be unit-tested without spinning
// up a server or touching the filesystem.

import { TreeNode } from "./types";

export type TagMap = Record<string, string[]>;
export type AttributeMap = Record<string, Record<string, unknown>>;

export interface TagSummary {
  /** Number of distinct tags. */
  tagCount: number;
  /** Total (tag, instance) associations across all tags. */
  totalTagged: number;
  /** { tag: number-of-instances } — compact, never dumps the paths. */
  tags: Record<string, number>;
}

/** Compact `{ tag: count }` view of a CollectionService tag map. */
export function summarizeTags(tags: TagMap): TagSummary {
  const out: Record<string, number> = {};
  let total = 0;
  for (const [tag, paths] of Object.entries(tags)) {
    const n = Array.isArray(paths) ? paths.length : 0;
    out[tag] = n;
    total += n;
  }
  return { tagCount: Object.keys(out).length, totalTagged: total, tags: out };
}

export interface TagPathsResult {
  query: string;
  /** Tag names that matched (exact match preferred, else prefix). */
  matchedTags: string[];
  /** Total paths across the matched tags (before pagination). */
  total: number;
  offset: number;
  limit: number;
  /** Number of paths actually returned in `paths`. */
  returned: boolean | number;
  /** { tag: paths[] } limited to the requested window. */
  paths: Record<string, string[]>;
}

/**
 * Resolve the instance paths for a tag. `query` matches a tag exactly, or — if
 * no exact match exists — every tag whose name starts with `query`. Results are
 * paginated with `offset`/`limit` over the flattened, grouped path list.
 */
export function selectTagPaths(
  tags: TagMap,
  query: string,
  offset = 0,
  limit = 200,
): TagPathsResult {
  const keys = Object.keys(tags);
  let matched: string[];
  if (keys.includes(query)) {
    matched = [query];
  } else {
    matched = keys.filter((k) => k.startsWith(query)).sort();
  }

  // Flatten in a stable order so pagination is deterministic across tags.
  const flat: { tag: string; path: string }[] = [];
  for (const tag of matched) {
    for (const p of tags[tag] ?? []) flat.push({ tag, path: p });
  }

  const start = Math.max(0, offset);
  const end = limit <= 0 ? flat.length : start + limit;
  const window = flat.slice(start, end);

  const paths: Record<string, string[]> = {};
  for (const { tag, path } of window) {
    (paths[tag] ??= []).push(path);
  }

  return {
    query,
    matchedTags: matched,
    total: flat.length,
    offset: start,
    limit,
    returned: window.length,
    paths,
  };
}

export interface AttributeFilter {
  /** Exact instance full path, or a sub-tree when used as a prefix. */
  instancePath?: string;
  /** Keep only attributes whose key name starts with this prefix. */
  keyPrefix?: string;
}

/**
 * Filter an attributes map.
 *
 * - `instancePath` keeps the instance itself plus its descendants
 *   (`Workspace.Base1` also matches `Workspace.Base1.Door`).
 * - `keyPrefix` keeps only attributes whose *key name* starts with the prefix,
 *   dropping instances left with no matching attributes.
 *
 * With neither filter the whole map is returned unchanged.
 */
export function filterAttributes(attrs: AttributeMap, filter: AttributeFilter = {}): AttributeMap {
  const { instancePath, keyPrefix } = filter;
  const out: AttributeMap = {};

  for (const [instPath, bag] of Object.entries(attrs)) {
    if (instancePath) {
      const exact = instPath === instancePath;
      const descendant = instPath.startsWith(instancePath + ".");
      if (!exact && !descendant) continue;
    }

    let kept = bag;
    if (keyPrefix) {
      kept = {};
      for (const [k, v] of Object.entries(bag)) {
        if (k.startsWith(keyPrefix)) kept[k] = v;
      }
      if (Object.keys(kept).length === 0) continue;
    }

    out[instPath] = kept;
  }

  return out;
}

export interface AgeDescription {
  /** Milliseconds between the export and `now`. */
  ms: number;
  /** Whole days elapsed. */
  days: number;
  /** Human phrase, e.g. "4 days ago" or "just now". */
  human: string;
}

/**
 * Describe how long ago an ISO timestamp was, relative to `now`. Returns null
 * for unparseable input.
 */
export function describeAge(iso: string, now: Date = new Date()): AgeDescription | null {
  const t = Date.parse(iso);
  if (Number.isNaN(t)) return null;
  const ms = Math.max(0, now.getTime() - t);
  const sec = Math.floor(ms / 1000);
  const min = Math.floor(sec / 60);
  const hours = Math.floor(min / 60);
  const days = Math.floor(hours / 24);

  let human: string;
  if (sec < 45) human = "just now";
  else if (min < 2) human = "a minute ago";
  else if (min < 60) human = `${min} minutes ago`;
  else if (hours < 2) human = "an hour ago";
  else if (hours < 24) human = `${hours} hours ago`;
  else if (days < 2) human = "yesterday";
  else human = `${days} days ago`;

  return { ms, days, human };
}

export interface TreeBound {
  /**
   * Maximum depth of `children` to keep. `0` drops every child and reports the
   * count via `_truncated`; `1` keeps the direct children only; and so on.
   */
  maxDepth: number;
  /**
   * Cap on the number of direct children kept at each node. When a node has
   * more, the extras are dropped and reported via `_childrenOmitted` /
   * `_childCount`. Undefined means no width cap.
   */
  maxChildren?: number;
}

/** A {@link TreeNode} plus the annotations {@link boundTreeNode} may attach. */
export type BoundedTreeNode = TreeNode & {
  /** Direct children dropped because `maxDepth` was reached. */
  _truncated?: number;
  /** Direct children dropped because the `maxChildren` cap was exceeded. */
  _childrenOmitted?: number;
  /** Total number of direct children before the `maxChildren` cap. */
  _childCount?: number;
};

/**
 * Return a depth- and width-bounded copy of a tree node so a single MCP
 * response can never serialize an entire subtree.
 *
 * - `rotree_get_tree` uses it with `maxDepth` only (no width cap) — output is
 *   identical to the previous inline truncation.
 * - `rotree_get_instance` uses it with a small `maxDepth` plus a `maxChildren`
 *   cap, so asking for one big Model/Folder stays cheap.
 *
 * Leaf nodes and nodes already within the limits are returned unchanged (a
 * shallow copy). The original node is never mutated.
 */
export function boundTreeNode(node: TreeNode, bound: TreeBound): BoundedTreeNode {
  const { maxDepth, maxChildren } = bound;
  const out: BoundedTreeNode = { ...node };
  const kids = node.children;

  if (!kids || kids.length === 0) return out;

  if (maxDepth <= 0) {
    out._truncated = kids.length;
    delete out.children;
    return out;
  }

  let kept = kids;
  if (typeof maxChildren === "number" && maxChildren >= 0 && kids.length > maxChildren) {
    kept = kids.slice(0, maxChildren);
    out._childrenOmitted = kids.length - maxChildren;
    out._childCount = kids.length;
  }
  out.children = kept.map((c) => boundTreeNode(c, { maxDepth: maxDepth - 1, maxChildren }));
  return out;
}
