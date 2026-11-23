#!/usr/bin/env python3
"""A tiny stand-in for the board's web server (src/WifiApp.cpp) for testing HttpLink on a PC. It answers /api/ctrl and /api/data
with frames from ios/Tests/golden/frames.json (built by the firmware's own C++). Usage: fake_board.py <repo root> [port]"""
import http.server, json, pathlib, sys, threading

root = pathlib.Path(sys.argv[1])
port = int(sys.argv[2]) if len(sys.argv) > 2 else 0
frames = {k: bytes.fromhex(v) for k, v in json.loads((root / 'ios/Tests/golden/frames.json').read_text()).items()}
log = []

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0)); body = self.rfile.read(n)
        log.append((self.path, list(body[:8]), len(body)))
        out = b''
        if self.path == '/api/ctrl' and body:
            op = body[0]
            out = frames['info'] if op == 1 else frames['live_all'] if op == 0x54 else bytes([0x30, op, 0]) if op in (0x20, 0x50) else bytes([0x30, op, 2])
        elif self.path == '/api/data':
            out = frames['ota_recv']
        elif self.path == '/boom':
            self.send_error(500); return
        self.send_response(200); self.send_header('Content-Type', 'application/octet-stream'); self.send_header('Content-Length', str(len(out))); self.end_headers(); self.wfile.write(out)
    def do_GET(self):
        if self.path == '/log':
            b = json.dumps(log).encode(); self.send_response(200); self.send_header('Content-Length', str(len(b))); self.end_headers(); self.wfile.write(b); return
        self.send_error(404)

srv = http.server.ThreadingHTTPServer(('127.0.0.1', port), H)
print(srv.server_address[1], flush=True)
srv.serve_forever()
