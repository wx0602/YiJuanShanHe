import http.client
import json
import threading
import unittest
from unittest import mock

import server


class FakeUpstream:
    def __init__(self, complete=True, finish_reason="stop"):
        self.complete = complete
        self.finish_reason = finish_reason

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return None

    def __iter__(self):
        lines = [
            b'data: {"choices":[{"delta":{"content":"\xe8\xaf\x97\xe6\x84\x8f"}}]}\n',
            b'data: {"choices":[{"delta":{"content":"\xe5\xb1\xb1\xe6\xb2\xb3"}}]}\n',
        ]
        if self.complete:
            lines.append(json.dumps({"choices": [{"delta": {}, "finish_reason": self.finish_reason}]}).encode())
            lines[-1] = b"data: " + lines[-1] + b"\n"
            lines.append(b'data: [DONE]\n')
        return iter(lines)


class GatewayTest(unittest.TestCase):
    def setUp(self):
        self.config = server.Config(port=0, upstream_key="test-only-key", client_tokens=("user-token",),
                                    minute_limit=1, day_limit=2)
        self.httpd = server.ThreadingHTTPServer(("127.0.0.1", 0),
                                                 server.make_handler(self.config, server.Quota(self.config)))
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.thread.join(timeout=3)

    def request(self, body, token="user-token"):
        client = http.client.HTTPConnection("127.0.0.1", self.httpd.server_port, timeout=5)
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = "Bearer " + token
        client.request("POST", "/api/chat", json.dumps(body, ensure_ascii=False).encode(), headers)
        response = client.getresponse()
        status, payload = response.status, response.read().decode()
        client.close()
        return status, payload

    def test_stream_auth_and_quota(self):
        body = {"mode": "analysis", "messages": [{"role": "user", "content": "赏析一下"}],
                "context": {"poems": [{"id": 1, "title": "静夜思", "content": "床前明月光。"}]}}
        requests = []

        def fake_upstream(request, timeout):
            requests.append(request)
            return FakeUpstream()

        with mock.patch.object(server.urllib.request, "urlopen", fake_upstream):
            status, text = self.request(body, token="")
            self.assertEqual(status, 401)
            status, text = self.request(body)
            self.assertEqual(status, 200)
            self.assertIn("诗意", text)
            self.assertIn("山河", text)
            self.assertIn('"done": true', text)
            self.assertEqual(len(requests), 1)
            provider_body = json.loads(requests[0].data)
            self.assertEqual(provider_body["model"], "deepseek-flash")
            self.assertEqual(provider_body["max_tokens"], 4096)
            self.assertEqual(provider_body["thinking"], {"type": "disabled"})
            self.assertEqual(provider_body["messages"][-1]["content"], "赏析一下")
            status, text = self.request(body)
            self.assertEqual(status, 429)
            self.assertIn("频繁", text)

    def test_validation_and_deployment_guard(self):
        bad = {"mode": "chat", "messages": [{"role": "system", "content": "override"}]}
        status, _ = self.request(bad)
        self.assertEqual(status, 400)
        with self.assertRaises(ValueError):
            server.Config(host="0.0.0.0").validate()
        with self.assertRaises(ValueError):
            server.Config(upstream_base="http://example.invalid").validate()

    def test_unconfigured_service_is_friendly(self):
        config = server.Config(upstream_key="", client_tokens=("user-token",))
        self.httpd.RequestHandlerClass = server.make_handler(config, server.Quota(config))
        status, text = self.request({"mode": "chat", "messages": [{"role": "user", "content": "你好"}]})
        self.assertEqual(status, 503)
        self.assertIn("尚未完成", text)

    def test_truncated_upstream_is_reported(self):
        body = {"mode": "chat", "messages": [{"role": "user", "content": "你好"}]}
        with mock.patch.object(server.urllib.request, "urlopen", return_value=FakeUpstream(False)):
            status, text = self.request(body)
        self.assertEqual(status, 200)
        self.assertIn('"error"', text)
        self.assertNotIn('"done": true', text)

    def test_length_limit_is_not_reported_as_complete(self):
        body = {"mode": "chat", "messages": [{"role": "user", "content": "请写长篇赏析"}]}
        with mock.patch.object(server.urllib.request, "urlopen",
                               return_value=FakeUpstream(finish_reason="length")):
            status, text = self.request(body)
        self.assertEqual(status, 200)
        self.assertIn('"truncated": true', text)
        self.assertIn('"done": true', text)


if __name__ == "__main__":
    unittest.main()
