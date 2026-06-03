#!/bin/bash
# Hook : Stop / StopFailure
# Rôle : Verifications de fin de turn — tests, fichiers non commites, resume structure.

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

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOOK_EVENT="${CLAUDE_HOOK_EVENT:-Stop}"

mkdir -p "$PROJECT_DIR/.archipel"

# StopFailure : diagnostic immediat
if [ "$HOOK_EVENT" = "StopFailure" ]; then
  echo "[$TIMESTAMP] StopFailure detected" >> "$PROJECT_DIR/.archipel/audit.log"
  _monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-stop.sh\",\"type\":\"blocked\",\"project\":\"$_MONITOR_PROJ\",\"msg\":\"StopFailure detecte\"}"
  python3 << 'PYEOF'
import json
msg = "STOP FAILURE detecte — le turn s'est termine en erreur. Consulter .archipel/audit.log pour les tool failures. Action : diagnostiquer la cause racine avant de relancer."
print(json.dumps({'systemMessage': msg}))
PYEOF
  exit 0
fi

# Tests web
TEST_WEB=""
if [ -f "$PROJECT_DIR/apps/web/package.json" ]; then
  cd "$PROJECT_DIR/apps/web"
  npm test -- --passWithNoTests > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    TEST_WEB="FAILED"
    echo "[$TIMESTAMP] Stop: tests web FAILED" >> "$PROJECT_DIR/.archipel/audit.log"
  else
    TEST_WEB="OK"
  fi
fi

# Tests API
TEST_API=""
if [ -f "$PROJECT_DIR/apps/api/requirements.txt" ] && [ -f "$PROJECT_DIR/apps/api/.venv/bin/pytest" ]; then
  cd "$PROJECT_DIR/apps/api"
  .venv/bin/pytest --tb=short > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    TEST_API="FAILED"
    echo "[$TIMESTAMP] Stop: tests API FAILED" >> "$PROJECT_DIR/.archipel/audit.log"
  else
    TEST_API="OK"
  fi
fi

cd "$PROJECT_DIR"
UNCOMMITTED=$(git status --porcelain 2>/dev/null | grep -v "^?" | wc -l | tr -d ' ')
FILES_CHANGED=$(git diff --name-only HEAD 2>/dev/null | wc -l | tr -d ' ')

echo "[$TIMESTAMP] Stop: uncommitted=$UNCOMMITTED files_changed=$FILES_CHANGED" >> "$PROJECT_DIR/.archipel/audit.log"

export TEST_WEB TEST_API UNCOMMITTED

# N'emettre que si quelque chose a signaler
if [ -n "$TEST_WEB" ] || [ -n "$TEST_API" ] || [ "$UNCOMMITTED" -gt 0 ]; then
  python3 << 'PYEOF'
import json, os
parts = []
web = os.environ.get('TEST_WEB', '')
api = os.environ.get('TEST_API', '')
uncommitted = os.environ.get('UNCOMMITTED', '0')
if web:
    parts.append(f"Tests web: {web}")
if api:
    parts.append(f"Tests API: {api}")
if uncommitted and uncommitted != '0':
    parts.append(f"Git: {uncommitted} fichier(s) non committe(s)")
else:
    parts.append("Git: propre")
print(json.dumps({'systemMessage': ' | '.join(parts)}))
PYEOF
fi

_monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-stop.sh\",\"type\":\"success\",\"project\":\"$_MONITOR_PROJ\",\"msg\":\"Session stop — git:${UNCOMMITTED:-0} uncommitted\"}"

exit 0
