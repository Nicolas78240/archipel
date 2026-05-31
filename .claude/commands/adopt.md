# /adopt — Rétro-analyse et onboarding d'un projet existant

Analyse un projet existant, détecte sa stack et ses conventions,
crée `.archipel/project.json` adapté à la réalité du code,
identifie les gaps par rapport aux gates Archipel,
et produit un plan de migration progressif sans rien casser.

---

## Usage

```
/adopt
```

Lancer depuis la racine du projet à adopter.

---

## Protocole d'exécution

### Phase 1 — Cartographie (lecture seule, aucune écriture)

#### 1.1 Structure du projet
```bash
find . -maxdepth 3 -type f \
  \( -name "package.json" -o -name "pyproject.toml" -o -name "requirements*.txt" \
  -o -name "Dockerfile" -o -name "docker-compose*.yml" \
  -o -name "*.yml" -path "*/github*" -o -name "*.yml" -path "*gitlab*" \
  -o -name "schema.prisma" -o -name "alembic.ini" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*"
```

#### 1.2 Détection de stack

**Next.js / React :**
```bash
grep -r "\"next\"" package.json apps/*/package.json */package.json 2>/dev/null
grep -r "\"react\"" package.json apps/*/package.json */package.json 2>/dev/null
```

**FastAPI / Flask / Django :**
```bash
grep -r "fastapi\|flask\|django" requirements*.txt apps/*/requirements*.txt */pyproject.toml 2>/dev/null
```

**Workers / Jobs :**
```bash
find . -name "worker*.py" -o -name "job*.py" -o -name "task*.py" \
  -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null
grep -r "celery\|dramatiq\|arq\|rq" requirements*.txt */pyproject.toml 2>/dev/null
```

**Base de données :**
```bash
# Prisma
find . -name "schema.prisma" -not -path "*/node_modules/*"

# Alembic
find . -name "alembic.ini" -o -name "env.py" -path "*/alembic/*"

# Autres migrations
find . -name "*.sql" -path "*/migrations/*" | head -5
```

#### 1.3 Détection CI/CD existant
```bash
# GitHub Actions
find .github/workflows -name "*.yml" 2>/dev/null

# GitLab CI
test -f .gitlab-ci.yml && echo "GitLab CI trouvé"

# Autres
find . -name "Jenkinsfile" -o -name "circle.yml" -o -name ".travis.yml" 2>/dev/null
```

#### 1.4 Détection du cloud target
```bash
# GCP
grep -r "google-cloud\|gcloud\|cloud run\|cloud sql" . \
  --include="*.yml" --include="*.yaml" --include="*.json" \
  -l 2>/dev/null | head -5

# Azure
grep -r "azure\|containerapp\|az login" . \
  --include="*.yml" --include="*.yaml" \
  -l 2>/dev/null | head -5
```

#### 1.5 État des tests
```bash
# Coverage web
find . -name "jest.config*" -not -path "*/node_modules/*"
find . -name "coverage" -type d -not -path "*/node_modules/*"

# Coverage api
find . -name "pytest.ini" -o -name "pyproject.toml" | xargs grep -l "pytest" 2>/dev/null
find . -name ".coverage" -o -name "coverage.xml" 2>/dev/null
```

#### 1.6 Linting existant
```bash
find . -name ".eslintrc*" -o -name "eslint.config*" -not -path "*/node_modules/*" 2>/dev/null
find . -name "ruff.toml" -o -name ".ruff.toml" 2>/dev/null
grep -r "\[tool.ruff\]" pyproject.toml */pyproject.toml 2>/dev/null
```

#### 1.7 Détection secrets scanning
```bash
find . -name ".gitleaks.toml" -o -name "gitleaks.toml" 2>/dev/null
grep -r "gitleaks\|trufflesecurity\|detect-secrets" .github .gitlab-ci.yml 2>/dev/null | head -5
```

---

### Phase 2 — Questions de contexte (ce que le code ne peut pas dire)

Après la cartographie, présenter un résumé des détections automatiques à l'utilisateur,
puis poser les questions auxquelles l'analyse statique ne peut pas répondre.

