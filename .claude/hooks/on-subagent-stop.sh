#!/bin/bash
# Hook : SubagentStop
# Rôle : Vérifier les livrables obligatoires + respecter le contrat de scope.

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
AGENT_TYPE=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('agent_type', d.get('name', '')))" 2>/dev/null || echo "")
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

[ -z "$AGENT_TYPE" ] && exit 0

mkdir -p "$PROJECT_DIR/.archipel"

# Marquer le contrat comme terminé
CONTRACT_FILE="$PROJECT_DIR/.archipel/subagent-contracts/$AGENT_TYPE.json"
if [ -f "$CONTRACT_FILE" ]; then
  export CONTRACT_FILE TIMESTAMP
  python3 << 'PYEOF' 2>/dev/null
import json, os
f = os.environ['CONTRACT_FILE']
ts = os.environ['TIMESTAMP']
with open(f) as fh:
    d = json.load(fh)
d['status'] = 'completed'
d['completed_at'] = ts
with open(f, 'w') as fh:
    json.dump(d, fh, indent=2)
PYEOF
fi

echo "[$TIMESTAMP] SubagentStop agent=$AGENT_TYPE" >> "$PROJECT_DIR/.archipel/audit.log"
_monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-subagent-stop\",\"type\":\"ok\",\"project\":\"$_MONITOR_PROJ\",\"agent\":\"$AGENT_TYPE\",\"msg\":\"$AGENT_TYPE done\"}"

# Chercher IMPL-*.md dans PROJECT_DIR ET dans le build target actif (cas multi-projet)
_BUILD_TARGET=""
_BUILD_TARGET_FILE="$PROJECT_DIR/.archipel/active-build-target"
if [ -f "$_BUILD_TARGET_FILE" ]; then
  _BUILD_TARGET=$(cat "$_BUILD_TARGET_FILE" 2>/dev/null)
fi

LATEST_IMPL=$(
  {
    find "$PROJECT_DIR/docs" -name "IMPL-*.md" 2>/dev/null
    [ -n "$_BUILD_TARGET" ] && [ -d "$_BUILD_TARGET/docs" ] && find "$_BUILD_TARGET/docs" -name "IMPL-*.md" 2>/dev/null
  } | sort | tail -1
)

# Fonction utilitaire : émettre un systemMessage
emit_warn() {
  export WARN_MSG="$1"
  python3 << 'PYEOF' 2>/dev/null
import json, os
print(json.dumps({'systemMessage': os.environ['WARN_MSG']}))
PYEOF
}

