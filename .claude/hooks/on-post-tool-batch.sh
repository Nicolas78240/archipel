#!/bin/bash
# Hook : PostToolBatch
# Rôle : Checkpoint apres un batch de tool calls paralleles.
#        Si taux d'erreur > 20%, alerter l'orchestrateur avant de continuer.

INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export HOOK_INPUT="$INPUT" TIMESTAMP

mkdir -p "$PROJECT_DIR/.archipel"

python3 << 'PYEOF'
import json, os, sys

try:
    d = json.loads(os.environ['HOOK_INPUT'])
    results = d.get('results', [])
    total = len(results)
    if total == 0:
        sys.exit(0)
    failed = sum(1 for r in results if not r.get('success', True) or r.get('error'))
    ts = os.environ.get('TIMESTAMP', '')
    # Audit log vers stderr pour ne pas polluer stdout
    print(f"[{ts}] PostToolBatch total={total} failed={failed}", file=sys.stderr)
    if failed == 0:
        sys.exit(0)
    rate = round(failed / total * 100, 1)
    if failed / total > 0.20:
        msg = f"CHECKPOINT BATCH : {failed}/{total} tool calls ont echoue ({rate}% > seuil 20%). L'orchestrateur doit evaluer l'etat avant de continuer — risque de cascade d'erreurs."
    else:
        msg = f"PostToolBatch : {failed}/{total} echecs ({rate}%). Sous le seuil mais a surveiller."
    print(json.dumps({'systemMessage': msg}))
except SystemExit:
    pass
except Exception as e:
    pass
PYEOF

exit 0
