# /bootstrap — Wizard nouveau projet

Lance le wizard d'initialisation pour un nouveau projet Archipel.
**Détecte automatiquement si un PRD existe** et adapte le mode en conséquence :
- **Mode PRD** (`docs/PRD.md` présent) → extrait tout depuis le PRD, aucune question
- **Mode wizard** (projet vierge) → pose 5 questions interactives

**Toujours idempotent** : peut être relancé à tout moment sur un projet existant.
Commence par un audit complet (Étape 0) avant toute action.
Ne s'arrête jamais prématurément — même si `project.json` existe déjà.

---

## Prérequis

La variable `ARCHIPEL_HOME` doit pointer vers le repo Archipel :
```bash
export ARCHIPEL_HOME=/Users/caussni/Dev/Archipel
# (ajouter dans ~/.zshrc pour la rendre permanente)
```

---

## Protocole d'exécution

### Étape 0 — Audit de l'état existant (TOUJOURS en premier)

Avant toute action, inspecter ce qui existe déjà et produire un rapport :

```python
import os, json

PROJECT_DIR = os.getcwd()
ARCHIPEL_HOME = os.environ.get("ARCHIPEL_HOME", "/Users/caussni/Dev/Archipel")

checks = {
    # Fondation
    "docs/PRD.md":                     os.path.exists(f"{PROJECT_DIR}/docs/PRD.md"),
    "docs/tasks.md":                   os.path.exists(f"{PROJECT_DIR}/docs/tasks.md"),
    ".archipel/project.json":          os.path.exists(f"{PROJECT_DIR}/.archipel/project.json"),
    ".archipel/data-patterns.json":    os.path.exists(f"{PROJECT_DIR}/.archipel/data-patterns.json"),
    # Archipel
    ".claude/hooks/ (16 fichiers)":    len(os.listdir(f"{PROJECT_DIR}/.claude/hooks")) >= 16 if os.path.exists(f"{PROJECT_DIR}/.claude/hooks") else False,
    ".claude/agents/ (38 agents)":     len(os.listdir(f"{PROJECT_DIR}/.claude/agents")) >= 38 if os.path.exists(f"{PROJECT_DIR}/.claude/agents") else False,
    ".claude/commands/":               os.path.exists(f"{PROJECT_DIR}/.claude/commands"),
    ".claude/settings.json":           os.path.exists(f"{PROJECT_DIR}/.claude/settings.json"),
    "CLAUDE.md":                       os.path.exists(f"{PROJECT_DIR}/CLAUDE.md"),
    "skills/":                         os.path.exists(f"{PROJECT_DIR}/skills"),
    ".mcp.json":                       os.path.exists(f"{PROJECT_DIR}/.mcp.json"),
    "tasks/lessons.md":                os.path.exists(f"{PROJECT_DIR}/tasks/lessons.md"),
    "tasks/live-events.jsonl":         os.path.exists(f"{PROJECT_DIR}/tasks/live-events.jsonl"),
    # Structure
    "apps/web/":                       os.path.exists(f"{PROJECT_DIR}/apps/web"),
    "apps/api/":                       os.path.exists(f"{PROJECT_DIR}/apps/api"),
    ".gitignore":                      os.path.exists(f"{PROJECT_DIR}/.gitignore"),
}

# Vérifications supplémentaires sur project.json
pj_path = f"{PROJECT_DIR}/.archipel/project.json"
pj_ok = {}
if os.path.exists(pj_path):
    pj = json.load(open(pj_path))
    pj_ok["project.json → ports définis"]  = "ports" in pj
    pj_ok["project.json → stage défini"]   = "stage" in pj
    pj_ok["project.json → services définis"] = "web" in pj.get("services",{})

ok    = {k: v for k, v in {**checks, **pj_ok}.items() if v}
missing = {k: v for k, v in {**checks, **pj_ok}.items() if not v}

print("=" * 50)
print("AUDIT BOOTSTRAP — état actuel")
print("=" * 50)
print(f"\n✅ Présent ({len(ok)}) :")
for k in ok: print(f"   {k}")
print(f"\n❌ Manquant ({len(missing)}) :")
for k in missing: print(f"   {k}")
print(f"\n→ Actions nécessaires : {len(missing)}")
```

