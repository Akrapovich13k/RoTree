"use strict";
// Unit tests for the pure MCP query helpers. Run with `node --test` after the
// core package is built (the test imports the compiled output in ../out).
const test = require("node:test");
const assert = require("node:assert/strict");

const {
  summarizeTags,
  selectTagPaths,
  filterAttributes,
  describeAge,
  boundTreeNode,
} = require("../out/queries.js");

// Minimal TreeNode factory — boundTreeNode only ever touches `children`.
function n(name, children) {
  return { name, className: "Folder", fullPath: name, isPart: false, children };
}

test("summarizeTags returns { tag: count } and totals", () => {
  const tags = {
    Climbable: ["Workspace.A", "Workspace.B"],
    Door: ["Workspace.Door1"],
    Empty: [],
  };
  const s = summarizeTags(tags);
  assert.deepEqual(s.tags, { Climbable: 2, Door: 1, Empty: 0 });
  assert.equal(s.tagCount, 3);
  assert.equal(s.totalTagged, 3);
});

test("selectTagPaths matches an exact tag", () => {
  const tags = { Door: ["a", "b", "c"], DoorFrame: ["x"] };
  const r = selectTagPaths(tags, "Door");
  assert.deepEqual(r.matchedTags, ["Door"]);
  assert.deepEqual(r.paths, { Door: ["a", "b", "c"] });
  assert.equal(r.total, 3);
});

test("selectTagPaths falls back to prefix when no exact match", () => {
  const tags = { Spawn_Red: ["a"], Spawn_Blue: ["b", "c"], Other: ["z"] };
  const r = selectTagPaths(tags, "Spawn_");
  assert.deepEqual(r.matchedTags.sort(), ["Spawn_Blue", "Spawn_Red"]);
  assert.equal(r.total, 3);
  assert.deepEqual(r.paths.Spawn_Red, ["a"]);
  assert.deepEqual(r.paths.Spawn_Blue, ["b", "c"]);
});

test("selectTagPaths paginates with offset/limit across grouped paths", () => {
  const tags = { T: ["p0", "p1", "p2", "p3", "p4"] };
  const page = selectTagPaths(tags, "T", 1, 2);
  assert.deepEqual(page.paths.T, ["p1", "p2"]);
  assert.equal(page.offset, 1);
  assert.equal(page.limit, 2);
  assert.equal(page.total, 5);
  assert.equal(page.returned, 2);
});

test("selectTagPaths returns no matches for an unknown tag", () => {
  const r = selectTagPaths({ A: ["x"] }, "Nope");
  assert.deepEqual(r.matchedTags, []);
  assert.deepEqual(r.paths, {});
});

test("filterAttributes by instancePath includes the instance and its subtree", () => {
  const attrs = {
    "Workspace.Base1": { OwnerId: 7 },
    "Workspace.Base1.Door": { Locked: true },
    "Workspace.Base10": { OwnerId: 9 }, // must NOT match Base1
    "Workspace.Other": { X: 1 },
  };
  const r = filterAttributes(attrs, { instancePath: "Workspace.Base1" });
  assert.deepEqual(Object.keys(r).sort(), ["Workspace.Base1", "Workspace.Base1.Door"]);
});

test("filterAttributes by keyPrefix drops instances with no matching key", () => {
  const attrs = {
    "Workspace.A": { OwnerId: 1, Level: 2 },
    "Workspace.B": { Level: 3 },
  };
  const r = filterAttributes(attrs, { keyPrefix: "Owner" });
  assert.deepEqual(r, { "Workspace.A": { OwnerId: 1 } });
});

test("filterAttributes combines instancePath and keyPrefix", () => {
  const attrs = {
    "Workspace.A": { OwnerId: 1, Color: "red" },
    "Workspace.A.Child": { OwnerName: "x" },
    "Workspace.B": { OwnerId: 2 },
  };
  const r = filterAttributes(attrs, { instancePath: "Workspace.A", keyPrefix: "Owner" });
  assert.deepEqual(r, {
    "Workspace.A": { OwnerId: 1 },
    "Workspace.A.Child": { OwnerName: "x" },
  });
});

test("filterAttributes with no filter returns everything", () => {
  const attrs = { "Workspace.A": { X: 1 } };
  assert.deepEqual(filterAttributes(attrs, {}), attrs);
});

test("describeAge formats elapsed time and returns null for garbage", () => {
  const base = new Date("2026-06-08T12:00:00Z");
  assert.equal(describeAge("2026-06-08T11:59:59Z", base).human, "just now");
  assert.equal(describeAge("2026-06-08T11:30:00Z", base).human, "30 minutes ago");
  assert.equal(describeAge("2026-06-08T09:00:00Z", base).human, "3 hours ago");
  const fourDays = describeAge("2026-06-04T12:00:00Z", base);
  assert.equal(fourDays.days, 4);
  assert.equal(fourDays.human, "4 days ago");
  assert.equal(describeAge("not-a-date", base), null);
});

test("boundTreeNode keeps direct children but truncates beyond maxDepth", () => {
  const tree = n("Root", [n("Child", [n("Grand", [])])]);
  const b = boundTreeNode(tree, { maxDepth: 1 });
  assert.equal(b.name, "Root");
  assert.equal(b.children.length, 1);
  const child = b.children[0];
  assert.equal(child.name, "Child");
  assert.equal(child.children, undefined); // grandchildren cut...
  assert.equal(child._truncated, 1); // ...and counted
});

test("boundTreeNode with maxDepth 0 drops children but keeps the count", () => {
  const tree = n("Root", [n("A", []), n("B", [])]);
  const b = boundTreeNode(tree, { maxDepth: 0 });
  assert.equal(b.children, undefined);
  assert.equal(b._truncated, 2);
});

test("boundTreeNode caps children with maxChildren and reports omissions", () => {
  const kids = [];
  for (let i = 0; i < 5; i++) kids.push(n("K" + i, []));
  const b = boundTreeNode(n("Root", kids), { maxDepth: 1, maxChildren: 2 });
  assert.deepEqual(b.children.map((c) => c.name), ["K0", "K1"]);
  assert.equal(b._childrenOmitted, 3);
  assert.equal(b._childCount, 5);
});

test("boundTreeNode without maxChildren keeps every child (get_tree parity)", () => {
  const b = boundTreeNode(n("Root", [n("A", []), n("B", []), n("C", [])]), { maxDepth: 3 });
  assert.equal(b.children.length, 3);
  assert.equal(b._childrenOmitted, undefined);
  assert.equal(b._childCount, undefined);
  assert.equal(b._truncated, undefined);
});

test("boundTreeNode leaves a leaf node unchanged", () => {
  const leaf = n("Leaf", []);
  assert.deepEqual(boundTreeNode(leaf, { maxDepth: 1, maxChildren: 5 }), leaf);
});

test("boundTreeNode does not mutate the input node", () => {
  const tree = n("Root", [n("Child", [n("Grand", [])])]);
  boundTreeNode(tree, { maxDepth: 0, maxChildren: 1 });
  assert.equal(tree.children.length, 1);
  assert.equal(tree.children[0].children.length, 1); // grandchild still intact
});
