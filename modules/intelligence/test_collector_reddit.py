import sys
import time
import unittest
from pathlib import Path
from unittest.mock import patch

import httpx

sys.path.insert(0, str(Path(__file__).parent))

import collector


class FakeResponse:
    def __init__(self, url: str, *, status_code: int = 200, json_data=None, content: bytes = b""):
        self.url = url
        self.status_code = status_code
        self._json_data = json_data
        self.content = content

    def raise_for_status(self):
        if self.status_code >= 400:
            request = httpx.Request("GET", self.url)
            response = httpx.Response(self.status_code, request=request)
            raise httpx.HTTPStatusError(f"{self.status_code} from {self.url}", request=request, response=response)

    def json(self):
        return self._json_data


class FakeClient:
    def __init__(self, responses):
        self.responses = responses
        self.calls = []

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def get(self, url, **kwargs):
        self.calls.append(("GET", url, kwargs))
        for prefix, response in self.responses:
            if url.startswith(prefix):
                return response(url)
        raise AssertionError(f"Unexpected GET {url}")

    def post(self, url, **kwargs):
        self.calls.append(("POST", url, kwargs))
        raise AssertionError(f"Unexpected POST {url}")


class RedditCollectorTests(unittest.TestCase):
    def test_collect_reddit_accepts_config_dict_and_uses_old_reddit_json(self):
        listing = {
            "data": {
                "children": [
                    {
                        "data": {
                            "permalink": "/r/LocalLLaMA/comments/abc123/test_post/",
                            "title": "MCP agents land on LocalLLaMA",
                            "score": 150,
                            "selftext": "tool use and Claude discussion",
                            "created_utc": time.time(),
                        }
                    }
                ]
            }
        }
        fake_client = FakeClient(
            responses=[
                ("https://old.reddit.com/", lambda url: FakeResponse(url, json_data=listing)),
            ]
        )

        with patch.object(collector.httpx, "Client", return_value=fake_client), \
             patch.object(collector, "load_seen", return_value={}), \
             patch.object(collector, "save_item", return_value=True), \
             patch.object(collector, "update_status"):
            items = collector.collect_reddit("reddit_localllama", {"subreddit": "LocalLLaMA"})

        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["raw_score"], 150)
        self.assertTrue(fake_client.calls[0][1].startswith("https://old.reddit.com/r/LocalLLaMA/hot/.json"))
        self.assertEqual(fake_client.calls[0][2]["headers"]["User-Agent"], collector.REDDIT_USER_AGENT)

    def test_collect_reddit_falls_back_to_rss_when_json_is_blocked(self):
        rss_feed = b"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>r/LocalLLaMA</title>
    <item>
      <title>Claude tool use thread</title>
      <link>https://www.reddit.com/r/LocalLLaMA/comments/xyz987/test_post/</link>
      <pubDate>Tue, 31 Mar 2026 10:00:00 GMT</pubDate>
      <description>LLM agents and tooling</description>
    </item>
  </channel>
</rss>
"""
        fake_client = FakeClient(
            responses=[
                ("https://old.reddit.com/", lambda url: FakeResponse(url, status_code=403)),
                ("https://www.reddit.com/r/LocalLLaMA/.rss", lambda url: FakeResponse(url, content=rss_feed)),
            ]
        )

        with patch.object(collector.httpx, "Client", return_value=fake_client), \
             patch.object(collector, "load_seen", return_value={}), \
             patch.object(collector, "save_item", return_value=True), \
             patch.object(collector, "update_status"), \
             patch.object(collector, "_load_reddit_credentials", return_value={}):
            items = collector.collect_reddit("reddit_localllama", {"subreddit": "LocalLLaMA"})

        self.assertEqual(len(items), 1)
        self.assertEqual(fake_client.calls[1][1], "https://www.reddit.com/r/LocalLLaMA/.rss")


if __name__ == "__main__":
    unittest.main()
