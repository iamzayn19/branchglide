"""
Thin launcher: resolves a system Ruby, then execs the vendored copy of the
canonical Branchglide Ruby engine (branchglide/vendor/), forwarding argv and
preserving stdio/exit code. No business logic lives here -- see
lib/branchglide/ in the main repo for the actual implementation, shared by
all three package ecosystems.

This package requires a system Ruby (>= 3.0) on PATH. We do not bundle a
portable Ruby runtime for the same reason the npm package doesn't: that
requires maintaining signed, checksummed builds for five OS/arch targets.
Install Ruby via your OS package manager, rbenv, asdf, or rvm if missing.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

MIN_RUBY_MAJOR = 3


def _find_ruby() -> str | None:
    candidates = ["ruby.exe", "ruby"] if sys.platform == "win32" else ["ruby"]
    for candidate in candidates:
        path = shutil.which(candidate)
        if path:
            return path
    return None


def _ruby_major_version(ruby: str) -> int:
    result = subprocess.run(
        [ruby, "-e", "print RUBY_VERSION"], capture_output=True, text=True, check=False
    )
    version = result.stdout or "0.0.0"
    try:
        return int(version.split(".")[0])
    except ValueError:
        return 0


def main() -> int:
    ruby = _find_ruby()
    if not ruby:
        sys.stderr.write(
            "branchglide: no Ruby interpreter found on PATH.\n"
            "Branchglide's engine is written in Ruby; this PyPI package is a thin launcher "
            "around it. Install Ruby >= 3.0 (https://www.ruby-lang.org/en/documentation/"
            "installation/) and re-run.\n"
        )
        return 1

    if _ruby_major_version(ruby) < MIN_RUBY_MAJOR:
        sys.stderr.write("branchglide: found a Ruby interpreter, but Ruby >= 3.0 is required.\n")
        return 1

    entry = Path(__file__).parent / "vendor" / "exe" / "branchglide"
    if not entry.exists():
        sys.stderr.write("branchglide: vendored engine not found; this package install is corrupt.\n")
        return 1

    result = subprocess.run([ruby, str(entry), *sys.argv[1:]])
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
