#!/bin/bash
# Hook : UserPromptExpansion
# Rôle : Bloquer les slash commands Archipel et forcer l'usage de la commande directe.
# Input : JSON sur stdin avec command_name, command_args, prompt

set -e

INPUT=$(cat)
COMMAND_NAME=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('command_name',''))" 2>/dev/null || echo "")
COMMAND_ARGS=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('command_args',''))" 2>/dev/null || echo "")

case "$COMMAND_NAME" in

  build)
    python3 -c "
import json
print(json.dumps({
    'decision': 'block',
    'reason': 'La commande /build ne garantit pas l invocation de l agent orchestrateur. Tape : Invoque l agent build-orchestrator avec les arguments : $COMMAND_ARGS'
}))
"
    exit 0
    ;;

  feature)
    python3 -c "
import json
print(json.dumps({
    'decision': 'block',
    'reason': 'Tape : Invoque l agent build-orchestrator pour la feature : $COMMAND_ARGS'
}))
"
    exit 0
    ;;

  *)
    # Pas une commande Archipel critique — laisser passer
    exit 0
    ;;

esac
