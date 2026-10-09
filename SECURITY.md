# Security

Branchglide runs your application code locally and, when you explicitly run
`branchglide share`, exposes it to the public internet through a tunnel
provider you already have installed. Treat that command as the
security-sensitive operation in this tool.

## Threat model

- Preview app processes bind to `127.0.0.1` only. They are not reachable
  from outside the host until a tunnel is explicitly started.
- `branchglide share` and `branchglide slot create` / `focus` never run
  implicitly as a side effect of `up`, `restart`, or any other command.
- A Cloudflare Quick Tunnel URL has **no authentication of its own**.
  Branchglide prints a warning on every `share` call; it does not and
  cannot add authentication on your behalf.
- `.branchglide.yml`'s `app.command` is executed as an argument array, never
  interpolated into a shell string, so branch names and config values
  cannot inject additional shell commands.
- Worktree removal refuses to touch a directory Branchglide did not create,
  and refuses to remove a worktree with uncommitted changes.
- Process termination uses a pidfile recording both the PID and the start
  time Branchglide itself observed, to avoid signaling an unrelated process
  that has since reused that PID.

## Reporting a vulnerability

Please open a private security advisory on
[the GitHub repository](https://github.com/iamzayn19/branchglide/security/advisories)
rather than a public issue. We'll acknowledge reports as promptly as we can
and credit reporters in the changelog unless you'd prefer otherwise.
