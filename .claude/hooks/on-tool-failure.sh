#!/bin/bash
# Hook : PostToolUseFailure
# Rôle : Capturer tout échec de tool et alerter l'orchestrateur explicitement.

# ── Archipel Monitor feed ──────────────────────────────────────────────────
_MONITOR_ROOT=$(git -C "${CLAUDE_PROJECT_DIR:-$(pwd)}" rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-$(pwd)}")
_MONITOR_FEED="$_MONITOR_ROOT/tasks/live-events.jsonl"
_MONITOR_TS=$(date -u +%H:%M:%S)
_MONITOR_PROJ=$(python3 -c \
  "import sys,json; print(json.load(open('$_MONITOR_ROOT/.archipel/project.json')).get('name','?'))" \
  2>/dev/null || echo "?")
_monitor_push() {
  echo "$1" >> "$_MONITOR_FEED" 2>/dev/null || true
  _TARGET_FILE="$_MONITOR_ROOT/.archipel/active-build-target"
  if [ -f "$_TARGET_FILE" ]; then
    _TARGET_PATH=$(cat "$_TARGET_FILE" 2>/dev/null)
    if [ -n "$_TARGET_PATH" ] && [ -d "$_TARGET_PATH" ]; then
      mkdir -p "$_TARGET_PATH/tasks" 2>/dev/null || true
      echo "$1" >> "$_TARGET_PATH/tasks/live-events.jsonl" 2>/dev/null || true
    fi
  fi
}
# ──────────────────────────────────────────────────────────────────────────

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

TOOL_NAME_VAL=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name', d.get('tool', 'unknown')))" 2>/dev/null || echo "unknown")
_monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-tool-failure\",\"type\":\"blocked\",\"project\":\"$_MONITOR_PROJ\",\"msg\":\"TOOL FAILURE: $TOOL_NAME_VAL\"}"

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
