"""Optional localhost-only Meta Muse Spark proposal proxy; Python 3 standard library.

Run outside the game. No credentials, upstream response bodies, or headers are
returned to clients or logs. Deterministic acceptance belongs to GDScript.
"""
import json
import os
import socket
import ssl
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener

META_URL = "https://api.meta.ai/v1/chat/completions"
META_MODEL = "muse-spark-1.3"
UPSTREAM_TIMEOUT_SECONDS = 60
MAX_BODY = 65536
SCHEMA = json.loads((Path(__file__).resolve().parents[1] / "docs/steppe-proposal.schema.json").read_text())
CONTEXT = """DAIRN: GREAT STEPPE. Propose geography only, never rules or story state.
Output one v1 steppe JSON object: width=height=16, cells row-major indexed r*16+q,
axial pointy-top hexes. Neighbors: (1,0),(1,-1),(0,-1),(-1,0),(-1,1),(0,1).
Only steppe, mountain, river, sea. Every boundary cell (q=0, q=15, r=0,
or r=15) MUST be mountain or sea; never steppe or river. Include all four
terrains, irregular narrow
mountain projections and sea inlets extending into the interior. Every river
must be a declared simple connected path of river coordinates, first adjacent
to mountain and last adjacent to sea. All river tiles must belong to a path.
Start on steppe. Uki walks to neighboring steppe or flies at most 3 hexes,
landing on steppe; straight trajectories may cross rivers but NEVER mountains
or sea (including touching an edge). Reveal radius is one hex. Every map cell except the two corners (0,0) and (15,15)
must be revealable from reachable steppe positions; only these two unreachable
impassable corners are excluded from victory. Avoid thick impassable regions. No other terrain, mechanics, textures, or fields. The game validates
and may reject the proposal. Match the requested seed exactly."""


class MissingAPIKeyError(RuntimeError):
    pass


class ResponseTooLargeError(ValueError):
    pass


def failure_diagnostic(error):
    """Only fixed labels and numeric HTTP status; never exception text."""
    if isinstance(error, MissingAPIKeyError):
        return {"code": "missing_api_key"}
    if isinstance(error, HTTPError):
        status = error.code
        codes = {400: "meta_bad_request", 401: "meta_unauthorized",
                 403: "meta_forbidden", 404: "meta_not_found", 429: "meta_rate_limited"}
        code = codes.get(status, "meta_http_error")
        if 300 <= status < 400:
            code = "meta_redirect_refused"
        elif 500 <= status < 600:
            code = "meta_unavailable"
        return {"code": code, "upstream_status": status}
    reason = error.reason if isinstance(error, URLError) else error
    if isinstance(reason, TimeoutError):
        return {"code": "meta_timeout"}
    if isinstance(reason, ssl.SSLError):
        return {"code": "meta_tls_error"}
    if isinstance(reason, socket.gaierror):
        return {"code": "meta_dns_error"}
    if isinstance(error, URLError):
        return {"code": "meta_network_error"}
    if isinstance(error, ResponseTooLargeError):
        return {"code": "meta_response_too_large"}
    if isinstance(error, json.JSONDecodeError):
        return {"code": "meta_invalid_json"}
    if isinstance(error, (ValueError, KeyError, TypeError)):
        return {"code": "meta_invalid_response"}
    return {"code": "internal_error"}


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise HTTPError(req.full_url, code, "Redirect refused", headers, fp)


def valid_request(data):
    return (
        isinstance(data, dict)
        and set(data) == {"version", "seed", "attempt"}
        and type(data["version"]) is int and data["version"] == 1
        and type(data["seed"]) is int and -(2**31) <= data["seed"] < 2**31
        and type(data["attempt"]) is int and 0 <= data["attempt"] < 2
    )


def propose(data):
    if not valid_request(data):
        raise ValueError("Invalid request")
    key = os.environ.get("MODEL_API_KEY", "").strip()
    if not key:
        raise MissingAPIKeyError("Meta API key is not configured")
    payload = {
        "model": META_MODEL,
        "messages": [{"role": "developer", "content": CONTEXT},
                     {"role": "user", "content": json.dumps(data)}],
        "reasoning_effort": "low",
        "max_completion_tokens": 8192,
        "response_format": {"type": "json_schema", "json_schema": {
            "name": "steppe_v1", "strict": True, "schema": SCHEMA}},
    }
    request = Request(META_URL, data=json.dumps(payload).encode(), headers={
        "Authorization": "Bearer " + key, "Content-Type": "application/json"}, method="POST")
    # Fixed Meta host, fixed Muse Spark model, no provider override or redirects.
    with build_opener(NoRedirect()).open(request, timeout=UPSTREAM_TIMEOUT_SECONDS) as response:
        body = response.read(MAX_BODY + 1)
    if len(body) > MAX_BODY:
        raise ResponseTooLargeError("Oversized response")
    envelope = json.loads(body)
    if not isinstance(envelope, dict):
        raise ValueError("Expected completion object")
    choices = envelope.get("choices")
    if not isinstance(choices, list) or not choices or not isinstance(choices[0], dict):
        raise ValueError("Expected completion choice")
    choice = choices[0]
    message = choice.get("message")
    if choice.get("finish_reason") != "stop" or not isinstance(message, dict):
        raise ValueError("Completion did not finish normally")
    if message.get("role") != "assistant" or message.get("refusal") or message.get("tool_calls"):
        raise ValueError("Expected assistant proposal")
    content = message.get("content")
    if not isinstance(content, str):
        raise ValueError("Expected text content")
    # Parse JSON only. No markdown extraction, code execution, or state changes.
    proposal = json.loads(content)
    if not isinstance(proposal, dict):
        raise ValueError("Expected proposal object")
    return proposal


class Handler(BaseHTTPRequestHandler):
    def log_message(self, _format, *args):
        pass  # Never log remote text, tokens, headers, or client input.

    def do_POST(self):
        self.connection.settimeout(5)
        if self.path != "/steppe":
            self.reply(404, {"error": "Not found"})
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 1024:
                raise ValueError("Invalid request size")
            data = json.loads(self.rfile.read(size))
            if not valid_request(data):
                raise ValueError("Invalid request")
        except (ValueError, OSError):
            self.reply(400, {"error": "Invalid v1 request"})
            return
        try:
            self.reply(200, propose(data))
        except Exception as error:
            diagnostic = failure_diagnostic(error)
            # Never print the exception, remote body, headers, request, or key.
            print("Meta proposal failed: " + json.dumps(diagnostic), file=sys.stderr, flush=True)
            self.reply(503, {"error": "Meta proposal unavailable", **diagnostic})

    def reply(self, status, body):
        encoded = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        try:
            self.wfile.write(encoded)
        except OSError:
            pass


if __name__ == "__main__":
    print("Meta proposal proxy listening on 127.0.0.1:8787 (credentials stay server-side).")
    ThreadingHTTPServer(("127.0.0.1", 8787), Handler).serve_forever()
