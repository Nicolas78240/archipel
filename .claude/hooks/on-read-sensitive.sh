#!/bin/bash
# Hook : PreToolUse (Read)
# Rôle : BLOQUER la lecture de fichiers secrets par les sous-agents.
#        Un agent qui lit .env ou *.pem peut exfiltrer ou logguer des credentials.

FILE="${TOOL_INPUT_file_path:-}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

[ -z "$FILE" ] && exit 0

BASENAME=$(basename "$FILE")

if echo "$BASENAME" | grep -qiE "^\.env$|^\.env\.|\.pem$|\.key$|\.p12$|\.pfx$|secrets?\.|credentials?\."; then
  mkdir -p "$PROJECT_DIR/.archipel"
  echo "[$TIMESTAMP] BLOCKED Read sensitive file: $FILE" >> "$PROJECT_DIR/.archipel/audit.log"
  python3 -c "
import json
print(json.dumps({
    'decision': 'block',
    'reason': 'BLOQUE : lecture de fichier sensible interdite aux sous-agents. Fichier : $FILE. Si requis, l orchestrateur doit extraire les valeurs necessaires et les passer en parametre.'
}))
" 2>/dev/null
  exit 0
fi

exit 0
