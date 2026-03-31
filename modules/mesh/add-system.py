#!/usr/bin/env python3
"""
Single Command Setup — Add a new system to the AI mesh.

Generates config YAML, tests connectivity, updates MESH.md, and adds to router.

Usage:
    python3 mesh/add-system.py \\
        --name 'NewTool' \\
        --cli '/path/to/cli' \\
        --auth-type api_key \\
        --auth-key 'xxx' \\
        --capabilities 'coding,research' \\
        --cost-model subscription \\
        --context-window 200000

    python3 mesh/add-system.py \\
        --name 'LocalLLM' \\
        --cli '/usr/local/bin/ollama' \\
        --auth-type none \\
        --capabilities 'coding,reasoning' \\
        --cost-model free
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

MESH_DIR = Path(__file__).resolve().parent
CONFIG_DIR = MESH_DIR / "config"
MESH_MD = MESH_DIR / "MESH.md"
ROUTER_PY = MESH_DIR / "router.py"

VALID_CAPABILITIES = [
    "coding", "research", "reasoning", "long_context", "multimodal",
    "quick_answers", "background", "monitoring", "orchestration",
    "web_search", "file_operations", "deployment",
]

VALID_AUTH_TYPES = ["api_key", "subscription", "none", "oauth"]
VALID_COST_MODELS = ["free", "subscription", "per_token", "api_credit"]


def generate_config_yaml(
    name: str,
    cli_path: str,
    auth_type: str,
    auth_key: str | None,
    capabilities: list[str],
    cost_model: str,
    context_window: int,
    display_name: str | None = None,
) -> str:
    """Generate a YAML config for the new system."""
    slug = name.lower().replace(" ", "-").replace("_", "-")
    display = display_name or name

    # Cost pricing
    if cost_model == "free":
        pricing_block = "  cost_model: free\n  pricing: $0"
    elif cost_model == "subscription":
        pricing_block = "  cost_model: subscription\n  pricing: $0 (flat rate)"
    elif cost_model == "per_token":
        pricing_block = "  cost_model: per_token\n  pricing:\n    input_per_1k: 0.001\n    output_per_1k: 0.002"
    else:
        pricing_block = f"  cost_model: {cost_model}"

    # Auth block
    if auth_type == "none":
        auth_block = "  method: none"
    elif auth_type == "api_key":
        env_var = f"{slug.upper().replace('-', '_')}_API_KEY"
        auth_block = f"  method: api_key\n  api_key_env: {env_var}"
    elif auth_type == "subscription":
        auth_block = "  method: subscription\n  plan: Subscription (flat rate)"
    else:
        auth_block = f"  method: {auth_type}"

    caps_list = "\n".join(f"    - {c}" for c in capabilities)

    yaml = f"""# {display} — Mesh System
system:
  name: {slug}
  display_name: "{display}"
  role: "Added via mesh/add-system.py"

auth:
{auth_block}
{pricing_block}

runtime:
  cli: "{cli_path}"
  context_window: {context_window}

capabilities:
  primary:
{caps_list}

cost_routing:
  priority_for: {{}}
  never_use_for: []

health_check:
  command: "{cli_path} --version"
  expected: "0"

added_at: "{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
"""
    return yaml


def test_connectivity(cli_path: str) -> tuple[bool, str]:
    """Test if the CLI is reachable."""
    try:
        result = subprocess.run(
            [cli_path, "--version"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        output = (result.stdout or result.stderr or "").strip()
        if result.returncode == 0:
            return True, output.splitlines()[0] if output else "OK"
        return False, output or f"exit code {result.returncode}"
    except FileNotFoundError:
        return False, f"CLI not found at {cli_path}"
    except subprocess.TimeoutExpired:
        return False, "timed out"
    except Exception as e:
        return False, str(e)


def update_mesh_md(name: str, cli_path: str, capabilities: list[str], cost_model: str) -> None:
    """Append the new system to MESH.md."""
    if not MESH_MD.exists():
        return

    content = MESH_MD.read_text()
    slug = name.lower().replace(" ", "-").replace("_", "-")

    # Check if already exists
    if slug in content.lower() or name.lower() in content.lower():
        print(f"  [mesh.md] System '{name}' already listed — skipping update")
        return

    entry = f"""
