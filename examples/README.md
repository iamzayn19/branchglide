# Examples

Each directory is a minimal standalone app plus a `.branchglide.yml`,
demonstrating the config shape for that stack. Try one:

```bash
cd examples/python   # or examples/node, examples/rails
git init -q -b main && git add -A && git commit -q -m init
branchglide up main
branchglide ls
```

- `python/` — stdlib-only HTTP server, no dependencies. Verified working.
- `rails/` — a plain-Ruby stand-in for `bin/rails server`, so the example
  doesn't require installing Rails itself; the `.branchglide.yml` shape
  (`bundle exec rails server -b 127.0.0.1 -p {port}`) is what a real Rails
  app would use instead.
- `node/` — stdlib-only HTTP server. Requires a `node`/`npm` on PATH; if
  you use asdf/nvm, make sure a Node version is selected for this directory.