**Afficher le rapport à l'utilisateur.** Puis :
- Si tout est ✅ → afficher "Projet déjà complet — rien à faire" et s'arrêter
- Si manquants → continuer les étapes suivantes **uniquement pour les éléments manquants**
- Chaque étape vérifie si son livrable existe déjà avant d'agir (idempotent)

**Détecter le mode :**

```bash
PRD_EXISTS=$(test -f docs/PRD.md && echo "OUI" || echo "NON")
```

**Si `PRD_EXISTS == OUI` → Mode PRD (sauter Étape 1, aller directement Étape 1-PRD)**
**Si `PRD_EXISTS == NON` → Mode wizard (continuer Étape 1 normale)**

---

### Étape 1-PRD — Extraire les infos depuis docs/PRD.md (mode PRD uniquement)

Lire `docs/PRD.md` et extraire automatiquement :

```python
# Extraction depuis le PRD
import re

prd = open('docs/PRD.md').read()

# Nom du projet (depuis le titre H1 ou le nom du dossier courant)
name_match = re.search(r'^#\s+(?:PRD\s+—\s+)?(.+?)$', prd, re.MULTILINE)
PROJECT_NAME = name_match.group(1).strip() if name_match else os.path.basename(os.getcwd())

# Description (première ligne non-vide après le titre)
desc_match = re.search(r'\*\*(?:Application|Projet|Description|Vision)\*\*\s*:?\s*(.+?)$', prd, re.MULTILINE)
if not desc_match:
    # Fallback : première phrase du paragraphe Vision
    vision_match = re.search(r'##\s+\d+\.\s+Vision\s*\n+(.+?)\.', prd, re.DOTALL)
    desc_match = vision_match
PROJECT_DESC = desc_match.group(1).strip()[:100] if desc_match else PROJECT_NAME

# Type (clubmed si mention Club Med / Azure / GitLab, sinon perso)
PROJECT_TYPE = "clubmed" if re.search(r'club.?med|azure|gitlab', prd, re.IGNORECASE) else "perso"

# Stack (chercher les mots-clés techniques)
stack = []
if re.search(r'next\.?js|react|frontend', prd, re.IGNORECASE): stack.append("nextjs")
if re.search(r'fastapi|python|api', prd, re.IGNORECASE): stack.append("python-api")
if re.search(r'worker|queue|async.job', prd, re.IGNORECASE): stack.append("workers")
PROJECT_STACK = stack if stack else ["nextjs", "python-api"]

# PostgreSQL (toujours cloud-managed si clubmed, self-hosted si perso avec docker)
PROJECT_PG = "cloud-managed"

print(f"Extrait du PRD :")
print(f"  name        : {PROJECT_NAME}")
print(f"  description : {PROJECT_DESC}")
print(f"  type        : {PROJECT_TYPE}")
print(f"  stack       : {PROJECT_STACK}")
print(f"  postgresql  : {PROJECT_PG}")
```

Afficher un résumé à l'utilisateur et lui demander confirmation en une question :

```
AskUserQuestion :
"Ces informations extraites du PRD sont-elles correctes ?
  - Nom : <PROJECT_NAME>
  - Type : <PROJECT_TYPE>
  - Stack : <PROJECT_STACK>
  Continuer avec ces valeurs ou ajuster ?"

Options :
  "✅ Correct — continuer"
  "✏️ Ajuster le type (perso/clubmed)"
  "✏️ Ajuster la stack"
```

Si l'utilisateur confirme → utiliser ces valeurs pour toute la suite.
**Aller directement à l'Étape 2 en sautant Étape 1.**

---

### Étape 1 — Poser les 5 questions (AskUserQuestion — mode wizard uniquement)

**Batch 1 (4 questions) :**
1. **Nom du projet** — texte libre (suggestions : nom du repo, nom du domaine)
2. **Description** — une phrase max (pour les README et PRD)
3. **Type de projet** — options : `perso` | `clubmed`
4. **Stack activée** — multi-sélection : `nextjs` | `python-api` | `workers`

