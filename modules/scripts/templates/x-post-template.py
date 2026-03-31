#!/usr/bin/env python3
"""
X/Twitter Official API Poster -- Template
Uses OAuth 1.0a (Free tier: 500 posts/month)

SETUP:
1. Go to https://developer.x.com and create a project/app
2. Generate API Key, API Secret, Access Token, and Access Token Secret
3. Create ~/.config/x-cli/.env with:

    X_API_KEY=your_api_key_here
    X_API_SECRET=your_api_secret_here
    X_ACCESS_TOKEN=your_access_token_here
    X_ACCESS_TOKEN_SECRET=your_access_token_secret_here

4. Install dependencies: pip install tweepy
5. Run: python3 x-post-template.py "Your tweet text"

Usage:
  python3 x-post-template.py "Your tweet text"
  python3 x-post-template.py "Tweet text" --reply-to 1234567890
  python3 x-post-template.py "Thread first tweet" --thread "Second tweet" --thread "Third tweet"
"""

import tweepy
import sys
import os
import json
import argparse
from datetime import datetime
from pathlib import Path

# Load keys from x-cli config
ENV_PATH = os.path.expanduser("~/.config/x-cli/.env")

def load_keys():
    if not os.path.exists(ENV_PATH):
        print(f"ERROR: Config not found at {ENV_PATH}")
        print("Create it with X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN, X_ACCESS_TOKEN_SECRET")
        sys.exit(1)
    keys = {}
    with open(ENV_PATH) as f:
        for line in f:
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                k, v = line.split('=', 1)
                keys[k] = v
    return keys

def get_client():
    keys = load_keys()
    client = tweepy.Client(
        consumer_key=keys['X_API_KEY'],
        consumer_secret=keys['X_API_SECRET'],
        access_token=keys['X_ACCESS_TOKEN'],
        access_token_secret=keys['X_ACCESS_TOKEN_SECRET']
    )
    return client

def post_tweet(text, reply_to=None):
    client = get_client()
    kwargs = {"text": text}
    if reply_to:
        kwargs["in_reply_to_tweet_id"] = reply_to

    response = client.create_tweet(**kwargs)
    tweet_id = response.data['id']
    url = f"https://x.com/i/status/{tweet_id}"
    return tweet_id, url

def post_thread(tweets):
    """Post a thread (list of tweet texts)"""
    results = []
    reply_to = None

    for i, text in enumerate(tweets):
        tweet_id, url = post_tweet(text, reply_to=reply_to)
        results.append({"index": i, "id": tweet_id, "url": url, "text": text[:50] + "..."})
        reply_to = tweet_id
        print(f"[{i+1}/{len(tweets)}] Posted: {url}")

    return results

def main():
    parser = argparse.ArgumentParser(description="Post to X/Twitter via official API")
    parser.add_argument("text", help="Tweet text")
    parser.add_argument("--reply-to", "-r", help="Reply to this tweet ID")
    parser.add_argument("--thread", "-t", action="append", help="Additional tweets for thread (repeatable)")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    try:
        if args.thread:
            # Thread mode
            all_tweets = [args.text] + args.thread
            results = post_thread(all_tweets)
            if args.json:
                print(json.dumps({"ok": True, "thread": results}, indent=2))
            else:
                print(f"\nThread posted ({len(results)} tweets)")
                for r in results:
                    print(f"  {r['url']}")
        else:
            # Single tweet
            tweet_id, url = post_tweet(args.text, reply_to=args.reply_to)
            if args.json:
                print(json.dumps({"ok": True, "id": tweet_id, "url": url}))
            else:
                print(f"Posted: {url}")

        # Log to file
        log_dir = os.path.expanduser("~/.openclaw/workspace/logs")
        os.makedirs(log_dir, exist_ok=True)
        log_path = os.path.join(log_dir, "tweets.log")
        with open(log_path, "a") as f:
            f.write(f"[{datetime.now().isoformat()}] {args.text[:80]}...\n")

    except tweepy.errors.TooManyRequests as e:
        print(json.dumps({"ok": False, "error": "rate_limit", "message": str(e)}))
        sys.exit(1)
    except tweepy.errors.Forbidden as e:
        print(json.dumps({"ok": False, "error": "forbidden", "message": str(e)}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"ok": False, "error": "unknown", "message": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    main()
