# Branchglide

**Preview any Git branch. Share it without deploying.**

Branchglide runs multiple Git branches independently using isolated Git
worktrees, exposes previews through existing tunneling providers, and lets
you switch a named preview slot between branches without restarting the
public tunnel.

No Branchglide-hosted backend, account system, or telemetry. It's a local
CLI that orchestrates `git worktree`, your app's own start command, and a
tunnel binary you already have.

## Quick start

```bash
gem install branchglide   # or: npm install -g branchglide / pip install branchglide

cd your-project
branchglide init          # writes .branchglide.yml
branchglide up main
branchglide up feature/checkout
branchglide ls
```

Each branch gets its own commit-pinned worktree, its own process, and its
own port. Switching branches in your normal working directory never
touches a running preview.

## Installation

### RubyGems (canonical implementation)

```bash
gem install branchglide
```

### npm

```bash
npm install -g branchglide
```

The npm package is a thin launcher: it resolves a Ruby interpreter
(**Ruby >= 3.0 required on PATH**) and execs the same engine code published
to RubyGems. It does **not** bundle a portable Ruby runtime — that would
mean maintaining signed, checksummed Ruby builds for five OS/arch targets,
which this project does not currently do. If you don't have Ruby installed,
get it via your OS package manager, [rbenv](https://github.com/rbenv/rbenv),
[asdf](https://asdf-vm.com/), or [rvm](https://rvm.io/), then re-run the
install.

### pip

```bash
pip install branchglide
```

Same strategy and the same Ruby >= 3.0 requirement as the npm package.
Works inside a virtualenv; does not touch your system Ruby or Python.

All three expose the same `branchglide` executable with identical behavior,
because they all call into the same Ruby engine (`lib/branchglide/`).

## Why Git worktrees

Each preview checks out its branch's commit into its own working directory
(`.branchglide/worktrees/<branch>`), detached at that commit rather than
tracking the branch live. That means:

- Running `git checkout` in your normal clone never affects an active preview.
- Updating a preview to a branch's latest commit is an explicit action
  (`branchglide restart <branch>`), not something that happens behind your back.
- Branchglide never touches a worktree it didn't create, and never removes
  one that has uncommitted changes.

## Public tunneling

```bash
branchglide share feature/checkout
branchglide unshare feature/checkout
```

Branchglide starts a [Cloudflare Quick Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/do-more-with-tunnels/trycloudflare/)
using your existing `cloudflared` binary. The resulting `*.trycloudflare.com`
URL is temporary, provider-assigned, and **has no authentication of its
own** — Branchglide prints a warning every time you share. Sharing is never
automatic; `branchglide up` never exposes anything publicly by itself.

Other providers (ngrok, zrok) can be added behind the same
`Branchglide::Tunnels::Base` interface; only Cloudflare ships today.

## Named preview slots

A slot is a stable local routing target that can be re-pointed at a
different branch's preview without restarting the tunnel sitting in front
of it:

```bash
branchglide slot create qa --branch main
branchglide share --slot qa
branchglide focus qa feature/checkout
```

`focus` health-checks the new target **before** switching. If the new
target never becomes healthy, the slot keeps routing to its previous,
still-healthy target and the command exits non-zero.

## Configuration

`.branchglide.yml`:

```yaml
version: 1
app:
  command: ["bundle", "exec", "rails", "server", "-b", "127.0.0.1", "-p", "{port}"]
  health_path: /up
preview:
  mode: snapshot
  provider: cloudflare
```

`{port}` is substituted into the command array — never into a shell
string — so nothing in a branch name, environment variable, or config value
can be interpreted as a shell command. The same shape works for Node or
Python apps:

```yaml
app:
  command: ["npm", "run", "dev", "--", "--port", "{port}"]
```

## CLI reference

```
branchglide init
branchglide doctor

branchglide up <branch>
branchglide down <branch>
branchglide restart <branch>

branchglide ls
branchglide status
branchglide logs <branch> [--follow]

branchglide share <branch> | --slot <name>
branchglide unshare <branch>

branchglide slot create <name> --branch <branch>
branchglide slot ls
branchglide slot remove <name>
branchglide focus <name> <branch>

branchglide cleanup
```

## Security

- Local preview processes bind to `127.0.0.1` only; nothing is reachable
  from outside your machine until you explicitly run `share`.
- `branchglide share` prints an explicit warning every time, because a
  development server is not production-hardened and a Cloudflare Quick
  Tunnel enforces no authentication of its own.
- All commands are executed as argument arrays, never as interpolated
  shell strings — see `test/unit/security_test.rb`.
- Branchglide will not remove a worktree it did not create, or one with
  uncommitted changes.

See [SECURITY.md](SECURITY.md) for the full threat model and how to report
a vulnerability.

## Cross-platform support

Tested in CI on Linux (x86_64), macOS, and Windows, across Ruby 3.1–3.3.
Process supervision uses pidfiles with recorded start times rather than
bare PID signaling, to avoid acting on an unrelated process after PID reuse.

## Known limitations

- Only Cloudflare Quick Tunnels are implemented; ngrok/zrok are not yet wired up.
- npm and PyPI installs require a system Ruby — see Installation above.
- Cloudflare Quick Tunnel URLs are temporary and are not guaranteed to
  survive a `cloudflared` restart; Branchglide does not promise a
  persistent public hostname.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache-2.0 — see [LICENSE](LICENSE).
