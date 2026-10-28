"""No live AI: verify fixed Meta routing, redaction, and schema request shape."""
import io
import json
import os
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

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

    @patch.dict(os.environ, {"LLAMA_API_KEY": "test-server-only-secret"}, clear=True)
    def test_meta_request_and_both_official_content_shapes(self):
        for content in ['{"version": 1}', {"type": "text", "text": '{"version": 1}'}]:
            with patch.object(proxy, "build_opener") as opener:
                opener.return_value.open.return_value = Response(json.dumps({
                    "completion_message": {"content": content}}).encode())
                self.assertEqual(proxy.propose({"version": 1, "seed": 42, "attempt": 0}), {"version": 1})
                request = opener.return_value.open.call_args.args[0]
                self.assertEqual(request.full_url, "https://api.llama.com/v1/chat/completions")
                payload = json.loads(request.data)
                self.assertEqual(payload["model"], proxy.META_MODEL)
                self.assertEqual(payload["response_format"]["json_schema"]["schema"], proxy.SCHEMA)
                self.assertNotIn("test-server-only-secret", json.dumps(payload))
                self.assertEqual(opener.return_value.open.call_args.kwargs["timeout"], 20)

    @patch.dict(os.environ, {"LLAMA_API_KEY": "test-server-only-secret"}, clear=True)
    def test_malformed_and_oversized_upstream_rejected(self):
        for body in [b"not JSON", b"{}", b"x" * 65537,
                     b'{"completion_message":{"content":null}}']:
            with patch.object(proxy, "build_opener") as opener:
                opener.return_value.open.return_value = Response(body)
                with self.assertRaises((ValueError, KeyError)):
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
                handler.do_POST()
            reply.assert_called_once_with(503, {"error": "Meta proposal unavailable"})


if __name__ == "__main__":
    unittest.main()
