import json
import socket
import ssl
import threading
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class FixtureState:
    def __init__(self):
        self.lock = threading.Lock()
        self.responses = deque()
        self.requests = []


def start_servers(certfile, keyfile):
    state = FixtureState()

    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *_):
            pass

        def send_body(self, status, body, headers=None):
            data = body.encode("utf-8")
            self.send_response(status)
            for name, value in (headers or {}).items():
                if name.lower() not in ("content-length", "connection"):
                    self.send_header(name, value)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(data)
            self.close_connection = True

        def handle_request(self):
            body = self.rfile.read(int(self.headers.get("Content-Length", "0"))).decode("utf-8")
            if self.server.control:
                if self.command == "GET" and self.path == "/health":
                    return self.send_body(200, "ready")
                if self.command == "GET" and self.path == "/requests":
                    with state.lock:
                        captured = json.dumps(state.requests)
                    return self.send_body(200, captured, {"Content-Type": "application/json"})
                if self.command == "POST" and self.path == "/reset":
                    try:
                        responses = json.loads(body)["responses"]
                        if not isinstance(responses, list) or not all(
                            isinstance(response, dict)
                            and isinstance(response.get("status", 200), int)
                            and isinstance(response.get("body", ""), str)
                            and isinstance(response.get("headers", {}), dict)
                            for response in responses
                        ):
                            raise ValueError("invalid response queue")
                    except (KeyError, TypeError, ValueError):
                        return self.send_body(400, "invalid response queue")
                    with state.lock:
                        state.responses = deque(responses)
                        state.requests = []
                    return self.send_body(200, "reset")
                return self.send_body(404, "unknown control endpoint")

            with state.lock:
                state.requests.append({
                    "method": self.command,
                    "path": self.path,
                    "headers": {name.lower(): value for name, value in self.headers.items()},
                    "body": body,
                })
                response = state.responses.popleft() if state.responses else {
                    "status": 500, "body": "unexpected fixture request"
                }
            if response.get("disconnect"):
                self.close_connection = True
                self.connection.shutdown(socket.SHUT_RDWR)
                return
            self.send_body(response.get("status", 200), response.get("body", ""), response.get("headers"))

        do_GET = handle_request
        do_POST = handle_request

    servers = []
    try:
        for address, control, secure in [
            (("0.0.0.0", 80), False, False),
            (("127.0.0.1", 18080), True, False),
            (("127.0.0.1", 18443), False, True),
        ]:
            server = ThreadingHTTPServer(address, Handler)
            server.control = control
            servers.append(server)
            if secure:
                context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                context.load_cert_chain(certfile, keyfile)
                server.socket = context.wrap_socket(server.socket, server_side=True)
        for server in servers:
            threading.Thread(target=server.serve_forever, daemon=True).start()
        return servers
    except Exception:
        for server in servers:
            server.server_close()
        raise
