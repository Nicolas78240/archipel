#!/bin/bash
# Hook : WorktreeCreate / WorktreeRemove
# Rôle : Logger la création et suppression des worktrees d'isolation des agents.

INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOOK_NAME="${CLAUDE_HOOK_EVENT:-WorktreeEvent}"

export HOOK_INPUT="$INPUT"
export HOOK_NAME_ENV="$HOOK_NAME"
export TIMESTAMP_ENV="$TIMESTAMP"

mkdir -p "$PROJECT_DIR/.archipel"

python3 << 'PYEOF' >> "$PROJECT_DIR/.archipel/audit.log" 2>/dev/null
import json, os
try:
    d = json.loads(os.environ['HOOK_INPUT'])
    path = d.get('path', d.get('worktree_path', '?'))
    ts = os.environ['TIMESTAMP_ENV']
    hook = os.environ['HOOK_NAME_ENV']
    print(f"[{ts}] {hook} path={path}")
except:
    pass
PYEOF

if [ "$HOOK_NAME" = "WorktreeRemove" ]; then
  python3 << 'PYEOF' 2>/dev/null
import json, os
try:
    d = json.loads(os.environ['HOOK_INPUT'])
    path = d.get('path', d.get('worktree_path', '?'))
    print(json.dumps({'systemMessage': f'Worktree supprime : {path} — isolation agent terminee.'}))
except:
    pass
PYEOF
fi

exit 0
