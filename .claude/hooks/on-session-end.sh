#!/bin/bash
# Hook : SessionEnd
# Rôle : Émettre une entrée de log dans session-log.md à chaque fin de session.

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

exit 0
