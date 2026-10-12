#!/usr/bin/env python3
"""Minimal, privacy-conscious Ark Responses proxy for LingXiu.

The service deliberately accepts only the subset of the Responses API used by
the iOS app. It fixes the model server-side, disables Ark response storage,
rejects remote image URLs, limits request sizes, and never logs request bodies
or credentials.
"""

from __future__ import annotations

import hmac
import json
import os
import threading
import time
import urllib.error
import urllib.request
from collections import defaultdict, deque
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


ARK_API_KEY = os.environ.get("ARK_API_KEY", "").strip()
ARK_MODEL_ID = os.environ.get("ARK_MODEL_ID", "doubao-seed-evolving").strip()
ARK_RESPONSES_URL = os.environ.get(
    "ARK_RESPONSES_URL",
    "https://ark.cn-beijing.volces.com/api/v3/responses",
).strip()
LINGXIU_PROXY_TOKEN = os.environ.get("LINGXIU_PROXY_TOKEN", "").strip()

LISTEN_HOST = os.environ.get("LINGXIU_LISTEN_HOST", "127.0.0.1")
LISTEN_PORT = int(os.environ.get("LINGXIU_LISTEN_PORT", "8080"))
MAX_BODY_BYTES = int(os.environ.get("LINGXIU_MAX_BODY_BYTES", str(20 * 1024 * 1024)))
RATE_LIMIT_PER_MINUTE = int(os.environ.get("LINGXIU_RATE_LIMIT_PER_MINUTE", "30"))

_rate_lock = threading.Lock()
_request_times: dict[str, deque[float]] = defaultdict(deque)


def _json_bytes(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def _client_ip(handler: BaseHTTPRequestHandler) -> str:
    # The service binds to loopback and trusts X-Real-IP only from local nginx.
    return handler.headers.get("X-Real-IP", handler.client_address[0]).strip()


def _within_rate_limit(client_ip: str) -> bool:
    now = time.monotonic()
    threshold = now - 60
    with _rate_lock:
        entries = _request_times[client_ip]
        while entries and entries[0] < threshold:
            entries.popleft()
        if len(entries) >= RATE_LIMIT_PER_MINUTE:
            return False
        entries.append(now)
        return True


def _validated_input(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list) or len(value) != 1:
        raise ValueError("input must contain exactly one user message")

    message = value[0]
    if not isinstance(message, dict) or message.get("role") != "user":
        raise ValueError("only a user message is allowed")

    content = message.get("content")
    if not isinstance(content, list) or not 1 <= len(content) <= 4:
        raise ValueError("content must contain one text item and up to three images")

    text_count = 0
    image_count = 0
    validated_content: list[dict[str, str]] = []
    for item in content:
        if not isinstance(item, dict):
            raise ValueError("invalid content item")

        item_type = item.get("type")
        if item_type == "input_text":
            text = item.get("text")
            if not isinstance(text, str) or not text.strip() or len(text) > 24_000:
                raise ValueError("invalid text input")
            text_count += 1
            validated_content.append({"type": "input_text", "text": text})
        elif item_type == "input_image":
            image_url = item.get("image_url")
            if not isinstance(image_url, str) or not image_url.startswith("data:image/"):
                raise ValueError("only inline image data is allowed")
            image_count += 1
            validated_content.append({"type": "input_image", "image_url": image_url})
        else:
            raise ValueError("unsupported content type")

    if text_count != 1 or image_count > 3:
        raise ValueError("one text item and at most three images are required")
    return [{"role": "user", "content": validated_content}]


class LingXiuProxyHandler(BaseHTTPRequestHandler):
    server_version = "LingXiuAPI/1.0"
    sys_version = ""

    def log_message(self, format: str, *args: Any) -> None:
        # Record only method/path/status metadata from BaseHTTPRequestHandler.
        # Request bodies, headers, upstream payloads and credentials are never logged.
        super().log_message(format, *args)

    def _send_json(self, status: HTTPStatus | int, payload: Any) -> None:
        body = _json_bytes(payload)
        self.send_response(int(status))
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        if self.path in {"/health", "/healthz"}:
            self._send_json(
                HTTPStatus.OK,
                {
                    "status": "ok",
                    "api_version": "v1",
                    "ark_configured": bool(ARK_API_KEY),
                    "model": ARK_MODEL_ID,
                },
            )
            return
        self._send_json(HTTPStatus.NOT_FOUND, {"error": {"code": "NotFound"}})

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/v1/responses":
            self._send_json(HTTPStatus.NOT_FOUND, {"error": {"code": "NotFound"}})
            return

        supplied_token = self.headers.get("X-LingXiu-Proxy-Token", "")
        if not LINGXIU_PROXY_TOKEN or not hmac.compare_digest(
            supplied_token.encode("utf-8"),
            LINGXIU_PROXY_TOKEN.encode("utf-8"),
        ):
            self._send_json(HTTPStatus.UNAUTHORIZED, {"error": {"code": "Unauthorized"}})
            return

        client_ip = _client_ip(self)
        if not _within_rate_limit(client_ip):
            self._send_json(HTTPStatus.TOO_MANY_REQUESTS, {"error": {"code": "RateLimited"}})
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            content_length = 0
        if content_length <= 0 or content_length > MAX_BODY_BYTES:
            self._send_json(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, {"error": {"code": "BodyTooLarge"}})
            return

        try:
            request_object = json.loads(self.rfile.read(content_length))
            upstream_input = _validated_input(request_object.get("input"))
        except (json.JSONDecodeError, UnicodeDecodeError, ValueError) as error:
            self._send_json(
                HTTPStatus.BAD_REQUEST,
                {"error": {"code": "InvalidRequest", "message": str(error)}},
            )
            return

        if not ARK_API_KEY:
            self._send_json(
                HTTPStatus.SERVICE_UNAVAILABLE,
                {"error": {"code": "ArkNotConfigured"}},
            )
            return

        upstream_body = _json_bytes(
            {
                "model": ARK_MODEL_ID,
                "input": upstream_input,
                "store": False,
                "max_output_tokens": min(
                    max(int(request_object.get("max_output_tokens", 4096)), 256),
                    4096,
                ),
            }
        )
        upstream_request = urllib.request.Request(
            ARK_RESPONSES_URL,
            data=upstream_body,
            method="POST",
            headers={
                "Authorization": f"Bearer {ARK_API_KEY}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )

        try:
            with urllib.request.urlopen(upstream_request, timeout=100) as response:
                response_body = response.read()
                status = response.status
        except urllib.error.HTTPError as error:
            response_body = error.read()
            status = error.code
        except (urllib.error.URLError, TimeoutError):
            self._send_json(
                HTTPStatus.BAD_GATEWAY,
                {"error": {"code": "ArkUnavailable"}},
            )
            return

        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(response_body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(response_body)


def main() -> None:
    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), LingXiuProxyHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
