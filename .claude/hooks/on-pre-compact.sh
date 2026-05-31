#!/bin/bash
# Hook : PreCompact
# Rôle : Injecter l'état de gouvernance critique avant compression du contexte.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

export BUILD_STATE_JSON=$(cat "$PROJECT_DIR/.archipel/build-state.json" 2>/dev/null || echo "")
export LAST_LESSONS=$(grep -A 5 "^###" "$PROJECT_DIR/tasks/lessons.md" 2>/dev/null | head -30 || echo "")
export UNCOMMITTED=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | grep -v "^?" | wc -l | tr -d ' ')

python3 << 'PYEOF' 2>/dev/null
import json, os

build_json = os.environ.get('BUILD_STATE_JSON', '')
lessons = os.environ.get('LAST_LESSONS', '')
uncommitted = os.environ.get('UNCOMMITTED', '0')

lines = ['=== ETAT DE GOUVERNANCE (PreCompact) ===']

if build_json:
    try:
        d = json.loads(build_json)
        status = d.get('status', 'unknown')
        completed = d.get('completed', [])
        current = d.get('current', 'none')
        project = d.get('project', '?')
        lines.append(f'BUILD [{project}] status={status} | completes={completed} | courant={current}')
    except:
        pass

if uncommitted and uncommitted != '0':
    lines.append(f'ATTENTION : {uncommitted} fichier(s) modifie(s) non committe(s)')

if lessons:
    lines.append('Dernieres lecons :')
    lines.append(lessons)

lines.append('=== FIN ETAT GOUVERNANCE ===')
context = '\n'.join(lines)
print(json.dumps({'systemMessage': context}))
PYEOF

exit 0