**Batch 2 (1 question) :**
5. **PostgreSQL** — options : `cloud-managed` | `self-hosted`

### Étape 2 — Écrire `.archipel/project.json`

Les noms de services Cloud sont dérivés automatiquement depuis `name` (slugifié) :
- `services.web` → `<name>-web` (Cloud Run perso / Container App clubmed)
- `services.api` → `<name>-api`

```json
{
  "name": "<nom>",
  "description": "<description>",
  "type": "<perso|clubmed>",
  "stage": "discover",
  "stack": ["<nextjs>", "<python-api>", "<workers>"],
  "postgresql": "<cloud-managed|self-hosted>",
  "git_remote": "<github|gitlab>",
  "ci": "<github-actions|gitlab-ci>",
  "cloud": "<gcp|azure>",
  "deploy_strategy": "<direct|staging-prod>",
  "pg_service": "<cloud-sql|azure-database>",
  "gcp_region": "europe-west1",
  "azure_resource_group": "<nom-slug>",
  "services": {
    "web": "<nom-slug>-web",
    "api": "<nom-slug>-api"
  },
  "ports": {
    "web": "<port-libre-3000+>",
    "api": "<port-libre-8000+>",
    "db": "<port-libre-5432+>"
  },
  "created_at": "<ISO date>"
}
```

**Dérivation automatique depuis `type` :**

| Config           | perso             | clubmed               |
|------------------|-------------------|-----------------------|
| `git_remote`     | `github`          | `gitlab`              |
| `ci`             | `github-actions`  | `gitlab-ci`           |
| `cloud`          | `gcp`             | `azure`               |
| `deploy_strategy`| `direct`          | `staging-prod`        |
| `pg_service`     | `cloud-sql`       | `azure-database`      |

### Étape 2b — Détecter et figer les ports libres

Avant de créer `docker-compose.yml`, trouver les ports libres pour éviter les conflits entre projets.

```bash
# Trouver les premiers ports libres pour chaque service
find_free_port() {
  local BASE=$1
  for PORT in $(seq $BASE $((BASE+20))); do
    if ! lsof -i ":$PORT" 2>/dev/null | grep -q LISTEN; then
      echo $PORT
      return
    fi
  done
  echo $BASE  # fallback
}

PORT_WEB=$(find_free_port 3000)
PORT_API=$(find_free_port 8000)
PORT_DB=$(find_free_port 5432)

echo "Ports assignés : web=$PORT_WEB api=$PORT_API db=$PORT_DB"

# Mettre à jour project.json avec les ports figés
python3 -c "
import json
d = json.load(open('.archipel/project.json'))
d['ports'] = {'web': $PORT_WEB, 'api': $PORT_API, 'db': $PORT_DB}
json.dump(d, open('.archipel/project.json', 'w'), indent=2)
print('✅ Ports figés dans project.json')
"
```

Ces ports sont utilisés dans `docker-compose.yml` et dans `.env`. Une fois figés, ils ne changent jamais pour ce projet — même si d'autres projets démarrent entre-temps.

### Étape 2b-bis — Créer `.archipel/data-patterns.json`

Ce fichier définit les patterns métier que `on-stop.sh` vérifie dans les pages web pour détecter les données vides.

```bash
# Créer .archipel/data-patterns.json
# Adapter pages[] et patterns[] au projet (termes métier visibles dans les pages)
cat > .archipel/data-patterns.json << 'EOF'
{
  "pages": ["/"],
  "patterns": ["TODO_adapter_au_projet"]
}
EOF
echo "✅ data-patterns.json créé — adapter pages[] et patterns[] au domaine métier"
```

**Important** : `patterns` doit contenir des termes qui apparaissent dans le HTML SSR quand les données sont présentes (noms propres, codes, labels visibles). Exemple pour un tracker NHL : `["MTL", "BUF", "Anderson"]`. Exemple pour un Gantt : `["Sprint", "Milestone", "2026"]`.

