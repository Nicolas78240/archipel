#!/bin/bash
# Hook : PreToolUse (Bash)
# Rôle : Bloquer les commandes dangereuses avant execution.

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
  # Si un build target est actif, pousser aussi dans son feed
  _TARGET_FILE="$_MONITOR_ROOT/.archipel/active-build-target"
  if [ -f "$_TARGET_FILE" ]; then
    _TARGET_PATH=$(cat "$_TARGET_FILE" 2>/dev/null)
    _TARGET_FEED="$_TARGET_PATH/tasks/live-events.jsonl"
    if [ -n "$_TARGET_PATH" ] && [ -d "$_TARGET_PATH" ]; then
      mkdir -p "$_TARGET_PATH/tasks" 2>/dev/null || true
      echo "$1" >> "$_TARGET_FEED" 2>/dev/null || true
    fi
  fi
}
# ──────────────────────────────────────────────────────────────────────────

COMMAND="${TOOL_INPUT_command:-}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

[ -z "$COMMAND" ] && exit 0

# ── git push --force sur main/master ─────────────────────────────────────────
if echo "$COMMAND" | grep -q "git push" && echo "$COMMAND" | grep -q "\-\-force\|-f"; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
  if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
    echo "BLOQUE : git push --force sur $CURRENT_BRANCH est interdit" >&2
    _monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-bash.sh\",\"type\":\"blocked\",\"project\":\"$_MONITOR_PROJ\",\"msg\":\"GATE blocked\"}"
    exit 2
  fi
fi

# ── Scan secrets avant git push ───────────────────────────────────────────────
if echo "$COMMAND" | grep -q "git push"; then
  if command -v gitleaks &>/dev/null; then
    gitleaks detect --no-git 2>/dev/null || {
      echo "BLOQUE : gitleaks a detecte des secrets — corriger avant de pusher" >&2
      _monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-bash.sh\",\"type\":\"blocked\",\"project\":\"$_MONITOR_PROJ\",\"msg\":\"GATE blocked\"}"
      exit 2
    }
  fi
fi

# ── rm -rf dangereux ──────────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qE "rm -rf|rm -fr"; then
  if echo "$COMMAND" | grep -qvE "node_modules|\.next|__pycache__|\.pytest_cache|dist|build|coverage"; then
    python3 << 'PYEOF'
import json
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": "Commande rm -rf sur un repertoire potentiellement important. Verifier que c'est intentionnel avant d'executer."
    }
}))
PYEOF
    exit 0
  fi
fi

# ── docker compose down -v (suppression volumes = perte DB) ───────────────────
if echo "$COMMAND" | grep -q "docker compose down" && echo "$COMMAND" | grep -q "\-v\b"; then
  echo "BLOQUE : docker compose down -v supprime les volumes PostgreSQL (perte de donnees)" >&2
  echo "Utiliser 'docker compose down' sans -v pour arreter sans supprimer les donnees" >&2
  _monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-bash.sh\",\"type\":\"blocked\",\"project\":\"$_MONITOR_PROJ\",\"msg\":\"GATE blocked\"}"
  exit 2
fi

# ── SQL destructif direct ─────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qiE "DROP TABLE|DROP COLUMN|TRUNCATE"; then
  echo "BLOQUE : operation SQL destructive detectee" >&2
  echo "Utiliser Alembic (migration versionnee) plutot que du SQL direct" >&2
  _monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-bash.sh\",\"type\":\"blocked\",\"project\":\"$_MONITOR_PROJ\",\"msg\":\"GATE blocked\"}"
  exit 2
fi

# ── alembic downgrade ─────────────────────────────────────────────────────────
if echo "$COMMAND" | grep -q "alembic downgrade"; then
  python3 << 'PYEOF'
import json
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": "alembic downgrade va retrograder le schema DB. Verifier que c'est intentionnel et qu'une sauvegarde existe."
    }
}))
PYEOF
  exit 0
fi

_monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-bash.sh\",\"type\":\"ok\",\"project\":\"$_MONITOR_PROJ\",\"msg\":$(python3 -c "import sys,json;print(json.dumps(sys.argv[1][:80]))" "$COMMAND" 2>/dev/null || echo "\"bash\"")}"

exit 0
