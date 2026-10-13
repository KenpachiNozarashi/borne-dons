"""Local logo background removal. Listens on loopback only; no image uploads to third parties."""
import io
import json
import os
import sys
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Lock

model_dir = Path(sys._MEIPASS) / 'models' if getattr(sys, 'frozen', False) else Path(__file__).parent / 'models'
os.environ.setdefault('U2NET_HOME', str(model_dir))
from PIL import Image
from rembg import new_session, remove

ALLOWED_ORIGINS = {'http://localhost:8080', 'http://127.0.0.1:8080'}
MAX_BYTES = 5 * 1024 * 1024
_session = None
_lock = Lock()


def process_logo(data):
    global _session
    with Image.open(io.BytesIO(data)) as source:
        if source.width * source.height > 16_000_000:
            raise ValueError('Image trop grande.')
        source.load()
        image = source.convert('RGBA')
        # Already transparent logos retain their artwork exactly.
        if image.getchannel('A').getextrema()[0] < 255:
            result = image
        else:
            with _lock:
                if _session is None:
                    _session = new_session('u2net')
                result = remove(image, session=_session)
        if result.getchannel('A').getbbox() is None:
            raise ValueError('Aucun logo détecté. Gardez le logo original.')
        output = io.BytesIO()
        result.save(output, format='PNG')
        return output.getvalue()


class Handler(BaseHTTPRequestHandler):
    def origin_allowed(self):
        return self.headers.get('Origin') in ALLOWED_ORIGINS or not self.headers.get('Origin')

    def respond(self, status, body, mime='application/json'):
        self.send_response(status)
        origin = self.headers.get('Origin')
        if origin in ALLOWED_ORIGINS:
            self.send_header('Access-Control-Allow-Origin', origin)
            self.send_header('Vary', 'Origin')
        self.send_header('Content-Type', mime)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        if not self.origin_allowed():
            self.respond(403, b'{}')
            return
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', self.headers.get('Origin', 'http://127.0.0.1:8080'))
        self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('Access-Control-Allow-Private-Network', 'true')
        self.end_headers()

    def do_GET(self):
        if self.path == '/health':
            self.respond(200, b'{"status":"ready"}')
        else:
            self.respond(404, b'{}')

    def do_POST(self):
        if self.path != '/remove-background':
            self.respond(404, b'{}')
            return
        if not self.origin_allowed():
            self.respond(403, b'{}')
            return
        try:
            length = int(self.headers.get('Content-Length', 0))
            if not 0 < length <= MAX_BYTES:
                self.respond(413, b'{"error":"Image trop grande ou vide."}')
                return
            data = self.rfile.read(length)
            output = process_logo(data)
            self.respond(200, output, 'image/png')
        except Exception:
            self.respond(422, json.dumps({'error': 'Détourage impossible. Vous pouvez garder le logo original.'}).encode())


if __name__ == '__main__':
    print('Préparation du modèle de détourage local...', flush=True)
    _session = new_session('u2net')
    print('Détourage local prêt sur http://127.0.0.1:3002', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 3002), Handler).serve_forever()
