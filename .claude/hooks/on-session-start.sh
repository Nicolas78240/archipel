#!/bin/bash
# Hook : SessionStart
# Rôle : Charger automatiquement le contexte du projet au demarrage.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

export PROJECT_JSON=$(cat "$PROJECT_DIR/.archipel/project.json" 2>/dev/null || echo "")
export BUILD_STATE=$(cat "$PROJECT_DIR/.archipel/build-state.json" 2>/dev/null || echo "")
export LAST_LESSONS=$(grep -A 8 "^###" "$PROJECT_DIR/tasks/lessons.md" 2>/dev/null | head -40 || echo "")
export PENDING_COUNT=$(grep -c "^- \[ \]" "$PROJECT_DIR/docs/tasks.md" 2>/dev/null || echo "0")

python3 << 'PYEOF' 2>/dev/null
import json, os

project_json = os.environ.get('PROJECT_JSON', '')
build_state = os.environ.get('BUILD_STATE', '')
lessons = os.environ.get('LAST_LESSONS', '')
pending = os.environ.get('PENDING_COUNT', '0')

parts = []

if project_json:
    try:
        d = json.loads(project_json)
        name = d.get('name', '?')
        ptype = d.get('type', '?')
        stack = ', '.join(d.get('stack', []))
        parts.append(f"Projet : {name} ({ptype}) — Stack : {stack}")
    except:
        pass

if build_state:
    try:
        d = json.loads(build_state)
        status = d.get('status', 'unknown')
        completed = d.get('completed', [])
        current = d.get('current', None)
        if status in ('interrupted', 'running'):
            parts.append(f"Build interrompu — completes: {completed}, en cours: {current}")
        elif status == 'completed':
            parts.append("Build termine — tous les milestones completes")
    except:
        pass

if pending and pending != '0':
    parts.append(f"Taches en attente : {pending} milestone(s)")

if lessons:
    parts.append(f"Dernieres lecons :\n{lessons}")

if parts:
    context = '\n'.join(parts)
    print(json.dumps({'systemMessage': context}))
PYEOF

exit 0
