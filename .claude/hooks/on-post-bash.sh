#!/bin/bash
# Hook : PostToolUse (Bash)
# Rôle : Capturer les sorties significatives des commandes bash et alimenter l'audit.

COMMAND="${TOOL_INPUT_command:-}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

[ -z "$COMMAND" ] && exit 0

mkdir -p "$PROJECT_DIR/.archipel"

# Logger les opérations à fort impact
if echo "$COMMAND" | grep -qE "git push|docker (build|push|compose up)|alembic upgrade|prisma migrate deploy|npm run build|pytest|jest"; then
  echo "[$TIMESTAMP] PostBash: $COMMAND" >> "$PROJECT_DIR/.archipel/audit.log"
fi

exit 0
