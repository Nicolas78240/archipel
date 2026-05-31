#!/bin/bash
# Hook : SubagentStart
# Rôle : Enregistrer le contrat de scope de chaque agent au démarrage.
#        SubagentStop peut ainsi vérifier le respect du périmètre.

INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

AGENT_TYPE=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('agent_type', d.get('name', 'unknown')))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

# Scopes autorisés par agent (case compatible bash 3.2 macOS)
case "$AGENT_TYPE" in
  architect)             SCOPE="docs/" ;;
  nextjs-dev)            SCOPE="apps/web/" ;;
  fastapi-dev)           SCOPE="apps/api/" ;;
  db-dev)                SCOPE="shared/db/" ;;
  test-writer)           SCOPE="apps/web/ apps/api/" ;;
  design-system)         SCOPE="apps/web/src/app/globals.css tailwind.config docs/" ;;
  creative-director)     SCOPE="docs/" ;;
  ui-designer)           SCOPE="docs/" ;;
  review-security|\
  review-architecture|\
  review-performance|\
  review-maintainability|\
  review-resilience)     SCOPE="docs/review/" ;;
  build-orchestrator)    SCOPE="*" ;;
  *)                     SCOPE="unknown" ;;
esac

# Écrire le contrat
mkdir -p "$PROJECT_DIR/.archipel/subagent-contracts"
python3 -c "
import json
contract = {
    'agent_type': '$AGENT_TYPE',
    'started_at': '$TIMESTAMP',
    'allowed_scope': '$SCOPE',
    'status': 'running'
}
with open('$PROJECT_DIR/.archipel/subagent-contracts/$AGENT_TYPE.json', 'w') as f:
    json.dump(contract, f, indent=2)
" 2>/dev/null

# Audit log
mkdir -p "$PROJECT_DIR/.archipel"
echo "[$TIMESTAMP] SubagentStart agent=$AGENT_TYPE scope=$SCOPE" >> "$PROJECT_DIR/.archipel/audit.log"

exit 0
