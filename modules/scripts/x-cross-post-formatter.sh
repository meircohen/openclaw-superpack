#!/usr/bin/env bash
# x-cross-post-formatter.sh — Convert a tweet to cross-platform content
# Usage: ./x-cross-post-formatter.sh "tweet text" [--image /path/to/image.jpg] [--json] [--url https://x.com/...]
set -euo pipefail

##############################################################################
# PARSE ARGS
##############################################################################
IMAGE_PATH=""
TWEET_URL=""
JSON_OUTPUT=false
TWEET_TEXT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE_PATH="$2"; shift 2 ;;
    --url) TWEET_URL="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    --help)
      echo "Usage: x-cross-post-formatter.sh \"tweet text\" [--image /path/to/img] [--url URL] [--json]"
      echo ""
      echo "Converts a tweet into formatted versions for TikTok, Instagram, LinkedIn, YouTube Shorts."
      exit 0
      ;;
    *)
      if [[ -z "$TWEET_TEXT" ]]; then
        TWEET_TEXT="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$TWEET_TEXT" ]]; then
  echo "❌ Error: Tweet text is required as first argument" >&2
  echo "Usage: x-cross-post-formatter.sh \"tweet text\" [--image /path/to/img] [--json]" >&2
  exit 1
fi

##############################################################################
# GENERATE ALL PLATFORM VERSIONS
##############################################################################
RESULT=$(TWEET_TEXT="$TWEET_TEXT" IMAGE_PATH="$IMAGE_PATH" TWEET_URL="$TWEET_URL" python3 << 'PYEOF'
import json, re, os

tweet_text = os.environ["TWEET_TEXT"]
image_path = os.environ.get("IMAGE_PATH", "")
tweet_url = os.environ.get("TWEET_URL", "")

text_lower = tweet_text.lower()

# ── Topic detection + platform-specific hashtags ──
topic_hashtags = {
    "ai": {
        "tiktok": "#ai #aitools #artificialintelligence #techtok #aiagent #automation #future",
        "instagram": "#AI #ArtificialIntelligence #AITools #TechFounder #AIAgent #Automation #FutureOfWork #BuildInPublic",
        "linkedin": "#ArtificialIntelligence #AI #AIAgents #Automation #TechLeadership #FutureOfWork",
        "youtube": "#ai #aitools #artificialintelligence #automation #aiagent #tech #shorts",
    },
    "founder": {
        "tiktok": "#founder #startup #entrepreneur #buildinpublic #hustle #ceo #tech",
        "instagram": "#Founder #Startup #Entrepreneur #BuildInPublic #CEO #StartupLife #TechFounder #Hustle",
        "linkedin": "#Entrepreneurship #Startup #BuildInPublic #FounderLife #Leadership #Innovation",
        "youtube": "#founder #startup #entrepreneur #buildinpublic #business #shorts",
    },
    "political": {
        "tiktok": "#politics #news #conservative #truth #america #freedom",
        "instagram": "#Politics #News #Conservative #America #Freedom #Truth #StandUp",
        "linkedin": "#Politics #PublicPolicy #Leadership #CurrentEvents",
        "youtube": "#politics #news #conservative #america #truth #shorts",
    },
    "israel": {
        "tiktok": "#israel #jewish #standwithisrael #truth #am_yisrael_chai",
        "instagram": "#Israel #StandWithIsrael #Jewish #AmYisraelChai #Truth #NeverAgain",
        "linkedin": "#Israel #StandWithIsrael #Leadership #Truth",
        "youtube": "#israel #standwithisrael #jewish #truth #shorts",
    },
    "security": {
        "tiktok": "#cybersecurity #hacking #privacy #techtok #security #data",
        "instagram": "#CyberSecurity #Privacy #Hacking #TechSecurity #DataProtection #InfoSec",
        "linkedin": "#CyberSecurity #Privacy #DataProtection #InfoSec #TechLeadership",
        "youtube": "#cybersecurity #hacking #privacy #security #tech #shorts",
    },
    "general": {
        "tiktok": "#viral #foryou #fyp #trending #truth #knowledge",
        "instagram": "#Viral #Trending #Truth #Knowledge #Wisdom #BuildInPublic",
        "linkedin": "#Leadership #Innovation #BuildInPublic #Growth",
        "youtube": "#viral #trending #truth #knowledge #shorts",
    },
}

if any(w in text_lower for w in ["ai", "agent", "llm", "gpt", "claude", "automation", "openclaw"]):
    topic = "ai"
elif any(w in text_lower for w in ["startup", "founder", "build", "ship", "launch", "revenue", "scale", "company"]):
    topic = "founder"
elif any(w in text_lower for w in ["israel", "jewish", "hamas", "antisemit", "zion"]):
    topic = "israel"
elif any(w in text_lower for w in ["politic", "trump", "biden", "congress", "conservative", "liberal"]):
    topic = "political"
elif any(w in text_lower for w in ["security", "hack", "privacy", "cyber", "breach"]):
    topic = "security"
else:
    topic = "general"

tags = topic_hashtags[topic]

# Clean tweet text (remove t.co links)
clean = re.sub(r'https://t\.co/\S+', '', tweet_text).strip()
clean = re.sub(r'\s+$', '', clean, flags=re.MULTILINE)

# Extract hook (first sentence)
sentences = re.split(r'[.!?\n]', clean)
hook = sentences[0].strip() if sentences else clean[:100]

# ── TikTok: punchy, casual, hook-first ──
tiktok = f"{hook}\n\n{clean}\n\n👉 Follow @meircohen for more\n\n{tags['tiktok']}"

# ── Instagram Reels: polished, emoji-rich, CTA for saves ──
instagram = (
    f"🔥 {clean}\n\n"
    f"💡 Drop a 🔥 if you agree\n"
    f"📌 Save this for later\n"
    f"🔄 Share with someone who needs to see this\n\n"
    f"Follow @meircohen_ for daily insights on AI, tech & building in public 🚀\n\n"
    f"{tags['instagram']}"
)

# ── LinkedIn: professional, storytelling, thought-leadership ──
lines = clean.split('\n')
li_hook = lines[0] if lines else clean[:100]
li_body = '\n'.join(lines[1:]) if len(lines) > 1 else ""

linkedin = (
    f"{li_hook}\n\n"
    f"{li_body}\n\n"
    f"Here's what most people miss:\n\n"
    f"The tools are available to everyone. The execution is what separates winners from watchers.\n\n"
    f"I've been building consumer tech products for 20 years (TrapCall, RoboKiller, SpoofCard, TapeACall).\n\n"
    f"Now I run 55+ AI agents through OpenClaw — and it's changed everything about how I build.\n\n"
    f"What's your take? 👇"
)
if tweet_url:
    linkedin += f"\n\n🔗 Originally posted on X: {tweet_url}"
linkedin += f"\n\n{tags['linkedin']}"

# ── YouTube Shorts: SEO-focused, keyword-rich ──
youtube = (
    f"{hook}\n\n"
    f"{clean}\n\n"
    f"🔔 Subscribe for daily content on AI, tech, and building companies without code.\n\n"
    f"👤 About me: I'm Meir Cohen — serial entrepreneur behind TrapCall, RoboKiller, "
    f"SpoofCard, and TapeACall. Now building the future with 55+ AI agents via OpenClaw.\n\n"
    f"🔗 Follow me:\n"
    f"• X/Twitter: https://x.com/MeirCohen\n"
    f"• OpenClaw: https://github.com/meircohen/openclaw-playbook\n\n"
    f"{tags['youtube']}"
)

result = {
    "original_tweet": tweet_text,
    "topic_detected": topic,
    "image": image_path or None,
    "platforms": {
        "tiktok": {
            "caption": tiktok.strip(),
            "notes": "Post as video with text overlay of the hook. Use trending sound.",
            "char_count": len(tiktok.strip()),
        },
        "instagram_reels": {
            "caption": instagram.strip(),
            "notes": "Use carousel if no video. Text overlay on first slide. Save-bait CTA.",
            "char_count": len(instagram.strip()),
        },
        "linkedin": {
            "post": linkedin.strip(),
            "notes": "Post as text. Add image if available. Best times: Tue-Thu 8-10am ET.",
            "char_count": len(linkedin.strip()),
        },
        "youtube_shorts": {
            "description": youtube.strip(),
            "notes": "Use as description. Title = the hook. Add end screen CTA.",
            "char_count": len(youtube.strip()),
        },
    },
}

print(json.dumps(result, indent=2))
PYEOF
)