**Afficher d'abord le résumé de détection :**
```
Voici ce que j'ai détecté dans ce projet :
- Stack     : <liste>
- CI/CD     : <pipeline détecté ou "non détecté">
- Cloud     : <gcp|azure|aws|"non détecté">
- Tests     : <jest.config trouvé|pytest trouvé|"aucun trouvé">
- Lint      : <eslint|ruff|"aucun trouvé">
- Migrations: <prisma|alembic|sql|"aucune">
- Secrets   : <gitleaks|"aucun scan détecté">
```

**Puis poser les questions via AskUserQuestion (2 batches de 4 max) :**

#### Batch 1 — Identité et intention

1. **Nom du projet**
   - Suggestions dérivées du nom de dossier/package.json
   - Option "Other" pour saisie libre

2. **Description en une phrase**
   - Suggestions dérivées du README ou package.json description si trouvés
   - Option "Other" pour saisie libre

3. **Type de projet** (si non détectable avec certitude depuis le CI/cloud)
   - `perso` — GitHub + GCP
   - `clubmed` — GitLab + Azure

4. **Priorité d'adoption**
   - `vite` — Je veux utiliser /feature et /ship dès maintenant, on adapte ce qui bloque
   - `progressive` — Je veux un plan par étapes, rien de forcé
   - `audit only` — Je veux juste le rapport de gaps, sans écrire project.json

#### Batch 2 — Gaps connus et contraintes

5. **Coverage actuel estimé** (si pas de rapport existant trouvé)
   - `> 80%` — déjà bon
   - `50-80%` — en cours
   - `< 50%` — à construire
   - `inconnu` — jamais mesuré

6. **Migrations DB** (si détection ambiguë)
   - `versionnées` — Prisma/Alembic/Flyway, tout est tracé
   - `scripts manuels` — des .sql qu'on applique à la main
   - `pas de DB` — pas de base de données

7. **CI/CD à garder** (si CI existant détecté)
   - `garder tel quel` — ne pas toucher au pipeline existant
   - `enrichir` — ajouter lint/scan/tests au pipeline existant
   - `remplacer` — utiliser les templates Archipel ci/

8. **Contexte métier** — information libre que l'analyse ne peut pas détecter
   - `projet actif` — en production, des utilisateurs
   - `projet en cours` — en développement, pas encore en prod
   - `projet legacy` — existant, peu maintenu, à moderniser

---

### Phase 3 — Analyse et scoring

Construire le rapport de gaps en croisant détection automatique + réponses utilisateur :

```
## Rapport d'adoption — <nom du projet>
Date : <ISO>

### Stack détectée
- Web : <nextjs X.X | react | vue | none>
- API : <fastapi | flask | django | none>
- Workers : <oui (celery/arq/...) | non>
- DB : <prisma | alembic | flyway | scripts sql | none>

### CI/CD existant
- Pipeline : <github-actions | gitlab-ci | jenkins | none>
- Cloud : <gcp | azure | aws | heroku | none>
- Deploy strategy : <détectée ou inconnue>

### Gaps Archipel
| Gate              | État actuel         | Action requise           | Priorité |
|-------------------|---------------------|--------------------------|----------|
| Coverage > 80%    | <X% ou inconnu>     | <action>                 | <H/M/L>  |
| Lint clean        | <eslint/ruff/none>  | <action>                 | <H/M/L>  |
| Secrets scan      | <oui/non>           | <action>                 | <H/M/L>  |
| Migrations        | <versionnées/none>  | <action>                 | <H/M/L>  |

### Structure vs Archipel
| Dossier Archipel  | Équivalent trouvé   | Mapping                  |
|-------------------|---------------------|--------------------------|
| apps/web/         | <path trouvé>       | <adapter /feature>       |
| apps/api/         | <path trouvé>       | <adapter /feature>       |
| workers/          | <path trouvé>       | <adapter /feature>       |
| shared/db/        | <path trouvé>       | <noter dans project.json>|
```

**Si l'utilisateur a choisi `audit only` en Phase 2 :** afficher le rapport et s'arrêter ici.

---

