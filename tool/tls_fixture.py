"""Local HTTPS fixture. Its temporary self-signed certificate must be rejected."""
import http.server
import ssl

server = http.server.HTTPServer(('127.0.0.1', 18443), http.server.SimpleHTTPRequestHandler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain('tls-fixture-cert.pem', 'tls-fixture-key.pem')
server.socket = context.wrap_socket(server.socket, server_side=True)
server.serve_forever()