case "$AGENT_TYPE" in

  architect)
    if [ -z "$LATEST_IMPL" ] || [ ! -f "$LATEST_IMPL" ]; then
      python3 -c "import json; print(json.dumps({'decision': 'block', 'reason': 'GATE BLOQUANT : architect a termine sans produire docs/IMPL-*.md.'}))"
      exit 0
    fi
    echo "OK Gate architect : $(basename $LATEST_IMPL) present" >&2
    ;;

  nextjs-dev)
    CHANGED=$(git -C "$PROJECT_DIR" diff --name-only HEAD 2>/dev/null | grep -v "^apps/web/" | grep -v "^docs/" | head -5)
    if [ -n "$CHANGED" ]; then
      emit_warn "SCOPE VIOLATION nextjs-dev : fichiers modifies hors apps/web/ : $CHANGED"
    else
      echo "OK Gate nextjs-dev : scope apps/web/ respecte" >&2
    fi
    ;;

  fastapi-dev)
    CHANGED=$(git -C "$PROJECT_DIR" diff --name-only HEAD 2>/dev/null | grep -v "^apps/api/" | grep -v "^docs/" | head -5)
    if [ -n "$CHANGED" ]; then
      emit_warn "SCOPE VIOLATION fastapi-dev : fichiers modifies hors apps/api/ : $CHANGED"
    else
      echo "OK Gate fastapi-dev : scope apps/api/ respecte" >&2
    fi
    ;;

  db-dev)
    CHANGED=$(git -C "$PROJECT_DIR" diff --name-only HEAD 2>/dev/null | grep -v "^shared/db/" | grep -v "^docs/" | head -5)
    if [ -n "$CHANGED" ]; then
      emit_warn "SCOPE VIOLATION db-dev : fichiers modifies hors shared/db/ : $CHANGED"
    else
      echo "OK Gate db-dev : scope shared/db/ respecte" >&2
    fi
    ;;

  review-security|review-architecture|review-performance|review-maintainability|review-resilience)
    if [ ! -d "$PROJECT_DIR/docs/review" ] && [ -z "$(find "$PROJECT_DIR/docs" -name "review-*.md" 2>/dev/null | head -1)" ]; then
      emit_warn "Gate $AGENT_TYPE : aucun rapport de review trouve dans docs/review/ ou docs/review-*.md"
    else
      echo "OK Gate $AGENT_TYPE : rapport present" >&2
    fi
    ;;

  creative-director)
    if [ ! -f "$PROJECT_DIR/docs/CREATIVE-BRIEF.md" ]; then
      python3 -c "import json; print(json.dumps({'decision': 'block', 'reason': 'GATE BLOQUANT : creative-director a termine sans produire docs/CREATIVE-BRIEF.md.'}))"
      exit 0
    fi
    echo "OK Gate creative-director : CREATIVE-BRIEF.md present" >&2
    ;;

  design-system)
    MISSING=""
    [ ! -f "$PROJECT_DIR/docs/DESIGN-SYSTEM.md" ] && MISSING="docs/DESIGN-SYSTEM.md"
    [ ! -f "$PROJECT_DIR/apps/web/src/app/globals.css" ] && MISSING="$MISSING apps/web/src/app/globals.css"

    if [ ! -f "$PROJECT_DIR/apps/web/postcss.config.js" ]; then
      echo 'module.exports = { plugins: { "@tailwindcss/postcss": {} } };' > "$PROJECT_DIR/apps/web/postcss.config.js"
      echo "postcss.config.js cree automatiquement (lecon V3)" >&2
    fi

    if [ -n "$MISSING" ]; then
      export MISSING
      python3 -c "import json,os; print(json.dumps({'decision': 'block', 'reason': f'GATE BLOQUANT : design-system a termine sans produire : {os.environ[\"MISSING\"]}'}))"
      exit 0
    fi
    echo "OK Gate design-system : DESIGN-SYSTEM.md + globals.css presents" >&2
    ;;

  ui-designer)
    if [ ! -f "$PROJECT_DIR/docs/UI-SPECS.md" ]; then
      python3 -c "import json; print(json.dumps({'decision': 'block', 'reason': 'GATE BLOQUANT : ui-designer a termine sans produire docs/UI-SPECS.md.'}))"
      exit 0
    fi
    SPEC_LINES=$(wc -l < "$PROJECT_DIR/docs/UI-SPECS.md" | tr -d ' ')
    if [ "$SPEC_LINES" -lt 50 ]; then
      export SPEC_LINES
      python3 -c "import json,os; print(json.dumps({'decision': 'block', 'reason': f'GATE BLOQUANT : docs/UI-SPECS.md trop court ({os.environ[\"SPEC_LINES\"]} lignes).'}))"
      exit 0
    fi
    echo "OK Gate ui-designer : UI-SPECS.md present ($SPEC_LINES lignes)" >&2
    ;;

  test-writer)
    COVERAGE_FILE="$PROJECT_DIR/apps/web/coverage/coverage-summary.json"
    if [ -f "$COVERAGE_FILE" ]; then
      export COVERAGE_FILE
      python3 << 'PYEOF' 2>/dev/null
import json, os
f = os.environ['COVERAGE_FILE']
d = json.load(open(f))
pct = d.get('total', {}).get('lines', {}).get('pct', 0)
if float(pct) < 80:
    print(json.dumps({'systemMessage': f'GATE test-writer : coverage {pct}% < 80% requis'}))
else:
    import sys; print(f'OK Coverage web : {pct}%', file=sys.stderr)
PYEOF
    fi
    ;;

  *)
    exit 0
    ;;
esac

exit 0
