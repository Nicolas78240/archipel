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
  # Si un build target est actif, écrire UNIQUEMENT dans son feed (pas de doublon)
  # Sinon écrire dans le feed Archipel
  _TARGET_FILE="$_MONITOR_ROOT/.archipel/active-build-target"
  if [ -f "$_TARGET_FILE" ]; then
    _TARGET_PATH=$(cat "$_TARGET_FILE" 2>/dev/null)
    if [ -n "$_TARGET_PATH" ] && [ -d "$_TARGET_PATH" ]; then
      mkdir -p "$_TARGET_PATH/tasks" 2>/dev/null || true
      echo "$1" >> "$_TARGET_PATH/tasks/live-events.jsonl" 2>/dev/null || true
      return
    fi
  fi
  echo "$1" >> "$_MONITOR_FEED" 2>/dev/null || true
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

# Lire description depuis le fichier agent si disponible
AGENT_DESC=$(python3 -c "
import re, os
path = '$_MONITOR_ROOT/.claude/agents/$AGENT_TYPE.md'
try:
    txt = open(path).read()
    m = re.search(r'description:\s*(.+)', txt)
    if m:
        desc = m.group(1).strip().strip('\"').strip(\"'\")[:60]
        print(desc)
    else:
        print('')
except:
    print('')
" 2>/dev/null || echo "")
MSG="$AGENT_TYPE started"
[ -n "$AGENT_DESC" ] && MSG="$AGENT_TYPE — $AGENT_DESC"
_monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-subagent-start\",\"type\":\"agent\",\"project\":\"$_MONITOR_PROJ\",\"agent\":\"$AGENT_TYPE\",\"msg\":\"$MSG\"}"

# Injecter les leçons fraîches dans le contexte de l'agent
# (réinjecter à chaque agent, pas seulement au SessionStart)
LESSONS_FILE="$PROJECT_DIR/tasks/lessons.md"
if [ -f "$LESSONS_FILE" ]; then
  # Filtrer les leçons selon le type d'agent
  case "$AGENT_TYPE" in
    architect|db-dev)          TAGS="#architecture #db" ;;
    fastapi-dev)               TAGS="#architecture #db #resilience" ;;
    nextjs-dev)                TAGS="#architecture #maintainability" ;;
    review-security)           TAGS="#security" ;;
    review-performance)        TAGS="#performance #db" ;;
    review-resilience)         TAGS="#resilience" ;;
    review-maintainability)    TAGS="#maintainability" ;;
    review-architecture)       TAGS="#architecture" ;;
    test-writer)               TAGS="#resilience #config" ;;
    *)                         TAGS="" ;;
  esac
  if [ -n "$TAGS" ]; then
    FRESH_LESSONS=$(grep -B2 -A8 "$TAGS" "$LESSONS_FILE" 2>/dev/null | head -60 || echo "")
    if [ -n "$FRESH_LESSONS" ]; then
      export AGENT_TYPE FRESH_LESSONS
      python3 << 'PYEOF' 2>/dev/null
import json, os
agent = os.environ.get('AGENT_TYPE', '?')
lessons = os.environ.get('FRESH_LESSONS', '')
msg = f"Leçons récentes pour {agent} :\n{lessons}"
print(json.dumps({'systemMessage': msg}))
PYEOF
    fi
  fi
fi

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
