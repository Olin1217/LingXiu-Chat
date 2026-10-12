import json
import pathlib
import sys
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer


SERVER_ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER_ROOT))

import lingxiu_proxy as proxy  # noqa: E402


class LingXiuProxyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        proxy.ARK_API_KEY = "configured-for-test"
        proxy.ARK_MODEL_ID = "test-model"
        proxy.LINGXIU_PROXY_TOKEN = "test-proxy-token"
        proxy._request_times.clear()
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), proxy.LingXiuProxyHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base_url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def test_health_aliases_report_version_without_credentials(self) -> None:
        for path in ("/health", "/healthz"):
            with urllib.request.urlopen(f"{self.base_url}{path}", timeout=2) as response:
                payload = json.load(response)
            self.assertEqual(payload["status"], "ok")
            self.assertEqual(payload["api_version"], "v1")
            self.assertTrue(payload["ark_configured"])
            self.assertNotIn("api_key", payload)

    def test_responses_rejects_missing_proxy_token_before_parsing_body(self) -> None:
        request = urllib.request.Request(
            f"{self.base_url}/v1/responses",
            data=b"{}",
            method="POST",
            headers={"Content-Type": "application/json"},
        )
        with self.assertRaises(urllib.error.HTTPError) as context:
            urllib.request.urlopen(request, timeout=2)
        self.assertEqual(context.exception.code, 401)
        payload = json.load(context.exception)
        self.assertEqual(payload["error"]["code"], "Unauthorized")

    def test_responses_rejects_non_whitelisted_input(self) -> None:
        request = urllib.request.Request(
            f"{self.base_url}/v1/responses",
            data=json.dumps({"input": []}).encode("utf-8"),
            method="POST",
            headers={
                "Content-Type": "application/json",
                "X-LingXiu-Proxy-Token": "test-proxy-token",
            },
        )
        with self.assertRaises(urllib.error.HTTPError) as context:
            urllib.request.urlopen(request, timeout=2)
        self.assertEqual(context.exception.code, 400)
        payload = json.load(context.exception)
        self.assertEqual(payload["error"]["code"], "InvalidRequest")

    def test_input_validator_allows_one_text_and_up_to_three_inline_images(self) -> None:
        validated = proxy._validated_input(
            [
                {
                    "role": "user",
                    "content": [
                        {"type": "input_text", "text": "测试"},
                        {"type": "input_image", "image_url": "data:image/png;base64,AA=="},
                    ],
                }
            ]
        )
        self.assertEqual(validated[0]["role"], "user")
        self.assertEqual(len(validated[0]["content"]), 2)

    def test_input_validator_rejects_remote_image_urls(self) -> None:
        with self.assertRaises(ValueError):
            proxy._validated_input(
                [
                    {
                        "role": "user",
                        "content": [
                            {"type": "input_text", "text": "测试"},
                            {"type": "input_image", "image_url": "https://example.com/a.png"},
                        ],
                    }
                ]
            )


if __name__ == "__main__":
    unittest.main()