**En mode PRD** : extraire les patterns depuis `docs/PRD.md` → section `data-patterns.json` si présente, sinon utiliser les mots-clés métier du PRD (noms d'entités, statuts, codes).

### Étape 2b-ter — Générer `docs/tasks.md` depuis le PRD (mode PRD uniquement)

**Si `docs/tasks.md` n'existe pas encore ET que `docs/PRD.md` est présent** :

Lire la section **Milestones** du PRD et générer `docs/tasks.md` avec :
- Un milestone par section PRD (M1, M2... ou noms métier)
- Les tâches extraites de chaque milestone
- Les gates `[EXEC]` extraits de la section "Gates [EXEC]" du PRD si présente
- Toutes les tâches à `[ ]` (non cochées)

```python
# Exemple de génération depuis le PRD
# L'agent lit docs/PRD.md section "Milestones" et reproduit
# le backlog en format tasks.md avec [ ] et [EXEC] tags
```

**Si `docs/tasks.md` existe déjà** → ne pas écraser, utiliser tel quel.

### Étape 2c — Enregistrer le projet dans Archipel Monitor

Ajouter le projet dans `.archipel/projects.json` du repo Archipel source :

```bash
ARCHIPEL_HOME="${ARCHIPEL_HOME:-/Users/caussni/Dev/Archipel}"
PROJECTS_FILE="$ARCHIPEL_HOME/.archipel/projects.json"
PROJECT_PATH="$(pwd)"
PROJECT_NAME="<nom du projet>"

python3 << 'PYEOF'
import json, os

f = os.environ.get('PROJECTS_FILE', '')
path = os.environ.get('PROJECT_PATH', '')
name = os.environ.get('PROJECT_NAME', '')

if not f or not os.path.exists(f):
    print("⚠️  projects.json absent — monitor non mis à jour")
else:
    d = json.load(open(f))
    projects = d.get('projects', [])
    # Éviter les doublons
    if not any(p['path'] == path for p in projects):
        projects.append({'name': name, 'path': path})
        d['projects'] = projects
        json.dump(d, open(f, 'w'), indent=2)
        print(f"✅ Projet '{name}' enregistré dans Archipel Monitor")
    else:
        print(f"✅ Projet '{name}' déjà enregistré")
PYEOF
```

### Étape 3 — Créer la structure monorepo

```bash
# Dossiers applicatifs
mkdir -p apps/web/src/{app,components/{ui,features},lib,hooks,types}
mkdir -p apps/api/{routers,services,repositories,models,schemas,dependencies,tests}
mkdir -p workers
mkdir -p shared/db/{prisma,alembic/versions}

# Documentation et tâches
mkdir -p docs tasks

# CI/CD
mkdir -p ci/github-actions ci/gitlab-ci
mkdir -p .archipel/config

# .gitignore
cat > .gitignore << 'EOF'
node_modules/
.env
.env.*
!.env.example
__pycache__/
*.py[cod]
.pytest_cache/
.coverage
coverage/
.next/
dist/
*.log
.DS_Store
EOF

# Initialiser tasks/lessons.md
cat > tasks/lessons.md << 'EOF'
# Lessons Learned — <nom du projet>

## Format d'une leçon

```markdown
### YYYY-MM-DD — [AGENT] Titre court

**Contexte** : dans quelle situation l'erreur s'est produite
**Erreur** : ce qui a mal tourné (code, décision, hypothèse)
**Correction** : ce qui a été fait pour corriger
**Règle** : formulation actionnable pour ne pas reproduire
**Tags** : #architecture | #security | #performance | #maintainability | #resilience | #db | #ci | #config
```

---

## Entrées

*Nouvelles entrées au-dessus de cette ligne.*
EOF

# Initialiser tasks/session-log.md
cat > tasks/session-log.md << 'EOF'
# Session Log — <nom du projet>

Format :
### YYYY-MM-DD — /commande [JIRA-ID optionnel]
**Action** : ce qui a été fait
**Livrable** : fichiers créés ou modifiés
**Résultat** : OK | KO | Partiel
**Prochaine étape** : /commande suggérée

---

## Entrées

EOF
```

### Étape 3b — Installer les commandes et skills Archipel (idempotent)

Chaque action vérifie si son livrable est déjà présent avant de l'écraser.

```bash
ARCHIPEL_HOME="${ARCHIPEL_HOME:-/Users/caussni/Dev/Archipel}"
PROJECT_PATH=$(pwd)

# Vérifier que ARCHIPEL_HOME est accessible
if [ ! -d "$ARCHIPEL_HOME" ]; then
  echo "❌ ARCHIPEL_HOME non trouvé : $ARCHIPEL_HOME"
  exit 1
fi

mkdir -p .claude .archipel

# Hooks — TOUJOURS copier (version live, peut avoir été mis à jour)
cp -r "$ARCHIPEL_HOME/.claude/hooks" .claude/
HOOKS_COUNT=$(ls .claude/hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')
echo "✅ Hooks copiés ($HOOKS_COUNT fichiers)"

# Agents — TOUJOURS copier (version live, peut avoir été mis à jour)
cp -r "$ARCHIPEL_HOME/.claude/agents" .claude/
AGENTS_COUNT=$(ls .claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "✅ Agents copiés ($AGENTS_COUNT agents)"

# Commands — copier si absent ou incomplet
CMD_COUNT=$(ls .claude/commands/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$CMD_COUNT" -lt 10 ]; then
  cp -r "$ARCHIPEL_HOME/.claude/commands" .claude/
  echo "✅ Commands Archipel copiées"
else
  echo "ℹ️  Commands déjà présentes ($CMD_COUNT fichiers) — skip"
fi

# Skills — copier si absent
if [ ! -d "skills" ] || [ -z "$(ls skills/*.md 2>/dev/null)" ]; then
  cp -r "$ARCHIPEL_HOME/skills" .
  echo "✅ Skills Archipel copiés"
else
  echo "ℹ️  Skills déjà présents — skip"
fi

# Templates — copier si absent
if [ ! -d ".archipel/templates" ]; then
  cp -r "$ARCHIPEL_HOME/.archipel/templates" .archipel/
  echo "✅ Templates copiés"
else
  echo "ℹ️  Templates déjà présents — skip"
fi

# settings.json — copier et adapter si absent ou si hooks ont changé
cp "$ARCHIPEL_HOME/.claude/settings.json" .claude/settings.json
sed -i '' "s|$ARCHIPEL_HOME|$PROJECT_PATH|g" .claude/settings.json
echo "✅ .claude/settings.json configuré"

# .mcp.json — copier si absent
if [ ! -f ".mcp.json" ]; then
  cp "$ARCHIPEL_HOME/.mcp.json" .mcp.json
  echo "✅ .mcp.json copié"
else
  echo "ℹ️  .mcp.json déjà présent — skip"
fi

# Générer CLAUDE.md — TOUJOURS régénérer (ports peuvent avoir changé)
PROJECT_NAME=$(python3 -c "import json; print(json.load(open('.archipel/project.json'))['name'])" 2>/dev/null || echo "<nom>")
PORT_WEB=$(python3 -c "import json; print(json.load(open('.archipel/project.json')).get('ports',{}).get('web',3000))" 2>/dev/null || echo "3000")
PORT_API=$(python3 -c "import json; print(json.load(open('.archipel/project.json')).get('ports',{}).get('api',8000))" 2>/dev/null || echo "8000")
PORT_DB=$(python3 -c "import json; print(json.load(open('.archipel/project.json')).get('ports',{}).get('db',5432))" 2>/dev/null || echo "5432")

cat > CLAUDE.md << CLAUDEEOF
# CLAUDE.md — $PROJECT_NAME

Projet **Archipel**. Ports : web=$PORT_WEB, api=$PORT_API, db=$PORT_DB.

---

## Démarrage

**Pour lancer le build complet, dire à Claude :**

> **Invoque l'agent build-orchestrator**

L'agent lit \`docs/tasks.md\`, \`docs/PRD.md\`, \`tasks/lessons.md\`
et \`.archipel/build-state.json\` (reprise automatique si build interrompu),
puis orchestre tout de façon autonome jusqu'au build report final.

**Ne jamais invoquer les agents dev manuellement** — tout passe par build-orchestrator.

---

## Structure

\`\`\`
docs/
  PRD.md          ← vision, user stories, specs features
  tasks.md        ← backlog avec tags [EXEC] (actions à vérifier en DB/API)
  IMPL-*.md       ← plans techniques générés par architect pendant le build
tasks/
  lessons.md      ← leçons des builds précédents — lues par les agents
  live-events.jsonl ← feed Archipel Live (non versionné)
.archipel/
  project.json    ← config (nom, ports, stack, cloud)
  build-state.json ← état du build en cours
\`\`\`

---

## Règles critiques

| Règle | Détail |
|-------|--------|
| **Jamais coder directement** | Toujours passer par un agent via \`/build\` ou \`/feature\` |
| **Gates [EXEC]** | Tâche \`[EXEC]\` dans tasks.md = exécuter ET vérifier avant de clore le milestone |
| **float pas Decimal** | Colonnes NUMERIC PostgreSQL → \`float\` dans Pydantic (pas \`Decimal\`) |
| **PagedResponse normalisé** | Les helpers \`api.ts\` retournent l'array directement, jamais \`data.items\` dans les pages |
| **dynamic(ssr:false)** | Uniquement dans un fichier \`"use client"\` — jamais dans un Server Component |
CLAUDEEOF

echo "✅ CLAUDE.md généré"

# Git init et premier commit
git init
git add .
git commit -m "chore(config): bootstrap Archipel project [$(date -I)]"
echo "✅ Premier commit effectué"
```

### Étape 3c — Trident UI (clubmed + nextjs uniquement)

**Si `type != clubmed` ou `stack` ne contient pas `nextjs` → sauter cette étape.**

#### Question SidebarLayout (AskUserQuestion)

Demander via AskUserQuestion :

**Veux-tu utiliser le SidebarLayout Trident comme base du projet ?**
- `Oui (recommandé)` — header, nav, sidebar gérés par Trident. Référence : [docs SidebarLayout](https://develop.trident-ui.pro.clubmed/docs/components/sidebar-layout.html)
- `Non` — layout custom (rare, réservé aux pages standalone sans navigation)

**Si `Non` → sauter à l'Étape 4.**

---

#### Installation Trident UI (si `Oui`)

Les fichiers de config viennent des templates Archipel (`$PROJECT_PATH/.archipel/templates/clubmed/web/`).

```bash
TEMPLATES="$PROJECT_PATH/.archipel/templates/clubmed/web"
cd apps/web

# 1. Tailwind 4 — obligatoire (Trident est incompatible avec Tailwind 3)
npm install -D tailwindcss@^4.2.1 @tailwindcss/postcss@^4.2.1 postcss@^8.5

# 2. Configs depuis les templates
cp "$TEMPLATES/postcss.config.js"   postcss.config.js
cp "$TEMPLATES/tailwind.config.ts"  tailwind.config.ts
cp "$TEMPLATES/next.config.ts"      next.config.ts
cp "$TEMPLATES/globals.css"         src/app/globals.css
echo "✅ Configs Tailwind 4 + Trident tokens installées"

# 3. Installer SidebarLayout depuis le registry Trident
# Le registry a un bug : il liste @/ui/hooks/useSlots comme dépendance npm.
# Solution : registry pour le composant + useSlots depuis le template.
mkdir -p src/hooks
echo "y" | npx shadcn@latest add https://develop.trident-ui.pro.clubmed/r/sidebar-layout.json || true

# 4. useSlots.ts depuis le template (corrige le bug du registry)
cp "$TEMPLATES/hooks/useSlots.ts" src/hooks/useSlots.ts
echo "✅ useSlots.ts créé (fix bug registry)"

cd ../..
echo "✅ Trident UI prêt (Tailwind 4 + SidebarLayout)"
echo "   ⚠️  Règle d'or : wrapper tout contenu app avec --spacing: 0.25rem"
echo "   Voir skills/cm-trident.md → pattern AppLayout complet"
```

### Étape 3c-bis — Générer tasks.md si absent (mode PRD)

**Si `docs/tasks.md` n'existe pas ET que `docs/PRD.md` est présent** :

Lire `docs/PRD.md`, trouver la section **Milestones** et générer `docs/tasks.md` :
- Reproduire chaque milestone avec ses tâches à `[ ]`
- Conserver les `[EXEC]` tags si présents dans le PRD
- Ne PAS écraser si `tasks.md` existe déjà

```bash
if [ ! -f "docs/tasks.md" ] && [ -f "docs/PRD.md" ]; then
  echo "⚠️  docs/tasks.md absent — génération depuis le PRD..."
  # Lire le PRD et extraire la section Milestones → générer tasks.md
  # L'agent extrait les milestones M1..M6 et leurs tâches, les convertit en [ ] / [EXEC]
  echo "✅ docs/tasks.md généré depuis PRD"
else
  echo "ℹ️  docs/tasks.md déjà présent ou pas de PRD — skip"
fi
```

### Étape 3c-ter — Générer data-patterns.json si absent

**Si `.archipel/data-patterns.json` n'existe pas** :

En mode PRD : extraire les entités métier du PRD (noms de statuts, codes, labels visibles dans les pages) et générer `data-patterns.json`.

```bash
if [ ! -f ".archipel/data-patterns.json" ]; then
  # Extraire depuis le PRD : section data-patterns.json si présente, sinon entités métier
  # Générer le fichier avec pages[] et patterns[]
  echo "✅ .archipel/data-patterns.json généré"
fi
```

### Étape 4 — Adapter les fichiers CI selon le type

**Si `type == perso` :**
- Créer un stub `ci/github-actions/deploy.yml` :
  ```bash
  cat > ci/github-actions/deploy.yml << 'EOF'
  name: Deploy
  on:
    push:
      branches: [main]
  jobs:
    deploy:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: TODO — configurer le deploy GCP
          run: echo "deploy-web-here"
  EOF
  ```
- Écrire dans `tasks/session-log.md` :
  ```
  ### <ISO> — /bootstrap
  **Action** : Nouveau projet perso initialisé
  **Livrable** : .archipel/project.json, structure monorepo, CI stub, commandes Archipel
  **Résultat** : OK
  **Prochaine étape** : /discover ou /spec
  ```

**Si `type == clubmed` :**
- Créer un stub `ci/gitlab-ci/deploy.yml`
- Même format de session-log

### Étape 5 — Valider

```bash
test -f .archipel/project.json && \
python3 -c "
import json
d = json.load(open('.archipel/project.json'))
required = ['name','type','stack','postgresql','git_remote','ci','cloud','services']
missing = [k for k in required if k not in d]
assert not missing, f'Champs manquants : {missing}'
assert 'web' in d['services'] and 'api' in d['services'], 'services.web et services.api requis'
print('✅ project.json valide')
"
test -d apps/web && test -d apps/api && echo "✅ Structure monorepo créée"
test -d .claude/commands && echo "✅ Commandes Archipel présentes"
test -d skills && echo "✅ Skills Archipel présents"
```

Si la validation échoue, corriger et relancer.

---

## Critère de sortie

Relancer l'audit de l'Étape 0 — **tous les items doivent être ✅** :

| Item | Gate |
|------|------|
| `.archipel/project.json` | valide avec ports, stage, services |
| `.claude/hooks/` | 16 fichiers (version live Archipel) |
| `.claude/agents/` | 38 agents (avec signaux Archipel Live) |
| `.claude/settings.json` | chemins adaptés au projet |
| `CLAUDE.md` | instruction "Invoque l'agent build-orchestrator" |
| `docs/tasks.md` | backlog avec `[ ]` et `[EXEC]` tags |
| `.archipel/data-patterns.json` | pages et patterns métier définis |
| `tasks/lessons.md` | initialisé |
| `tasks/live-events.jsonl` | fichier vide créé |
| Structure monorepo | `apps/web/`, `apps/api/` présents |
| Git | au moins 1 commit |

**Si un item est ❌ après bootstrap → corriger et re-exécuter l'étape correspondante.**
Le bootstrap est idempotent — relancer est sans risque.
