"""
Mesh Hook Modules
Adapted from ECC (everything-claude-code) JavaScript hooks.

Individual hook modules for cost tracking, config protection,
quality gates, session management, compaction, MCP health,
session evaluation, governance, commit quality, and desktop notifications.
"""

from mesh.hooks.cost_tracker import track_cost
from mesh.hooks.config_protection import check_config_protection
from mesh.hooks.quality_gate import run_quality_gate
from mesh.hooks.session_manager import on_session_start, on_session_end, on_pre_compact
from mesh.hooks.suggest_compact import check_compact_suggestion
from mesh.hooks.mcp_health import check_mcp_health
from mesh.hooks.evaluate_session import evaluate_session
from mesh.hooks.governance import analyze_governance
from mesh.hooks.commit_quality import check_commit_quality
from mesh.hooks.desktop_notify import send_notification

__all__ = [
    "track_cost",
    "check_config_protection",
    "run_quality_gate",
    "on_session_start",
    "on_session_end",
    "on_pre_compact",
    "check_compact_suggestion",
    "check_mcp_health",
    "evaluate_session",
    "analyze_governance",
    "check_commit_quality",
    "send_notification",
]
