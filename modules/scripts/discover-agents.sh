#!/bin/bash
# discover-agents.sh -- Scan all registered agents and their specialties
# The orchestrator runs this to know who's available for delegation

CONFIG="$HOME/.openclaw/openclaw.json"
echo "=== Registered Agents ==="
echo ""

# Get all agent IDs from config
python3 -c "
import json, os, glob

with open('$CONFIG') as f:
    config = json.load(f)

agents = config.get('agents', {}).get('list', [])

for agent in agents:
    agent_id = agent.get('id', 'unknown')
    name = agent.get('name', agent_id)
    model = agent.get('model', 'default')
    workspace = agent.get('workspace', '')
    agent_dir = agent.get('agentDir', '')

    # Try to find SOUL.md for specialty info
    soul_paths = [
        os.path.join(workspace, 'SOUL.md') if workspace else '',
        os.path.join(agent_dir, '..', '..', 'workspace-' + agent_id, 'SOUL.md') if agent_dir else '',
        os.path.expanduser(f'~/.openclaw/workspace-{agent_id}/SOUL.md'),
        os.path.expanduser(f'~/.openclaw/workspaces/{agent_id}/SOUL.md'),
    ]

    soul_content = ''
    for sp in soul_paths:
        if sp and os.path.exists(sp):
            with open(sp) as sf:
                soul_content = sf.read()[:500]
            break

    # Try to find IDENTITY.md
    identity_paths = [
        os.path.join(workspace, 'IDENTITY.md') if workspace else '',
        os.path.expanduser(f'~/.openclaw/workspace-{agent_id}/IDENTITY.md'),
        os.path.expanduser(f'~/.openclaw/workspaces/{agent_id}/IDENTITY.md'),
    ]

    identity_content = ''
    for ip in identity_paths:
        if ip and os.path.exists(ip):
            with open(ip) as idf:
                identity_content = idf.read()[:300]
            break

    print(f'--- Agent: {name} (id: {agent_id}) ---')
    print(f'Model: {model}')
    if workspace:
        print(f'Workspace: {workspace}')
    if soul_content:
        # Extract first meaningful lines
        lines = [l.strip() for l in soul_content.split('\n') if l.strip() and not l.startswith('#')]
        preview = ' | '.join(lines[:3])
        print(f'SOUL preview: {preview}')
    if identity_content:
        lines = [l.strip() for l in identity_content.split('\n') if l.strip() and not l.startswith('#')]
        preview = ' | '.join(lines[:3])
        print(f'Identity: {preview}')
    if not soul_content and not identity_content:
        print('(No SOUL.md or IDENTITY.md found)')
    print()
"
