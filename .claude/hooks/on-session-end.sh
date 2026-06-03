#!/bin/bash
# Hook : SessionEnd
# Rôle : Émettre une entrée de log dans session-log.md à chaque fin de session.

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

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SESSION_LOG="$PROJECT_DIR/tasks/session-log.md"
DATE=$(date +%Y-%m-%d)

[ ! -f "$SESSION_LOG" ] && exit 0

BUILD_STATE=$(cat "$PROJECT_DIR/.archipel/build-state.json" 2>/dev/null || echo "")
BUILD_LINE=""
if [ -n "$BUILD_STATE" ]; then
  BUILD_LINE=$(python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    status = d.get('status', '?')
    completed = d.get('completed', [])
    print(f'Build : status={status}, complétés={completed}')
except:
    print('')
" <<< "$BUILD_STATE" 2>/dev/null)
fi

UNCOMMITTED=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | grep -v "^?" | wc -l | tr -d ' ')
GIT_LINE=""
[ "$UNCOMMITTED" -gt 0 ] && GIT_LINE="⚠️  ${UNCOMMITTED} fichier(s) non committé(s)"

ENTRY="\n### ${DATE} — SessionEnd\n**Build** : ${BUILD_LINE:-n/a}\n**Git** : ${GIT_LINE:-propre}\n"

printf "$ENTRY" >> "$SESSION_LOG" 2>/dev/null

_monitor_push "{\"ts\":\"$_MONITOR_TS\",\"hook\":\"on-session-end\",\"type\":\"info\",\"project\":\"$_MONITOR_PROJ\",\"msg\":\"Session terminee\"}"

exit 0
