#!/bin/bash
# Hook : PostToolUse (Write | Edit)
# Rôle : Verifications immediates apres ecriture de fichiers.
#        Format/lint, securite, coherence design system.

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

FILE="${TOOL_INPUT_file_path:-}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

[ -z "$FILE" ] && exit 0

case "$FILE" in
  /*) ABS_FILE="$FILE" ;;
  *)  ABS_FILE="$PROJECT_DIR/$FILE" ;;
esac

BASENAME=$(basename "$FILE")

# ── TypeScript / TSX ──────────────────────────────────────────────────────────
if [[ "$FILE" == *.ts || "$FILE" == *.tsx ]]; then
  if command -v eslint &>/dev/null; then
    eslint "$ABS_FILE" --max-warnings 0 >/dev/null 2>&1 || true
  fi
  if command -v prettier &>/dev/null; then
    prettier --write "$ABS_FILE" >/dev/null 2>&1 || true
  fi

  # Lecon V3 : postcss.config.js requis avec Tailwind 4
  if [[ "$BASENAME" == "globals.css" ]]; then
    POSTCSS="$PROJECT_DIR/apps/web/postcss.config.js"
    if [ ! -f "$POSTCSS" ]; then
      echo 'module.exports = { plugins: { "@tailwindcss/postcss": {} } };' > "$POSTCSS"
      echo "postcss.config.js cree automatiquement" >&2
    fi
  fi
fi

# ── Python ────────────────────────────────────────────────────────────────────
if [[ "$FILE" == *.py ]]; then
  if command -v ruff &>/dev/null; then
    ruff format "$ABS_FILE" >&2 2>/dev/null || true
    ruff check "$ABS_FILE" >&2 2>/dev/null || true
  fi

  # Migrations Alembic — alerter si DROP
  if [[ "$FILE" == *alembic*versions* ]]; then
    if grep -q "drop_table\|drop_column\|op\.drop" "$ABS_FILE" 2>/dev/null; then
      python3 << 'PYEOF'
import json
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": "ATTENTION : La migration Alembic contient une operation DROP. Verifier que cette suppression est prevue dans le plan avant d'appliquer."
    }
}))
PYEOF
    fi
  fi
fi

# ── Fichiers proteges : primitives shadcn/ui ──────────────────────────────────
if [[ "$FILE" == */components/ui/* && "$FILE" == *.tsx ]]; then
  python3 << 'PYEOF'
import json
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": "REGLE VIOLEE : Les fichiers dans components/ui/ sont des primitives shadcn — ne jamais les modifier directement. Creer un wrapper dans components/features/ a la place."
    }
}))
PYEOF
fi

# ── Variables d'environnement ─────────────────────────────────────────────────
if [[ "$BASENAME" == ".env" || "$BASENAME" == ".env.local" ]]; then
  if grep -v "changeme\|example\|placeholder\|xxxx\|YOUR_\|<" "$ABS_FILE" 2>/dev/null | grep -q "SECRET\|PASSWORD\|TOKEN\|KEY" 2>/dev/null; then
    echo ".env semble contenir des valeurs reelles — verifier qu'il est dans .gitignore" >&2
  fi
fi

_monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-write.sh\",\"type\":\"write\",\"project\":\"$_MONITOR_PROJ\",\"msg\":$(python3 -c "import sys,json;print(json.dumps(sys.argv[1]))" "$(basename $FILE) [write]" 2>/dev/null || echo "\"write\"")}"

exit 0
