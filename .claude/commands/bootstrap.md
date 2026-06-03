# /bootstrap — Wizard nouveau projet

Lance le wizard d'initialisation pour un nouveau projet Archipel.
Pose 5 questions, écrit `.archipel/project.json`, crée la structure monorepo,
et installe les commandes + skills Archipel dans le projet.
S'arrête quand `project.json` existe, la structure est créée et les commandes sont en place.

---

## Prérequis

La variable `ARCHIPEL_HOME` doit pointer vers le repo Archipel :
```bash
export ARCHIPEL_HOME=/Users/caussni/Dev/Archipel
# (ajouter dans ~/.zshrc pour la rendre permanente)
```

---

## Protocole d'exécution

### Étape 1 — Poser les 5 questions (AskUserQuestion, max 4 à la fois)

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

### Étape 3b — Installer les commandes et skills Archipel

```bash
ARCHIPEL_HOME="${ARCHIPEL_HOME:-/Users/caussni/Dev/Archipel}"
PROJECT_PATH=$(pwd)

# Vérifier que ARCHIPEL_HOME est accessible
if [ ! -d "$ARCHIPEL_HOME" ]; then
  echo "❌ ARCHIPEL_HOME non trouvé : $ARCHIPEL_HOME"
  echo "   Définir : export ARCHIPEL_HOME=/chemin/vers/archipel"
  exit 1
fi

# Copier les commandes Archipel
mkdir -p .claude
cp -r "$ARCHIPEL_HOME/.claude/commands" .claude/
echo "✅ Commandes Archipel copiées dans .claude/commands/"

# Copier les hooks Archipel (version live — pas les templates statiques)
cp -r "$ARCHIPEL_HOME/.claude/hooks" .claude/
echo "✅ Hooks Archipel copiés dans .claude/hooks/ (version live)"

# Copier les agents Archipel
cp -r "$ARCHIPEL_HOME/.claude/agents" .claude/
echo "✅ Agents Archipel copiés dans .claude/agents/ (version live)"

# Copier les skills
cp -r "$ARCHIPEL_HOME/skills" .
echo "✅ Skills Archipel copiés dans skills/"

# Copier les templates (configs prêtes à l'emploi par type/stack)
cp -r "$ARCHIPEL_HOME/.archipel/templates" .archipel/
echo "✅ Templates Archipel copiés dans .archipel/templates/"

# Copier et adapter settings.json
cp "$ARCHIPEL_HOME/.claude/settings.json" .claude/settings.json
sed -i '' "s|$ARCHIPEL_HOME|$PROJECT_PATH|g" .claude/settings.json
echo "✅ .claude/settings.json configuré pour $PROJECT_PATH"

# Copier .mcp.json (Figma + Atlassian MCPs)
cp "$ARCHIPEL_HOME/.mcp.json" .mcp.json
echo "✅ .mcp.json copié"
echo "   → Configurer les variables d'env si pas encore fait :"
echo "     export FIGMA_ACCESS_TOKEN=fig_xxx"
echo "     export ATLASSIAN_URL=https://xxx.atlassian.net"
echo "     export ATLASSIAN_EMAIL=xxx"
echo "     export ATLASSIAN_API_TOKEN=xxx"

# Générer CLAUDE.md — lu automatiquement par Claude Code à chaque session
PROJECT_NAME=$(python3 -c "import json; print(json.load(open('.archipel/project.json'))['name'])" 2>/dev/null || echo "<nom>")
PORT_WEB=$(python3 -c "import json; print(json.load(open('.archipel/project.json')).get('ports',{}).get('web',3000))" 2>/dev/null || echo "3000")
PORT_API=$(python3 -c "import json; print(json.load(open('.archipel/project.json')).get('ports',{}).get('api',8000))" 2>/dev/null || echo "8000")
PORT_DB=$(python3 -c "import json; print(json.load(open('.archipel/project.json')).get('ports',{}).get('db',5432))" 2>/dev/null || echo "5432")

cat > CLAUDE.md << CLAUDEEOF
# CLAUDE.md — $PROJECT_NAME

Projet **Archipel**. Ports : web=$PORT_WEB, api=$PORT_API, db=$PORT_DB.

---

## Démarrage

\`\`\`bash
/build    # Lance le build complet via build-orchestrator (M1 → dernier milestone)
\`\`\`

**\`/build\` invoque \`build-orchestrator\`** qui orchestre tout de façon autonome.
Ne jamais invoquer les agents manuellement — passer par \`/build\`.
Pour reprendre un build interrompu : \`/build\` relit \`.archipel/build-state.json\`.

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

- `.archipel/project.json` valide avec `services.web`, `services.api`, `gcp_region`, `azure_resource_group`
- Structure monorepo créée (`apps/web/`, `apps/api/`, `workers/`, `shared/db/`)
- `tasks/lessons.md` et `tasks/session-log.md` initialisés
- `.claude/commands/` et `skills/` présents dans le projet
- `.claude/settings.json` et `.mcp.json` configurés
- Premier commit git effectué
