"""No live AI: verify fixed Meta routing, redaction, and schema request shape."""
import io
import json
import os
import socket
import ssl
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError

from server import meta_proxy as proxy


class Response(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()


class ProxyTests(unittest.TestCase):
    def test_request_boundary(self):
        self.assertTrue(proxy.valid_request({"version": 1, "seed": -42, "attempt": 1}))
        for data in [None, [], {}, {"version": True, "seed": 42, "attempt": 0},
                     {"version": 1, "seed": 2**31, "attempt": 0},
                     {"version": 1, "seed": 42, "attempt": 2},
                     {"version": 1, "seed": 42, "attempt": 0, "model": "other"}]:
            self.assertFalse(proxy.valid_request(data))

    @patch.dict(os.environ, {}, clear=True)
    def test_missing_key_does_not_call_network(self):
        with patch.object(proxy, "build_opener") as opener:
            with self.assertRaises(RuntimeError):
                proxy.propose({"version": 1, "seed": 42, "attempt": 0})
            opener.assert_not_called()

    @staticmethod
    def completion(content='{"version": 1}', finish_reason="stop", **message_fields):
        return {"choices": [{"finish_reason": finish_reason, "message": {
            "role": "assistant", "content": content, **message_fields}}]}

    @patch.dict(os.environ, {"MODEL_API_KEY": "test-server-only-secret"}, clear=True)
    def test_muse_request_and_completion_shape(self):
        with patch.object(proxy, "build_opener") as opener:
            opener.return_value.open.return_value = Response(json.dumps(self.completion()).encode())
            self.assertEqual(proxy.propose({"version": 1, "seed": 42, "attempt": 0}), {"version": 1})
            request = opener.return_value.open.call_args.args[0]
            self.assertEqual(request.full_url, "https://api.meta.ai/v1/chat/completions")
            self.assertEqual(request.get_header("Authorization"), "Bearer test-server-only-secret")
            payload = json.loads(request.data)
            self.assertEqual(payload["model"], "muse-spark-1.3")
            self.assertEqual(payload["messages"][0]["role"], "developer")
            self.assertEqual(payload["response_format"]["json_schema"]["schema"], proxy.SCHEMA)
            self.assertTrue(payload["response_format"]["json_schema"]["strict"])
            self.assertEqual(payload["reasoning_effort"], "low")
            self.assertNotIn("temperature", payload)
            self.assertNotIn("test-server-only-secret", json.dumps(payload))
            self.assertEqual(opener.return_value.open.call_args.kwargs["timeout"], 60)

    @patch.dict(os.environ, {"LLAMA_API_KEY": "old-endpoint-secret"}, clear=True)
    def test_old_key_variable_is_not_sent_to_new_endpoint(self):
        with patch.object(proxy, "build_opener") as opener:
            with self.assertRaises(proxy.MissingAPIKeyError):
                proxy.propose({"version": 1, "seed": 42, "attempt": 0})
            opener.assert_not_called()

    @patch.dict(os.environ, {"MODEL_API_KEY": "test-server-only-secret"}, clear=True)
    def test_malformed_and_oversized_upstream_rejected(self):
        bodies = [b"not JSON", b"{}", b"x" * 65537,
                  b'{"completion_message":{"content":"{}"}}']
        completions = [[], {"choices": []}, {"choices": [None]},
                       self.completion(None), self.completion([]), self.completion("[]"),
                       self.completion("not JSON"), self.completion(finish_reason="length"),
                       self.completion(finish_reason="content_filter"),
                       self.completion(refusal="Cannot comply"),
                       self.completion(tool_calls=[{"function": "untrusted"}]),
                       self.completion(role="user")]
        bodies.extend(json.dumps(value).encode() for value in completions)
        for body in bodies:
            with self.subTest(body_length=len(body)), patch.object(proxy, "build_opener") as opener:
                opener.return_value.open.return_value = Response(body)
                with self.assertRaises(ValueError):
                    proxy.propose({"version": 1, "seed": 42, "attempt": 0})

    def test_redirects_cannot_forward_credentials(self):
        with self.assertRaises(HTTPError):
            proxy.NoRedirect().redirect_request(proxy.Request(proxy.META_URL), None, 302,
                                                "Moved", {}, "https://other.invalid")

    def test_handler_redacts_upstream_exception(self):
        handler = object.__new__(proxy.Handler)
        handler.path = "/steppe"
        body = b'{"version":1,"seed":42,"attempt":0}'
        handler.headers = {"Content-Length": str(len(body))}
        handler.rfile = io.BytesIO(body)
        with patch.object(handler, "connection", create=True), patch.object(handler, "reply") as reply:
            with patch.object(proxy, "propose", side_effect=RuntimeError("secret upstream details")):
                with patch("sys.stderr", new_callable=io.StringIO) as log:
                    handler.do_POST()
                    self.assertNotIn("secret upstream details", log.getvalue())
                    self.assertIn("internal_error", log.getvalue())
            reply.assert_called_once_with(503, {"error": "Meta proposal unavailable", "code": "internal_error"})

    def test_safe_failure_categories(self):
        cases = [
            (proxy.MissingAPIKeyError("secret"), "missing_api_key"),
            (TimeoutError("secret"), "meta_timeout"),
            (URLError(TimeoutError("secret")), "meta_timeout"),
            (URLError(ssl.SSLError("secret")), "meta_tls_error"),
            (URLError(socket.gaierror("secret")), "meta_dns_error"),
            (URLError("secret"), "meta_network_error"),
            (proxy.ResponseTooLargeError("secret"), "meta_response_too_large"),
            (json.JSONDecodeError("secret", "secret response", 0), "meta_invalid_json"),
            (KeyError("secret"), "meta_invalid_response"),
            (RuntimeError("secret"), "internal_error"),
        ]
        for error, code in cases:
            with self.subTest(code=code):
                diagnostic = proxy.failure_diagnostic(error)
                self.assertEqual(diagnostic, {"code": code})
                self.assertNotIn("secret", json.dumps(diagnostic))

    def test_http_failures_expose_only_status_and_fixed_code(self):
        for status, code in [(302, "meta_redirect_refused"), (400, "meta_bad_request"),
                             (401, "meta_unauthorized"), (403, "meta_forbidden"),
                             (404, "meta_not_found"), (429, "meta_rate_limited"),
                             (500, "meta_unavailable"), (418, "meta_http_error")]:
            error = HTTPError("https://secret.invalid", status, "secret", {"secret": "token"}, None)
            self.assertEqual(proxy.failure_diagnostic(error), {"code": code, "upstream_status": status})


if __name__ == "__main__":
    unittest.main()
