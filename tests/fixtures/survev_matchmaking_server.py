#!/usr/bin/env python3
"""Local HTTP fixture for original Survev find_game_v2 (never contacts public hosts)."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/api/find_game_v2":
            self.send_error(404)
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            assert 0 < size < 4096
            assert self.headers.get("Content-Type", "").startswith("application/json")
            body = json.loads(self.rfile.read(size))
            assert body == {
                "version": 1028,
                "region": "na",
                "zones": [],
                "playerCount": 1,
                "autoFill": True,
                "gameModeIdx": 0,
            }, body
            payload = json.dumps({
                "type": "success",
                "res": {"urls": ["ws://127.0.0.1:17984/play"],
                        "joinToken": "AUTHENTIC-FIXTURE-TOKEN"},
            }).encode()
            self.send_response(200)
        except (AssertionError, ValueError, KeyError) as error:
            payload = json.dumps({"type": "error", "error": str(error)}).encode()
            self.send_response(400)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *_args):
        pass

server = ThreadingHTTPServer(("127.0.0.1", 17983), Handler)
server.serve_forever()
