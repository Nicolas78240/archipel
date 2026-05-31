#!/bin/bash
# Hook : TeammateIdle
# Rôle : Checkpoint d'état entre les turns — persister build-state et flush audit.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$PROJECT_DIR/.archipel"
echo "[$TIMESTAMP] TeammateIdle — checkpoint" >> "$PROJECT_DIR/.archipel/audit.log" 2>/dev/null

BUILD_STATE=$(cat "$PROJECT_DIR/.archipel/build-state.json" 2>/dev/null || echo "")
if [ -n "$BUILD_STATE" ]; then
  export BUILD_STATE_JSON="$BUILD_STATE"
  python3 << 'PYEOF' 2>/dev/null
import json, os
try:
    d = json.loads(os.environ['BUILD_STATE_JSON'])
    status = d.get('status', '?')
    if status in ('running', 'interrupted'):
        msg = f"TeammateIdle : build en cours (status={status}). Etat persiste dans .archipel/build-state.json."
        print(json.dumps({'systemMessage': msg}))
except:
    pass
PYEOF
fi

exit 0
