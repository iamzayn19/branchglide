import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / "branchglide" / "vendor"

pytestmark = pytest.mark.skipif(not VENDOR.exists(), reason="run scripts/sync_vendor.sh first")


def run_launcher(*args):
    return subprocess.run(
        [sys.executable, "-c", "from branchglide.launcher import main; import sys; sys.exit(main())", *args],
        capture_output=True,
        text=True,
        cwd=ROOT,
    )


def test_forwards_version_flag():
    result = run_launcher("--version")
    assert result.returncode == 0
    assert result.stdout.strip().count(".") == 2


def test_preserves_nonzero_exit_code_on_error():
    result = run_launcher("logs", "no-such-branch")
    assert result.returncode != 0
