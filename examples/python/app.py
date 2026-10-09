"""Minimal example app for Branchglide. Start with `python app.py --port
<port>`; see ../../README.md and this directory's .branchglide.yml.
"""

import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"ok" if self.path == "/up" else f"Hello from the Python example app on port {PORT}\n".encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


if __name__ == "__main__":
    PORT = int(sys.argv[sys.argv.index("--port") + 1]) if "--port" in sys.argv else 3000
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
