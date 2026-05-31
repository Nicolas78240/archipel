#!/bin/bash
# Hook : PostToolUseFailure
# Rôle : Capturer tout échec de tool et alerter l'orchestrateur explicitement.

INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

export HOOK_INPUT="$INPUT"
mkdir -p "$PROJECT_DIR/.archipel"

python3 << 'PYEOF' 2>/dev/null
import json, os
try:
    d = json.loads(os.environ['HOOK_INPUT'])
    tool = d.get('tool_name', d.get('tool', 'unknown'))
    inp = d.get('tool_input', {})
    cmd = inp.get('command', inp.get('file_path', str(inp)[:120]))
    error = str(d.get('error', d.get('tool_result', '')))[:200]
    msg = f"TOOL FAILURE [{tool}] : {error} | Input : {cmd}"
    print(json.dumps({'systemMessage': msg}))
except:
    print(json.dumps({'systemMessage': 'TOOL FAILURE : details unavailable'}))
PYEOF

# Audit log séparé (stderr pour ne pas polluer stdout JSON)
python3 << PYEOF2 >> "$PROJECT_DIR/.archipel/audit.log" 2>/dev/null
import json, os
try:
    d = json.loads(os.environ['HOOK_INPUT'])
    tool = d.get('tool_name', 'unknown')
    inp = d.get('tool_input', {})
    cmd = inp.get('command', inp.get('file_path', ''))
    error = str(d.get('error', ''))[:100]
    print(f"[$TIMESTAMP] TOOL_FAILURE tool={tool} input={cmd} error={error}")
except:
    print(f"[$TIMESTAMP] TOOL_FAILURE parse_error")
PYEOF2

exit 0
