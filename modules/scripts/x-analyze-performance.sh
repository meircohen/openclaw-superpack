#!/bin/bash
# Analyze actual performance of recent X posts
# Returns actionable insights for next engagement

set -euo pipefail

TWITTER_CLI="/Users/meircohen/Library/Python/3.9/bin/twitter"

echo "📊 Analyzing recent X performance..."
echo ""

# Get our recent posts (last 5)
$TWITTER_CLI user-posts MeirCohen --max 5 --json > /tmp/recent-posts.json 2>/dev/null || {
    echo "❌ Failed to fetch recent posts"
    exit 1
}

# Analyze with Python
python3 << 'PYTHON'
import json
import sys

try:
    with open('/tmp/recent-posts.json', 'r') as f:
        data = json.load(f)
    
    if not data.get('data'):
        print("No recent posts found")
        sys.exit(1)
    
    posts = data['data'][:5]
    
    print("RECENT PERFORMANCE (Last 5 posts):")
    print("=" * 60)
    
    total_engagement = 0
    best_post = None
    best_score = 0
    
    for i, post in enumerate(posts, 1):
        metrics = post['metrics']
        
        # Engagement score: likes + (replies * 3) + (retweets * 2)
        # Replies/retweets = conversation, more valuable than passive likes
        score = metrics['likes'] + (metrics['replies'] * 3) + (metrics['retweets'] * 2)
        total_engagement += score
        
        if score > best_score:
            best_score = score
            best_post = post
        
        # Extract category from text patterns
        text = post['text'].lower()
        category = "unknown"
        if "we" in text or "our" in text:
            if "agent" in text or "cron" in text:
                category = "technical_war_story"
            elif "$" in text or "btc" in text:
                category = "finance"
        elif any(word in text for word in ["fraud", "security", "monitoring"]):
            category = "crossover_tech"
        
        print(f"\n#{i}: {post['text'][:50]}...")
        print(f"   Engagement: {score} (L:{metrics['likes']} R:{metrics['replies']} RT:{metrics['retweets']} V:{metrics['views']})")
        print(f"   Category: {category}")
    
    print("\n" + "=" * 60)
    print(f"\nBEST PERFORMING POST:")
    print(f"Text: {best_post['text'][:80]}...")
    print(f"Score: {best_score}")
    print(f"Likes: {best_post['metrics']['likes']}")
    print(f"Replies: {best_post['metrics']['replies']}")
    print(f"Retweets: {best_post['metrics']['retweets']}")
    print(f"Views: {best_post['metrics']['views']}")
    
    # Check if it's a reply
    if '@' in best_post['text'][:10]:
        print(f"Type: REPLY (high-reach strategy)")
    else:
        print(f"Type: ORIGINAL POST")
    
    print("\n" + "=" * 60)
    print("RECOMMENDATION:")
    
    avg_engagement = total_engagement / len(posts)
    if best_score > avg_engagement * 2:
        print(f"✅ Best post outperformed average by {int((best_score/avg_engagement - 1) * 100)}%")
        print(f"   Pattern: Look for similar opportunities")
        
        if '@libs' in best_post['text'].lower():
            print(f"   🎯 HIGH-REACH REPLY detected - prioritize similar targets")
        elif 'agent' in best_post['text'].lower():
            print(f"   🔧 TECHNICAL CONTENT resonating - maintain expertise positioning")
    else:
        print(f"⚠️  Performance relatively flat - experiment with new patterns")
    
except Exception as e:
    print(f"Error analyzing performance: {e}")
    sys.exit(1)
PYTHON

echo ""
echo "📈 Use this data for next /x optimization"
