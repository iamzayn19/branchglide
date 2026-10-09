// Minimal example app for Branchglide. Start with `npm run dev -- --port
// <port>`; see ../../README.md and this directory's .branchglide.yml.
"use strict";

const http = require("node:http");

const portFlagIndex = process.argv.indexOf("--port");
const port = portFlagIndex >= 0 ? Number(process.argv[portFlagIndex + 1]) : 3000;

const server = http.createServer((req, res) => {
  if (req.url === "/up") {
    res.writeHead(200);
    res.end("ok");
    return;
  }
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end(`Hello from the Node example app on port ${port}\n`);
});

server.listen(port, "127.0.0.1", () => {
  console.log(`listening on 127.0.0.1:${port}`);
});
