import json
import os
import threading
import unittest
import urllib.error
import urllib.request

import app as application


class AppTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ["DEPLOY_COLOR"] = "green"
        os.environ["APP_VERSION"] = "2.3.4"
        cls.server = application.make_server("127.0.0.1", 0)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        port = cls.server.server_address[1]
        cls.base = f"http://127.0.0.1:{port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.thread.join(timeout=3)

    def _get(self, path: str):
        with urllib.request.urlopen(self.base + path, timeout=2) as response:
            body = response.read()
            return response.status, response.headers.get("Content-Type", ""), body

    def test_health(self):
        status, content_type, body = self._get("/health")
        self.assertEqual(status, 200)
        self.assertIn("application/json", content_type)
        self.assertEqual(json.loads(body), {"status": "ok"})

    def test_version_reports_the_process_identity(self):
        status, _, body = self._get("/version")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body), {"color": "green", "version": "2.3.4"})

    def test_metrics_are_prometheus_text(self):
        status, content_type, body = self._get("/metrics")
        text = body.decode()
        self.assertEqual(status, 200)
        self.assertIn("text/plain", content_type)
        self.assertIn('app_requests_total{color="green",version="2.3.4"}', text)
        self.assertIn('app_info{color="green",version="2.3.4"} 1', text)

    def test_unknown_path_is_not_found(self):
        with self.assertRaises(urllib.error.HTTPError) as raised:
            urllib.request.urlopen(self.base + "/missing", timeout=2)
        self.assertEqual(raised.exception.code, 404)


if __name__ == "__main__":
    unittest.main()
