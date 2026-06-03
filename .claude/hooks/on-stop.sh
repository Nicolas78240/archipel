#!/bin/bash
# Hook : Stop / StopFailure
# Rôle : Verifications de fin de turn — tests, fichiers non commites, resume structure.

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

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOOK_EVENT="${CLAUDE_HOOK_EVENT:-Stop}"

mkdir -p "$PROJECT_DIR/.archipel"

# StopFailure : diagnostic immediat
if [ "$HOOK_EVENT" = "StopFailure" ]; then
  echo "[$TIMESTAMP] StopFailure detected" >> "$PROJECT_DIR/.archipel/audit.log"
  _monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-stop\",\"type\":\"blocked\",\"project\":\"$_MONITOR_PROJ\",\"msg\":\"StopFailure detecte\"}"
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

# Gate 4 — Vérifier que les pages web ont des données réelles (pas seulement HTTP 200)
# Lire les ports depuis project.json et chercher des patterns métier dans les pages
DATA_CHECK_RESULT=""
if [ -f "$PROJECT_DIR/.archipel/project.json" ] && [ -f "$PROJECT_DIR/apps/web/src/lib/api.ts" ]; then
  PORT_WEB=$(python3 -c "import json; print(json.load(open('$PROJECT_DIR/.archipel/project.json')).get('ports',{}).get('web',3000))" 2>/dev/null || echo "3000")
  # Lire les patterns de données depuis .archipel/data-patterns.json si existe, sinon patterns génériques
  PATTERNS_FILE="$PROJECT_DIR/.archipel/data-patterns.json"
  if [ -f "$PATTERNS_FILE" ]; then
    PATTERNS=$(python3 -c "import json; print(' '.join(json.load(open('$PATTERNS_FILE')).get('patterns',[])))" 2>/dev/null || echo "")
  else
    PATTERNS=""
  fi

  if [ -n "$PATTERNS" ]; then
    # Tester les pages principales — chercher les patterns métier
    export PORT_WEB PATTERNS PROJECT_DIR
    python3 << 'PYEOF' 2>/dev/null
import urllib.request, os, re, json

port = os.environ.get('PORT_WEB', '3000')
patterns = os.environ.get('PATTERNS', '').split()
proj_dir = os.environ.get('PROJECT_DIR', '')

if not patterns:
    import sys; sys.exit(0)

# Lire les pages à tester depuis .archipel/data-patterns.json
pf = os.path.join(proj_dir, '.archipel', 'data-patterns.json')
pages = json.load(open(pf)).get('pages', ['/']) if os.path.exists(pf) else ['/']

empty_pages = []
for page in pages:
    try:
        html = urllib.request.urlopen(f'http://localhost:{port}{page}', timeout=4).read().decode('utf-8','ignore')
        found = [p for p in patterns if p in html]
        if not found:
            empty_pages.append(page)
    except:
        pass  # page inaccessible = skip

if empty_pages:
    msg = f"Pages sans données métier : {', '.join(empty_pages)}. Les patterns attendus ({', '.join(patterns[:3])}) sont absents."
    print(json.dumps({'systemMessage': f'⚠️ DONNÉES VIDES — {msg}'}))
else:
    import sys; print(f'OK Données présentes sur {len(pages)} page(s)', file=sys.stderr)
PYEOF
  fi
fi

_monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-stop\",\"type\":\"success\",\"project\":\"$_MONITOR_PROJ\",\"msg\":\"Session stop — git:${UNCOMMITTED:-0} uncommitted\"}"

exit 0
