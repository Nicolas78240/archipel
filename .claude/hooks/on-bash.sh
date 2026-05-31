#!/bin/bash
# Hook : PreToolUse (Bash)
# Rôle : Bloquer les commandes dangereuses avant execution.

COMMAND="${TOOL_INPUT_command:-}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

[ -z "$COMMAND" ] && exit 0

# ── git push --force sur main/master ─────────────────────────────────────────
if echo "$COMMAND" | grep -q "git push" && echo "$COMMAND" | grep -q "\-\-force\|-f"; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
  if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
    echo "BLOQUE : git push --force sur $CURRENT_BRANCH est interdit" >&2
    exit 2
  fi
fi

# ── Scan secrets avant git push ───────────────────────────────────────────────
if echo "$COMMAND" | grep -q "git push"; then
  if command -v gitleaks &>/dev/null; then
    gitleaks detect --no-git 2>/dev/null || {
      echo "BLOQUE : gitleaks a detecte des secrets — corriger avant de pusher" >&2
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
  exit 2
fi

# ── SQL destructif direct ─────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qiE "DROP TABLE|DROP COLUMN|TRUNCATE"; then
  echo "BLOQUE : operation SQL destructive detectee" >&2
  echo "Utiliser Alembic (migration versionnee) plutot que du SQL direct" >&2
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

exit 0
