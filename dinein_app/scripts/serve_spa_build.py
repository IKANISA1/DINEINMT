#!/usr/bin/env python3
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class SpaHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, directory: str, **kwargs):
        self._spa_directory = Path(directory)
        super().__init__(*args, directory=directory, **kwargs)

    def send_head(self):  # noqa: D401 - http.server override
        path = self.translate_path(self.path)
        requested = Path(path)
        if requested.exists():
            return super().send_head()

        request_path = self.path.split("?", 1)[0].split("#", 1)[0]
        if "." not in request_path.rsplit("/", 1)[-1]:
            self.path = "/index.html"
            return super().send_head()

        return super().send_head()


def main() -> int:
    parser = argparse.ArgumentParser(description="Serve a Flutter web build with SPA fallback.")
    parser.add_argument("directory", help="Directory to serve")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=4173)
    args = parser.parse_args()

    handler = partial(SpaHandler, directory=args.directory)
    server = ThreadingHTTPServer((args.host, args.port), handler)
    print(f"Serving {args.directory} on http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
