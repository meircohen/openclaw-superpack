#!/bin/bash
# autoresearch-cloud.sh — Launch autoresearch on a cloud GPU from your Mac
# Usage: bash scripts/autoresearch-cloud.sh [provider]
# Providers: vast (cheapest), runpod, lambda

set -e

PROVIDER="${1:-vast}"
REPO_URL="https://github.com/karpathy/autoresearch.git"
WORK_DIR="$HOME/autoresearch-remote"

echo "============================================"
echo "🧪 Autoresearch Cloud Launcher"
echo "   Provider: $PROVIDER"
echo "============================================"

case "$PROVIDER" in
  vast)
    echo ""
    echo "📋 VAST.AI SETUP (cheapest: ~\$1.33-1.67/hr for H100)"
    echo ""
    echo "1. Go to: https://vast.ai"
    echo "2. Create account + add credits (\$25 is enough for overnight)"
    echo "3. Install CLI:"
    echo "   pip install vastai"
    echo ""
    echo "4. Set API key:"
    echo "   vastai set api-key YOUR_KEY"
    echo ""
    echo "5. Find a cheap H100 (or A100 for even cheaper):"
    echo "   vastai search offers 'gpu_name=H100_SXM reliability>0.95 num_gpus=1' -o 'dph'"
    echo ""
    echo "6. Rent the cheapest one (note the ID):"
    echo "   vastai create instance ID --image pytorch/pytorch:2.5.1-cuda12.4-cudnn9-devel --disk 50"
    echo ""
    echo "7. SSH in:"
    echo "   vastai ssh-url ID"
    echo ""
    echo "8. Run the setup inside the instance:"
    cat << 'REMOTE_SETUP'

    # === RUN THESE ON THE REMOTE GPU ===
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.local/bin/env
    git clone https://github.com/karpathy/autoresearch.git
    cd autoresearch
    uv sync
    uv run prepare.py
    
    # Verify GPU works
    uv run train.py
    
    # Now launch Claude Code or Codex:
    # Option A: Claude Code
    curl -fsSL https://claude.ai/install.sh | sh
    claude
    # Say: "Read program.md and start the autoresearch loop"
    
    # Option B: Codex
    npm install -g @openai/codex
    codex --model o4-mini
    # Say: "Read program.md and start the autoresearch loop"
    
    # Option C: Run via API (headless, no interactive agent needed)
    # See scripts/autoresearch-headless.sh

REMOTE_SETUP
    echo ""
    echo "9. Detach (keeps running): Ctrl+A, D (if using screen/tmux)"
    echo "10. Check results anytime: ssh in and 'cat results.tsv'"
    echo "11. When done: vastai destroy instance ID"
    ;;

  runpod)
    echo ""
    echo "📋 RUNPOD SETUP (~\$2.69/hr for H100)"
    echo ""
    echo "1. Go to: https://runpod.io"
    echo "2. Create account + add credits"
    echo "3. Deploy a GPU Pod:"
    echo "   - Template: PyTorch (latest)"
    echo "   - GPU: H100 SXM (or A100 80GB for cheaper)"
    echo "   - Volume: 50GB"
    echo "4. Connect via SSH or web terminal"
    echo "5. Run the same setup commands as above"
    ;;

  lambda)
    echo ""
    echo "📋 LAMBDA LABS SETUP (~\$2-3/hr for H100)"
    echo ""
    echo "1. Go to: https://lambdalabs.com/cloud"
    echo "2. Create account + add payment"
    echo "3. Launch instance: 1x H100 (or A100)"
    echo "4. SSH in with provided key"
    echo "5. Run the same setup commands as above"
    ;;

  *)
    echo "Unknown provider: $PROVIDER"
    echo "Use: vast, runpod, or lambda"
    exit 1
    ;;
esac

echo ""
echo "============================================"
echo "💰 COST ESTIMATE"
echo "============================================"
echo ""
echo "  Vast.ai H100:    ~\$1.67/hr  → 8hr overnight = ~\$13"
echo "  Vast.ai A100:    ~\$0.67/hr  → 8hr overnight = ~\$5"
echo "  RunPod H100:     ~\$2.69/hr  → 8hr overnight = ~\$22"
echo "  Hyperstack H100: ~\$2.40/hr  → 8hr overnight = ~\$19"
echo "  Lambda H100:     ~\$2.50/hr  → 8hr overnight = ~\$20"
echo ""
echo "  Expected: ~100 experiments overnight (12/hr × 8hr)"
echo "  Karpathy's result: 11% improvement in training speed"
echo ""
echo "============================================"
echo "🔧 QUICK START (copy-paste into remote GPU)"
echo "============================================"
echo ""
echo '  curl -LsSf https://astral.sh/uv/install.sh | sh && source $HOME/.local/bin/env'
echo '  git clone https://github.com/karpathy/autoresearch.git && cd autoresearch'
echo '  uv sync && uv run prepare.py && uv run train.py'
echo '  # Then launch your agent (claude / codex) and say:'
echo '  # "Read program.md and start the autoresearch loop"'
