#!/usr/bin/env node
"use strict";

/**
 * Thin launcher: resolves a system Ruby, then execs the vendored copy of
 * the canonical Branchglide Ruby engine (packages/npm/vendor/), forwarding
 * argv and preserving stdio/exit code. No business logic lives here --
 * see lib/branchglide/ for the actual implementation, shared by all three
 * package ecosystems.
 *
 * This package requires a system Ruby (>= 3.0) on PATH. We do not bundle a
 * portable Ruby runtime: that would require maintaining signed, checksummed
 * builds for five OS/arch targets, which is a real release engineering
 * effort beyond a thin wrapper. If that is a blocker for your environment,
 * install Ruby via your OS package manager, rbenv, asdf, or rvm.
 */

const { spawnSync } = require("node:child_process");
const path = require("node:path");
const fs = require("node:fs");

const MIN_RUBY_MAJOR = 3;

function findRuby() {
  const candidates = process.platform === "win32" ? ["ruby.exe", "ruby"] : ["ruby"];
  for (const candidate of candidates) {
    const probe = spawnSync(candidate, ["-v"], { encoding: "utf8" });
    if (probe.status === 0 && probe.stdout) return candidate;
  }
  return null;
}

function checkVersion(ruby) {
  const result = spawnSync(ruby, ["-e", "print RUBY_VERSION"], { encoding: "utf8" });
  const version = result.stdout || "0.0.0";
  const major = parseInt(version.split(".")[0], 10);
  return { ok: major >= MIN_RUBY_MAJOR, version };
}

function main() {
  const ruby = findRuby();
  if (!ruby) {
    process.stderr.write(
      "branchglide: no Ruby interpreter found on PATH.\n" +
        "Branchglide's engine is written in Ruby; this npm package is a thin launcher around it.\n" +
        "Install Ruby >= 3.0 (e.g. https://www.ruby-lang.org/en/documentation/installation/) and re-run.\n"
    );
    process.exit(1);
  }

  const { ok, version } = checkVersion(ruby);
  if (!ok) {
    process.stderr.write(`branchglide: found Ruby ${version}, but Ruby >= 3.0 is required.\n`);
    process.exit(1);
  }

  const entry = path.join(__dirname, "..", "vendor", "exe", "branchglide");
  if (!fs.existsSync(entry)) {
    process.stderr.write("branchglide: vendored engine not found; this package install is corrupt.\n");
    process.exit(1);
  }

  const result = spawnSync(ruby, [entry, ...process.argv.slice(2)], { stdio: "inherit" });
  if (result.error) {
    process.stderr.write(`branchglide: failed to launch engine: ${result.error.message}\n`);
    process.exit(1);
  }
  process.exit(result.status === null ? 1 : result.status);
}

main();
