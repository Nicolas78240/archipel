#!/bin/bash
# Hook : PostToolUse (Write | Edit)
# Rôle : Verifications immediates apres ecriture de fichiers.
#        Format/lint, securite, coherence design system.

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

exit 0
