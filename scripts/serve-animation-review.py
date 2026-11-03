"""Local review server with module MIME types, no stale assets and enough backlog."""
import argparse
import functools
import http.server
from pathlib import Path

class ReviewHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map={**http.server.SimpleHTTPRequestHandler.extensions_map,'.mjs':'text/javascript','.js':'text/javascript','.glb':'model/gltf-binary'}
    def end_headers(self):
        self.send_header('Cache-Control','no-store, max-age=0')
        super().end_headers()
    def log_message(self,*args):pass

class ReviewServer(http.server.ThreadingHTTPServer):
    request_queue_size=128
    daemon_threads=True

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=8765);args=parser.parse_args()
    directory=Path(__file__).resolve().parents[1]/'content-animations'
    with ReviewServer(('127.0.0.1',args.port),functools.partial(ReviewHandler,directory=str(directory))) as server:
        print(f'Animation review: http://localhost:{args.port}/review.html',flush=True)
        server.serve_forever()
