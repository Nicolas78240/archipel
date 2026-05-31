#!/bin/bash
# Hook : Stop / StopFailure
# Rôle : Verifications de fin de turn — tests, fichiers non commites, resume structure.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOOK_EVENT="${CLAUDE_HOOK_EVENT:-Stop}"

mkdir -p "$PROJECT_DIR/.archipel"

# StopFailure : diagnostic immediat
if [ "$HOOK_EVENT" = "StopFailure" ]; then
  echo "[$TIMESTAMP] StopFailure detected" >> "$PROJECT_DIR/.archipel/audit.log"
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

exit 0
