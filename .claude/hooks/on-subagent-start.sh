#!/bin/bash
# Hook : SubagentStart
# Rôle : Enregistrer le contrat de scope de chaque agent au démarrage.
#        SubagentStop peut ainsi vérifier le respect du périmètre.

# ── Archipel Monitor feed ──────────────────────────────────────────────────
_MONITOR_ROOT=$(git -C "${CLAUDE_PROJECT_DIR:-$(pwd)}" rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-$(pwd)}")
_MONITOR_FEED="$_MONITOR_ROOT/tasks/live-events.jsonl"
_MONITOR_TS=$(date -u +%H:%M:%S)
_TARGET_ACTIVE=$(cat "$_MONITOR_ROOT/.archipel/active-build-target" 2>/dev/null)
if [ -n "$_TARGET_ACTIVE" ] && [ -f "$_TARGET_ACTIVE/.archipel/project.json" ]; then
  _MONITOR_PROJ=$(python3 -c     "import sys,json; print(json.load(open('$_TARGET_ACTIVE/.archipel/project.json')).get('name','?'))"     2>/dev/null || echo "?")
else
  _MONITOR_PROJ=$(python3 -c     "import sys,json; print(json.load(open('$_MONITOR_ROOT/.archipel/project.json')).get('name','?'))"     2>/dev/null || echo "?")
fi
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

AGENT_TYPE=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('agent_type', d.get('name', 'unknown')))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

_monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-subagent-start\",\"type\":\"agent\",\"project\":\"$_MONITOR_PROJ\",\"agent\":\"$AGENT_TYPE\",\"msg\":\"$AGENT_TYPE started\"}"

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
  review-resilience)     SCOPE="docs/review/" ;;
  review-maintainability) SCOPE="docs/review/ docs/PATTERNS.md" ;;
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
