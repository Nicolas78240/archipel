#!/bin/bash
# Hook : PostCompact
# Rôle : Vérifier que le contexte de gouvernance a survécu à la compression.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "[$TIMESTAMP] PostCompact triggered" >> "$PROJECT_DIR/.archipel/audit.log" 2>/dev/null

BUILD_STATE=$(cat "$PROJECT_DIR/.archipel/build-state.json" 2>/dev/null || echo "")
if [ -n "$BUILD_STATE" ]; then
  export BUILD_STATE_JSON="$BUILD_STATE"
  python3 << 'PYEOF' 2>/dev/null
import json, os
try:
    d = json.loads(os.environ['BUILD_STATE_JSON'])
    status = d.get('status', 'unknown')
    completed = d.get('completed', [])
    current = d.get('current', 'none')
    msg = f"PostCompact — contexte re-injecte. Build: status={status} completes={completed} courant={current}"
    print(json.dumps({'systemMessage': msg}))
except:
    pass
PYEOF
fi

exit 0