### {len(content.split('###')) + 1}. {name}
- **Role:** Custom system added via mesh/add-system.py
- **Auth:** {cost_model}
- **Capabilities:** {', '.join(capabilities)}
- **CLI:** {cli_path}
"""

    # Insert before "## Cost Routing Rules" or append
    marker = "## Cost Routing Rules"
    if marker in content:
        content = content.replace(marker, entry + "\n" + marker)
    else:
        content += entry

    MESH_MD.write_text(content)
    print(f"  [mesh.md] Added {name} to MESH.md")


def set_api_key(name: str, auth_key: str) -> None:
    """Store the API key in the environment hint."""
    slug = name.lower().replace(" ", "-").replace("_", "-")
    env_var = f"{slug.upper().replace('-', '_')}_API_KEY"
    print(f"  [auth] To set the API key, run:")
    print(f"         export {env_var}='{auth_key}'")
    print(f"         Add to ~/.zshrc for persistence")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Add a new system to the AI mesh",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--name", required=True, help="System name (e.g. 'LocalLLM')")
    parser.add_argument("--cli", required=True, help="Path to CLI binary")
    parser.add_argument("--auth-type", required=True, choices=VALID_AUTH_TYPES, help="Authentication type")
    parser.add_argument("--auth-key", default=None, help="API key (if auth-type is api_key)")
    parser.add_argument("--capabilities", required=True, help="Comma-separated capabilities")
    parser.add_argument("--cost-model", default="free", choices=VALID_COST_MODELS, help="Cost model")
    parser.add_argument("--context-window", type=int, default=200000, help="Context window size")
    parser.add_argument("--display-name", default=None, help="Display name (defaults to --name)")
    parser.add_argument("--skip-test", action="store_true", help="Skip connectivity test")
    args = parser.parse_args()

    capabilities = [c.strip() for c in args.capabilities.split(",")]
    slug = args.name.lower().replace(" ", "-").replace("_", "-")

    print(f"[add-system] Adding '{args.name}' to mesh...")

    # 1. Test connectivity
    if not args.skip_test:
        print(f"  [test] Testing CLI at {args.cli}...")
        ok, detail = test_connectivity(args.cli)
        if ok:
            print(f"  [test] OK: {detail}")
        else:
            print(f"  [test] FAILED: {detail}")
            print(f"  [test] Use --skip-test to add anyway")
            return 1

    # 2. Generate config YAML
    yaml_content = generate_config_yaml(
        name=args.name,
        cli_path=args.cli,
        auth_type=args.auth_type,
        auth_key=args.auth_key,
        capabilities=capabilities,
        cost_model=args.cost_model,
        context_window=args.context_window,
        display_name=args.display_name,
    )

    config_file = CONFIG_DIR / f"{slug}.yaml"
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    config_file.write_text(yaml_content)
    print(f"  [config] Written to {config_file}")

    # 3. Update MESH.md
    update_mesh_md(args.name, args.cli, capabilities, args.cost_model)

    # 4. Handle auth key
    if args.auth_key and args.auth_type == "api_key":
        set_api_key(args.name, args.auth_key)

    # 5. Summary
    print(f"\n[add-system] Done! '{args.name}' added to mesh.")
    print(f"  Config: {config_file}")
    print(f"  Capabilities: {', '.join(capabilities)}")
    print(f"  Cost model: {args.cost_model}")
    print(f"\n  Next steps:")
    print(f"    1. Review config: cat {config_file}")
    print(f"    2. Run health check: python3 mesh/health.py")
    print(f"    3. Run refresh: python3 mesh/refresh.py")

    return 0


if __name__ == "__main__":
    sys.exit(main())
