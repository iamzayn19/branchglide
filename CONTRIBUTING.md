# Contributing to Branchglide

## Architecture

The canonical implementation is Ruby, under `lib/branchglide/`. The npm and
PyPI packages (`packages/npm/`, `packages/python/`) are thin launchers that
resolve a system Ruby and exec a vendored copy of the same engine — they
must never duplicate business logic. If you're changing behavior, change it
in `lib/branchglide/`; the wrappers should not need touching unless the
launcher mechanics themselves change.

## Development setup

```bash
bundle install
bundle exec rake test
```

To test the npm/PyPI wrappers against your local changes:

```bash
./scripts/sync_vendor.sh
cd packages/npm && node --test test/
cd packages/python && pip install -e . pytest && python -m pytest tests/
```

## Tests

- `test/unit/` — fast, isolated unit tests.
- `test/integration/` — spins up real throwaway Git repos and real
  (fixture) HTTP processes to exercise the full preview lifecycle. These
  are slower; run the full suite before opening a PR.

## Commit style

Small, focused commits. Each one should correspond to a single coherent
change — a feature, a fix, a test, or a docs update — not a mix of several.

## Adding a tunnel provider

Implement `Branchglide::Tunnels::Base`'s four methods
(`start`, `stop`, `public_url`, `executable_available?`) and wire it into
`CLI#tunnel_for`. See `lib/branchglide/tunnels/cloudflare.rb` for the
reference implementation.
