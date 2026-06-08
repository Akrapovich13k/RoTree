"use strict";
// Tests for the robust Rojo project discovery + comparison. Run with
// `node --test` after the core package is built.
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const { RojoComparator, ExportReader } = require("../out/index.js");

function tmp() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "rotree-rojo-"));
}
function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
}
function comparator(workspaceRoot, projectPath) {
  const reader = new ExportReader({ workspaceRoot });
  return new RojoComparator(workspaceRoot, reader, { projectPath });
}

test("detects default.project.json in the workspace root", async () => {
  const root = tmp();
  write(path.join(root, "default.project.json"), JSON.stringify({ name: "x", tree: {} }));
  const rojo = comparator(root);
  assert.equal(await rojo.detect(), true);
  assert.equal(await rojo.projectFile(), path.join(root, "default.project.json"));
});

test("walks UP parent directories to find the project", async () => {
  const root = tmp();
  write(path.join(root, "default.project.json"), JSON.stringify({ tree: {} }));
  const nested = path.join(root, "build", "exports");
  fs.mkdirSync(nested, { recursive: true });
  const rojo = comparator(nested); // export folder is nested, project is up top
  assert.equal(await rojo.projectFile(), path.join(root, "default.project.json"));
});

test("scans immediate sub-directories", async () => {
  const root = tmp();
  write(path.join(root, "game", "default.project.json"), JSON.stringify({ tree: {} }));
  const rojo = comparator(root);
  assert.equal(await rojo.projectFile(), path.join(root, "game", "default.project.json"));
});

test("honours an explicit project file path", async () => {
  const root = tmp();
  const explicit = path.join(root, "place", "client.project.json");
  write(explicit, JSON.stringify({ tree: {} }));
  // Also drop a default in the root to prove the explicit path wins.
  write(path.join(root, "default.project.json"), JSON.stringify({ tree: {} }));
  const rojo = comparator(root, explicit);
  assert.equal(await rojo.projectFile(), explicit);
});

test("explicit directory resolves default.project.json inside it", async () => {
  const root = tmp();
  const dir = path.join(root, "sub");
  write(path.join(dir, "default.project.json"), JSON.stringify({ tree: {} }));
  const rojo = comparator(root, dir);
  assert.equal(await rojo.projectFile(), path.join(dir, "default.project.json"));
});

test("reports searched locations when nothing is found", async () => {
  const root = tmp();
  const rojo = comparator(root);
  assert.equal(await rojo.detect(), false);
  const searched = rojo.searchedLocations();
  assert.ok(searched.length > 0, "should list candidate locations");
  assert.ok(
    searched.some((p) => p.endsWith("default.project.json")),
    "candidates should include default.project.json probes",
  );
});

test("compare() resolves $path relative to the project file dir", async () => {
  const root = tmp();
  // Rojo project lives in a sub-folder; its src is relative to that folder.
  const projDir = path.join(root, "game");
  write(
    path.join(projDir, "default.project.json"),
    JSON.stringify({
      name: "demo",
      tree: { ServerScriptService: { $path: "src/server" } },
    }),
  );
  write(path.join(projDir, "src", "server", "Hello.server.luau"), "print('hi')\n");
  write(path.join(projDir, "src", "server", "OnlyRojo.server.luau"), "print('only rojo')\n");

  // Studio export sits at the repo root .rotree, NOT next to the project.
  write(
    path.join(root, ".rotree", "scripts-map.json"),
    JSON.stringify([
      {
        name: "Hello",
        className: "Script",
        fullPath: "ServerScriptService.Hello",
        source: "print('hi')",
        lines: 1,
      },
      {
        name: "OnlyStudio",
        className: "Script",
        fullPath: "ServerScriptService.OnlyStudio",
        source: "print('studio')",
        lines: 1,
      },
    ]),
  );

  const rojo = comparator(root);
  assert.equal(await rojo.projectFile(), path.join(projDir, "default.project.json"));
  const diff = await rojo.compare();
  assert.ok(diff, "diff should be produced");
  assert.deepEqual(diff.onlyInStudio, ["ServerScriptService.OnlyStudio"]);
  assert.deepEqual(diff.onlyInRojo, ["ServerScriptService.OnlyRojo"]);
  assert.deepEqual(diff.differentSource, []); // Hello matches on both sides
});