### Phase 4 — Écriture (minimale, non destructive)

#### 4.1 Créer `.archipel/project.json` avec les vrais paths

```json
{
  "name": "<détecté depuis package.json ou dossier>",
  "description": "<détecté depuis README.md ou package.json description>",
  "type": "<perso|clubmed — dérivé du cloud détecté>",
  "stack": ["<stacks détectées>"],
  "postgresql": "<cloud-managed|self-hosted — dérivé du CI>",
  "git_remote": "<github|gitlab — dérivé du CI>",
  "ci": "<github-actions|gitlab-ci>",
  "cloud": "<gcp|azure>",
  "deploy_strategy": "<direct|staging-prod>",
  "pg_service": "<cloud-sql|azure-database>",
  "created_at": "<ISO>",
  "adopted_at": "<ISO>",
  "adoption_priority": "<vite|progressive>",
  "context": "<actif|en-cours|legacy>",
  "paths": {
    "web": "<chemin réel vers l'app web>",
    "api": "<chemin réel vers l'app api>",
    "workers": "<chemin réel ou null>",
    "prisma": "<chemin réel ou null>",
    "alembic": "<chemin réel ou null>"
  },
  "gaps": {
    "coverage": "<ok|todo>",
    "lint": "<ok|todo>",
    "secrets_scan": "<ok|todo>",
    "migrations_versioned": "<ok|todo>"
  }
}
```

#### 4.2 Créer `tasks/adoption-plan.md`

Le plan est adapté à la priorité choisie par l'utilisateur :
- `vite` → Niveau 1 et 2 d'abord, actions immédiates en tête
- `progressive` → Niveau 1 seulement, les autres en backlog

Plan de migration en 3 niveaux (ne pas tout faire d'un coup) :

```markdown
# Plan d'adoption Archipel — <nom projet>

## Niveau 1 — Overlay immédiat (0 risque, faire maintenant)
- [ ] `.archipel/project.json` créé ✅
- [ ] `CLAUDE.md` présent ✅
- [ ] Skills disponibles dans `skills/`
- [ ] Slash commands disponibles dans `.claude/commands/`

## Niveau 2 — Gates à activer (par ordre de priorité)
- [ ] Lint : installer eslint/ruff et corriger les warnings existants
- [ ] Secrets scan : ajouter gitleaks au CI existant
- [ ] Coverage : mesurer le coverage actuel, plan pour atteindre 80%

## Niveau 3 — Alignement structure (optionnel, quand pertinent)
- [ ] Renommer/déplacer vers `apps/web/`, `apps/api/` si besoin
- [ ] Migrer vers Prisma ou Alembic si migrations manuelles
- [ ] Activer le hook Stop (quand coverage ≥ 80%)

## Mappings de paths à adapter dans /feature et /ship
<liste des overrides détectés>
```

#### 4.3 Adapter les hooks `.claude/settings.json`

Mettre à jour les paths dans le hook Stop pour pointer vers les vrais
répertoires de tests détectés :

```json
"command": "cd <path_web_réel> && npm test -- --passWithNoTests && cd <path_api_réel> && python -m pytest --tb=short || exit 0"
```

---

### Phase 5 — Validation

```bash
test -f .archipel/project.json && \
python3 -c "
import json
d = json.load(open('.archipel/project.json'))
assert 'paths' in d, 'paths manquants'
assert 'gaps' in d, 'gaps manquants'
print('✅ project.json adopté et valide')
"
```

Afficher le rapport de gaps final et le plan d'adoption.

---

## Critère de sortie

- `.archipel/project.json` existe avec la section `paths` et `gaps`
- `tasks/adoption-plan.md` existe avec les 3 niveaux
- Aucun fichier existant modifié (lecture + création uniquement)
- Le rapport de gaps est affiché dans la conversation

## Principe clé

**Ne rien casser.** Cet agent ne modifie pas le code existant, ne déplace pas
de fichiers, ne change pas les CI/CD en place. Il crée uniquement
`.archipel/project.json` et `tasks/adoption-plan.md`.
Les adaptations structurelles sont dans le plan, à faire manuellement ou
via `/feature`.
