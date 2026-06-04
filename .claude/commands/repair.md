# /repair — Réparer et compléter un projet Archipel existant

Audite l'état du projet courant et complète **uniquement ce qui manque**.
Ne pose aucune question. Ne réinitialise rien. 100% idempotent.

Utiliser quand :
- `/bootstrap` a tourné partiellement
- Des fichiers Archipel ont été mis à jour et doivent être synchronisés
- Un projet importé manuellement manque de certains éléments

---

## Protocole

### 1. Audit complet

```python
import os, json

PROJECT_DIR = os.getcwd()
ARCHIPEL_HOME = os.environ.get("ARCHIPEL_HOME", "/Users/caussni/Dev/Archipel")

checks = {
    "docs/PRD.md":                  os.path.exists(f"{PROJECT_DIR}/docs/PRD.md"),
    "docs/tasks.md":                os.path.exists(f"{PROJECT_DIR}/docs/tasks.md"),
    ".archipel/project.json":       os.path.exists(f"{PROJECT_DIR}/.archipel/project.json"),
    ".archipel/data-patterns.json": os.path.exists(f"{PROJECT_DIR}/.archipel/data-patterns.json"),
    "hooks (16 fichiers)":          len(os.listdir(f"{PROJECT_DIR}/.claude/hooks")) >= 16 if os.path.exists(f"{PROJECT_DIR}/.claude/hooks") else False,
    "agents (38 agents)":           len(os.listdir(f"{PROJECT_DIR}/.claude/agents")) >= 38 if os.path.exists(f"{PROJECT_DIR}/.claude/agents") else False,
    ".claude/settings.json":        os.path.exists(f"{PROJECT_DIR}/.claude/settings.json"),
    "CLAUDE.md":                    os.path.exists(f"{PROJECT_DIR}/CLAUDE.md"),
    "skills/":                      os.path.exists(f"{PROJECT_DIR}/skills"),
    ".mcp.json":                    os.path.exists(f"{PROJECT_DIR}/.mcp.json"),
    "tasks/lessons.md":             os.path.exists(f"{PROJECT_DIR}/tasks/lessons.md"),
    "tasks/live-events.jsonl":      os.path.exists(f"{PROJECT_DIR}/tasks/live-events.jsonl"),
    "apps/web/":                    os.path.exists(f"{PROJECT_DIR}/apps/web"),
    "apps/api/":                    os.path.exists(f"{PROJECT_DIR}/apps/api"),
}

# Vérifications supplémentaires project.json
pj_path = f"{PROJECT_DIR}/.archipel/project.json"
if os.path.exists(pj_path):
    pj = json.load(open(pj_path))
    checks["project.json → ports"]  = "ports" in pj
    checks["project.json → stage"]  = "stage" in pj
    checks["project.json → services"] = "services" in pj

ok      = [k for k, v in checks.items() if v]
missing = [k for k, v in checks.items() if not v]

print("=" * 55)
print("AUDIT /repair")
print("=" * 55)
print(f"\n✅ OK ({len(ok)}) :", ", ".join(ok[:5]), "..." if len(ok) > 5 else "")
print(f"\n❌ MANQUANT ({len(missing)}) :")
for m in missing: print(f"   • {m}")

if not missing:
    print("\n✅ Projet complet — rien à réparer.")
```

Si `missing` est vide → afficher "Projet complet" et s'arrêter.

### 2. Réparer uniquement ce qui manque

Pour chaque item manquant, exécuter l'action correspondante :

#### hooks manquants ou incomplets
```bash
cp -r "$ARCHIPEL_HOME/.claude/hooks" .claude/
echo "✅ Hooks copiés ($(ls .claude/hooks/*.sh | wc -l | tr -d ' ') fichiers)"
```

#### agents manquants ou incomplets
```bash
cp -r "$ARCHIPEL_HOME/.claude/agents" .claude/
echo "✅ Agents copiés ($(ls .claude/agents/*.md | wc -l | tr -d ' ') agents)"
```

#### settings.json manquant
```bash
cp "$ARCHIPEL_HOME/.claude/settings.json" .claude/settings.json
sed -i '' "s|$ARCHIPEL_HOME|$(pwd)|g" .claude/settings.json
echo "✅ settings.json configuré"
```

#### CLAUDE.md manquant
Générer depuis `.archipel/project.json` — voir template dans bootstrap.md.

#### skills/ manquants
```bash
cp -r "$ARCHIPEL_HOME/skills" .
echo "✅ Skills copiés"
```

#### .mcp.json manquant
```bash
cp "$ARCHIPEL_HOME/.mcp.json" .mcp.json
echo "✅ .mcp.json copié"
```

#### docs/tasks.md manquant (si docs/PRD.md présent)
Lire `docs/PRD.md`, extraire la section Milestones, générer `docs/tasks.md` avec tâches `[ ]` et tags `[EXEC]`.

#### .archipel/data-patterns.json manquant
Extraire les entités métier de `docs/PRD.md` (statuts, codes, noms visibles dans les pages) et générer le fichier.

#### project.json → ports manquants
```python
import json, socket

def free_port(base):
    for p in range(base, base+20):
        s = socket.socket()
        try:
            s.bind(('', p)); s.close(); return p
        except: s.close()
    return base

d = json.load(open('.archipel/project.json'))
d['ports'] = {'web': free_port(3000), 'api': free_port(8000), 'db': free_port(5432)}
d.setdefault('stage', 'discover')
json.dump(d, open('.archipel/project.json', 'w'), indent=2)
print(f"✅ Ports ajoutés : {d['ports']}")
```

#### tasks/lessons.md ou live-events.jsonl manquants
```bash
mkdir -p tasks
[ ! -f tasks/lessons.md ] && echo "# Lessons Learned\n\n## Entrées\n\n*Nouvelles entrées au-dessus.*" > tasks/lessons.md
[ ! -f tasks/live-events.jsonl ] && touch tasks/live-events.jsonl
echo "✅ tasks/ initialisé"
```

#### apps/web/ ou apps/api/ manquants
```bash
mkdir -p apps/web/src/{app,components/{ui,features},lib,hooks,types}
mkdir -p apps/api/{routers,services,repositories,models,schemas,dependencies,tests}
echo "✅ Structure monorepo créée"
```

### 3. Re-audit final

Relancer l'audit du point 1 — afficher le nouveau rapport.
Si tous les items sont ✅ → "Réparation terminée. Projet prêt."
Si des items restent ❌ → les signaler pour correction manuelle.

### 4. Enregistrer dans Archipel Monitor (si absent)

```python
import json, os

archipel_home = os.environ.get("ARCHIPEL_HOME", "/Users/caussni/Dev/Archipel")
projects_file = f"{archipel_home}/.archipel/projects.json"
project_path = os.getcwd()

pj = json.load(open(".archipel/project.json"))
project_name = pj.get("name", os.path.basename(project_path))

if os.path.exists(projects_file):
    d = json.load(open(projects_file))
    if not any(p["path"] == project_path for p in d.get("projects", [])):
        d.setdefault("projects", []).append({"name": project_name, "path": project_path})
        json.dump(d, open(projects_file, "w"), indent=2)
        print(f"✅ '{project_name}' enregistré dans Archipel Monitor")
    else:
        print(f"ℹ️  '{project_name}' déjà dans Archipel Monitor")
```

---

## Critère de sortie

Re-audit final : **tous les items ✅**.
