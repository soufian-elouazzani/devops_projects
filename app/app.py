#!/usr/bin/env python3
"""HTTP service shared by every project in this portfolio.

The contract is intentionally small:

- ``GET /health`` returns 200 when the process can serve traffic
- ``GET /version`` reports the color and version of this instance
- ``GET /metrics`` exposes Prometheus text so the observability project has something real to scrape

Blue-green deployment works by running two copies of this process and moving the proxy from one to the other.
"""

from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def deploy_color() -> str:
    return os.environ.get("DEPLOY_COLOR", "blue")


def app_version() -> str:
    return os.environ.get("APP_VERSION", "1.0.0")


class Metrics:
    def __init__(self) -> None:
        self.requests = 0


METRICS = Metrics()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:  # noqa: N802 - stdlib handler name
        path = self.path.split("?", 1)[0]
        METRICS.requests += 1
        color = deploy_color()
        version = app_version()

        if path == "/health":
            self._json(200, {"status": "ok"})
            return
        if path == "/version":
            self._json(200, {"color": color, "version": version})
            return
        if path == "/metrics":
            body = (
                "# HELP app_requests_total Total HTTP requests served by this process.\n"
                "# TYPE app_requests_total counter\n"
                f'app_requests_total{{color="{color}",version="{version}"}} {METRICS.requests}\n'
                "# HELP app_info Static information about this process.\n"
                "# TYPE app_info gauge\n"
                f'app_info{{color="{color}",version="{version}"}} 1\n'
            )
            self._bytes(200, "text/plain; version=0.0.4; charset=utf-8", body.encode())
            return
        if path == "/":
            html = (
                "<!DOCTYPE html><html><head><meta charset=\"utf-8\">"
                "<title>platform-lab</title></head><body>"
                f"<h1>platform-lab</h1><p>color: {color}</p><p>version: {version}</p>"
                "</body></html>"
            )
            self._bytes(200, "text/html; charset=utf-8", html.encode())
            return
        self._json(404, {"error": "not found"})

    def _json(self, status: int, payload: dict) -> None:
        self._bytes(status, "application/json", json.dumps(payload).encode())

    def _bytes(self, status: int, content_type: str, body: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args) -> None:
        message = fmt % args
        print(
            f"color={deploy_color()} version={app_version()} "
            f"client={self.address_string()} {message}"
        )


def make_server(host: str, port: int) -> ThreadingHTTPServer:
    return ThreadingHTTPServer((host, port), Handler)


def main() -> None:
    host = "0.0.0.0"
    port = int(os.environ.get("PORT", "8080"))
    server = make_server(host, port)
    print(f"listening on {host}:{port} color={deploy_color()} version={app_version()}")
    server.serve_forever()


if __name__ == "__main__":
    main()
