"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const { spawnSync } = require("node:child_process");
const path = require("node:path");
const fs = require("node:fs");

const BIN = path.join(__dirname, "..", "bin", "branchglide.js");
const VENDOR = path.join(__dirname, "..", "vendor");

test("launcher forwards --version to the vendored Ruby engine", { skip: !fs.existsSync(VENDOR) && "run scripts/sync_vendor.sh first" }, () => {
  const result = spawnSync("node", [BIN, "--version"], { encoding: "utf8" });
  assert.strictEqual(result.status, 0);
  assert.match(result.stdout.trim(), /^\d+\.\d+\.\d+$/);
});

test("launcher forwards argv and preserves non-zero exit code on error", { skip: !fs.existsSync(VENDOR) && "run scripts/sync_vendor.sh first" }, () => {
  const result = spawnSync("node", [BIN, "logs", "no-such-branch"], { encoding: "utf8", cwd: "/tmp" });
  assert.notStrictEqual(result.status, 0);
});

test("launcher exits 1 with a clear message when vendored engine is missing", () => {
  // Simulated by pointing at a bin copy with no sibling vendor/ dir.
  const tmpBin = path.join(require("node:os").tmpdir(), "branchglide-missing-vendor.js");
  fs.copyFileSync(BIN, tmpBin);
  const result = spawnSync("node", [tmpBin, "--version"], { encoding: "utf8" });
  fs.unlinkSync(tmpBin);
  assert.notStrictEqual(result.status, 0);
  assert.match(result.stderr, /vendored engine not found|no Ruby interpreter/);
});
