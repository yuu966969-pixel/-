import os
import unittest
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

import main


class FakeUpstreamResponse:
    def __init__(self, status_code=200, content=b"\x00" * 12000):
        self.status_code = status_code
        self.content = content


class FakeAsyncClient:
    calls = []
    response = FakeUpstreamResponse()

    def __init__(self, *args, **kwargs):
        self.options = kwargs

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def post(self, url, **kwargs):
        self.__class__.calls.append((url, kwargs))
        return self.__class__.response


class MusicAPITests(unittest.TestCase):
    def setUp(self):
        FakeAsyncClient.calls = []
        FakeAsyncClient.response = FakeUpstreamResponse()
        self.rate_limit_patch = patch.object(main, "enforce_rate_limit", new=AsyncMock())
        self.rate_limit_patch.start()
        self.addCleanup(self.rate_limit_patch.stop)
        self.client = TestClient(main.app)

    def test_health_does_not_expose_api_key(self):
        with patch.dict(os.environ, {"STABILITY_API_KEY": "test-secret"}):
            response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["configured"])
        self.assertNotIn("test-secret", response.text)

    def test_generate_returns_mp3_and_uses_multipart_api(self):
        with patch.dict(os.environ, {"STABILITY_API_KEY": "test-secret", "STABILITY_MODEL": "stable-audio-2.5"}):
            with patch("main.httpx.AsyncClient", FakeAsyncClient):
                response = self.client.post("/api/generate", json={
                    "date": "2026-11-20",
                    "prompt": "Bright cheerful electronic music with playful bells",
                    "format": "mp3",
                    "mode": "custom"
                })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["content-type"], "audio/mpeg")
        self.assertEqual(len(response.content), 12000)
        self.assertEqual(len(FakeAsyncClient.calls), 1)
        url, kwargs = FakeAsyncClient.calls[0]
        self.assertEqual(url, "https://api.stability.ai/v2beta/audio/stable-audio-2/text-to-audio")
        self.assertEqual(kwargs["headers"]["Authorization"], "Bearer test-secret")
        self.assertEqual(kwargs["data"]["model"], "stable-audio-2.5")
        self.assertEqual(kwargs["data"]["duration"], "20")
        self.assertEqual(kwargs["data"]["output_format"], "mp3")
        self.assertIn("none", kwargs["files"])

    def test_missing_api_key_returns_503(self):
        with patch.dict(os.environ, {"STABILITY_API_KEY": ""}):
            response = self.client.post("/api/generate", json={
                "date": "2026-11-20", "prompt": "A calm piano tune", "format": "mp3", "mode": "custom"
            })
        self.assertEqual(response.status_code, 503)

    def test_invalid_format_is_rejected(self):
        with patch.dict(os.environ, {"STABILITY_API_KEY": "test-secret"}):
            response = self.client.post("/api/generate", json={
                "date": "2026-11-20", "prompt": "A calm piano tune", "format": "wav", "mode": "custom"
            })
        self.assertEqual(response.status_code, 400)
        self.assertEqual(FakeAsyncClient.calls, [])

    def test_provider_credit_error_is_reported(self):
        FakeAsyncClient.response = FakeUpstreamResponse(status_code=402, content=b"")
        with patch.dict(os.environ, {"STABILITY_API_KEY": "test-secret"}):
            with patch("main.httpx.AsyncClient", FakeAsyncClient):
                response = self.client.post("/api/generate", json={
                    "date": "2026-11-20", "prompt": "A calm piano tune", "format": "mp3", "mode": "custom"
                })
        self.assertEqual(response.status_code, 402)


if __name__ == "__main__":
    unittest.main()
