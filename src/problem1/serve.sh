#!/bin/bash

python3 -c "
from http.server import HTTPServer, BaseHTTPRequestHandler

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        order_id = self.path.split('/')[-1]
        response = f'{{\"order_id\": \"{order_id}\", \"status\": \"ok\"}}'
        self.wfile.write(response.encode())
        print(f'[REQUEST] GET {self.path} -> {response}')

    def log_message(self, format, *args):
        pass

print('Mock API server started at http://localhost:8081')
print('Waiting for requests...')
print('-' * 40)
HTTPServer(('', 8081), Handler).serve_forever()
"