##############################################################################
# OUTPUT
##############################################################################
if $JSON_OUTPUT; then
  echo "$RESULT"
else
  echo "$RESULT" | python3 -c "
import json, sys

r = json.load(sys.stdin)
p = r['platforms']

print('━' * 62)
print('📱 CROSS-PLATFORM FORMATTER')
print(f\"   Topic: {r['topic_detected'].upper()} | Image: {r['image'] or 'none'}\")
print('━' * 62)

sections = [
    ('🎵 TIKTOK CAPTION', p['tiktok']['caption'], p['tiktok']),
    ('📸 INSTAGRAM REELS CAPTION', p['instagram_reels']['caption'], p['instagram_reels']),
    ('💼 LINKEDIN POST', p['linkedin']['post'], p['linkedin']),
    ('▶️  YOUTUBE SHORTS DESCRIPTION', p['youtube_shorts']['description'], p['youtube_shorts']),
]

for title, text, meta in sections:
    print()
    print('┌' + '─' * 58)
    print(f'│ {title}')
    print('│' + '─' * 58)
    for line in text.split(chr(10)):
        print(f'│ {line}')
    print(f'│')
    print(f\"│ 📝 {meta['char_count']} chars | {meta['notes']}\")
    print('└' + '─' * 58)

print()
print('━' * 62)
print('  💡 Run with --json to get machine-readable output')
print('  💡 Copy any section above directly into the platform')
print('━' * 62)
"
fi
