#!/usr/bin/env python3
"""Post to X/Twitter via API. Template -- configure your API keys."""
import sys, os

# Configure these or set as environment variables
API_KEY = os.environ.get("TWITTER_API_KEY", "")
API_SECRET = os.environ.get("TWITTER_API_SECRET", "")
ACCESS_TOKEN = os.environ.get("TWITTER_ACCESS_TOKEN", "")
ACCESS_SECRET = os.environ.get("TWITTER_ACCESS_SECRET", "")

if not all([API_KEY, API_SECRET, ACCESS_TOKEN, ACCESS_SECRET]):
    print("Error: Twitter API credentials not configured.")
    print("Set TWITTER_API_KEY, TWITTER_API_SECRET, TWITTER_ACCESS_TOKEN, TWITTER_ACCESS_SECRET")
    sys.exit(1)

if len(sys.argv) < 2:
    print("Usage: x-post.py 'tweet text'")
    sys.exit(1)

text = sys.argv[1]
print(f"Would post: {text}")
print("(Configure API credentials to enable actual posting)")
