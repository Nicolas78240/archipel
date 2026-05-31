# /modernize — V2 Greenfield Rewrite

Analyse une codebase existante, en extrait la logique métier et les contrats,
puis produit un projet Archipel V2 from scratch. La codebase source est
**lecture seule** — elle n'est jamais modifiée, jamais copiée.

Mode : Human-AI collaborative — l'agent propose, l'humain valide à chaque étape clé.

---

## Usage

```
/modernize --source <path>             ← chemin absolu ou relatif vers la codebase source
/modernize --source <path> --level 1   ← forcer le niveau (bypass auto-détection)
```

Exemple : `/modernize --source ../mon-vieux-projet`

---

## Niveaux de modernisation

| Niveau | Nom        | Profil codebase source                  | Stratégie   |
|--------|------------|-----------------------------------------|-------------|
| 1      | Alignment  | Même stack mais mal structurée          | Big Bang    |
| 2      | Migration  | Stack différente, logique extractable   | Strangler Fig |
| 3      | Rewrite    | Legacy complet, paradigme dépassé       | Strangler Fig |

- **Big Bang** (niveau 1) : réécriture globale en un seul projet Archipel propre.
- **Strangler Fig** (niveaux 2-3) : feature par feature, chacune passant par `/spec → /design → /feature`.

---

## Protocole d'exécution

### Phase 1 — Lire les lessons et préparer l'audit

```bash
# Lessons pertinentes avant d'auditer et de concevoir
grep -B 1 -A 8 "#architecture\|#db\|#security" tasks/lessons.md 2>/dev/null \
  || echo "Aucune leçon"
```

Vérifier que le chemin source passé en argument existe et est lisible :
```bash
test -d <source_path> && echo "✅ Source accessible" || echo "❌ Chemin introuvable"
```

---

### Phase 2 — Audit de la codebase source (lecture seule)

> ⚠️ **Règle absolue** : aucune écriture, aucune modification, aucune exécution
> de commandes dans `<source_path>`. Lecture uniquement.

#### 2.1 Structure et stack

```bash
# Structure de haut niveau
find <source_path> -maxdepth 3 -type f \
  \( -name "package.json" -o -name "pyproject.toml" -o -name "requirements*.txt" \
  -o -name "Dockerfile" -o -name "docker-compose*.yml" \
  -o -name "schema.prisma" -o -name "alembic.ini" \
  -o -name "*.yml" -path "*github*" -o -name "*.yml" -path "*gitlab*" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*"

# Stack web
cat <source_path>/package.json 2>/dev/null || \
  find <source_path> -name "package.json" -not -path "*/node_modules/*" | head -3 | xargs cat

# Stack API
find <source_path> -name "requirements*.txt" -o -name "pyproject.toml" \
  -not -path "*/node_modules/*" | xargs cat 2>/dev/null | head -30
```

#### 2.2 Inventaire des features (ce que le produit fait)

Lire les fichiers qui révèlent la logique métier :
- `README.md`, `docs/`, `CHANGELOG.md` → description narrative des features
- Fichiers de routes : `pages/`, `app/`, `routes/`, `views/`, `controllers/`
- Fichiers de tests : `__tests__/`, `spec/`, `tests/` → chaque test décrit un comportement attendu

```bash
# Routes Next.js / Pages
find <source_path> -type f -name "*.tsx" -o -name "*.ts" \
  | grep -E "/(pages|app|routes)/" | grep -v node_modules | head -40

# Routes FastAPI / Flask / Django
find <source_path> -type f -name "*.py" \
  | xargs grep -l "@app\.\|@router\.\|urlpatterns\|path(" 2>/dev/null | head -20

# Tests existants (goldmine de spécifications comportementales)
find <source_path> -type f \( -name "*.test.*" -o -name "*.spec.*" -o -name "test_*.py" \) \
  -not -path "*/node_modules/*" | head -30
```

#### 2.3 Modèles de données

```bash
# Prisma
find <source_path> -name "schema.prisma" | xargs cat 2>/dev/null

# SQLAlchemy / Alembic models
find <source_path> -name "models.py" -o -name "model*.py" | xargs cat 2>/dev/null | head -150

# Migrations SQL brutes
find <source_path> -name "*.sql" -path "*/migrations/*" | sort | tail -5 | xargs cat 2>/dev/null
```

#### 2.4 Contrats API

```bash
# OpenAPI / Swagger si disponible
find <source_path> -name "openapi.json" -o -name "swagger.json" -o -name "openapi.yaml" \
  | xargs cat 2>/dev/null | head -200

# Pydantic schemas (contrats d'entrée/sortie)
find <source_path> -name "schemas.py" -o -name "schema*.py" | xargs cat 2>/dev/null | head -150

# Types TypeScript (interfaces)
find <source_path> -name "*.ts" | xargs grep -l "^interface\|^type " 2>/dev/null \
  | grep -v node_modules | head -10 | xargs cat 2>/dev/null | head -200
```

#### 2.5 Patterns d'authentification

```bash
# JWT / sessions / OAuth
find <source_path> -type f | xargs grep -l "jwt\|nextauth\|passport\|oauth\|session" \
  2>/dev/null | grep -v node_modules | head -10

# Middleware auth
find <source_path> -name "auth*" -o -name "middleware*" | grep -v node_modules | head -10
```

#### 2.6 Coverage et qualité actuels

```bash
# Présence de tests
find <source_path> -type f \( -name "*.test.*" -o -name "*.spec.*" -o -name "test_*.py" \) \
  -not -path "*/node_modules/*" | wc -l

# Derniers rapports de coverage s'ils existent
find <source_path> -name "coverage-summary.json" -o -name ".coverage" \
  -o -name "coverage.xml" | head -3
```

---

### Phase 3 — Classification du niveau (auto + validation humaine)

Après l'audit, déduire le niveau et présenter à l'utilisateur :

```
Analyse terminée. Voici ce que j'ai trouvé :

Stack source  : <détectée>
Features      : <N features identifiées>
Modèles DB    : <N modèles>
Contrats API  : <N endpoints ou N schémas>
Tests source  : <N fichiers de tests>
Auth          : <pattern détecté ou "aucun">

Niveau proposé : <1 | 2 | 3>
Raison         : <pourquoi ce niveau>
Stratégie      : <Big Bang | Strangler Fig>
```

Demander via AskUserQuestion :

1. **Niveau de modernisation**
   - `Niveau 1 — Alignment (Big Bang)` — même stack, réécriture globale propre
   - `Niveau 2 — Migration (Strangler Fig)` — stack différente, feature par feature
   - `Niveau 3 — Rewrite complet (Strangler Fig)` — legacy total, tout réécrire
   - `[Proposition du modèle]` — accepter le niveau auto-détecté
   - `Other` — préciser

2. **Périmètre de la V2**
   - `Toutes les features` — réécriture intégrale
   - `Core uniquement` — fonctionnalités essentielles seulement, les secondaires en backlog
   - `Other` — sélection manuelle à préciser

3. **Nom et type du projet V2**
   - Suggestions : `<nom-source>-v2`, `<nom-source>-next`, `<nom-source>-modern`
   - Type : `perso` (GitHub + GCP) ou `clubmed` (GitLab + Azure)
   - `Other` — préciser

---

### Phase 4 — Construire l'inventaire et le plan

#### 4.1 Inventaire des features

Construire une liste structurée depuis l'audit :
- Chaque feature = 1 ligne avec nom, description, priorité (core / secondaire / nice-to-have)
- Source de vérité : README, tests, routes, et contrats API lus en Phase 2

#### 4.2 Écrire `docs/migration-plan.md` dans le **projet V2** (pas dans la source)

```markdown
# Plan de modernisation V2 — <nom projet>

Date : <ISO>
Source : <source_path> (lecture seule — jamais modifiée)
Stratégie : <Big Bang | Strangler Fig>
Niveau : <1 | 2 | 3>

## Stack V2
- Web      : Next.js 15 + TypeScript strict + shadcn/ui (perso) | Trident (clubmed)
- API      : FastAPI + Pydantic v2 + Alembic
- DB       : PostgreSQL + Prisma (web) / Alembic (api)
- CI/CD    : GitHub Actions → GCP (perso) | GitLab CI → Azure (clubmed)

## Stack source (référence uniquement)
<stack détectée en Phase 2>

## Inventaire des features

| # | Feature              | Description                    | Priorité  | Statut    |
|---|----------------------|--------------------------------|-----------|-----------|
| 1 | <nom>                | <ce que l'utilisateur peut faire> | core   | À faire   |
| 2 | <nom>                | ...                            | core      | À faire   |
| … | …                    | …                              | secondaire| Backlog   |

## Modèles de données à recréer
| Modèle source      | Modèle V2          | Changements             |
|--------------------|--------------------|-------------------------|
| <User>             | <User>             | <champs renommés, etc.> |

## Contrats API à recréer
| Endpoint source    | Endpoint V2        | Notes                   |
|--------------------|--------------------|-------------------------|
| GET /api/products  | GET /api/products  | Même contrat            |
| POST /auth/login   | POST /auth/session | NextAuth côté V2        |

## Features hors périmètre V2
<liste des features non retenues pour cette réécriture>
```

#### 4.3 Validation humaine du plan via AskUserQuestion

Présenter le plan section par section :

```
TANT QUE (plan non validé) :
  a. Inventaire des features — correct ?
     - `valider` — la liste couvre bien ce que j'attends
     - `ajouter une feature` — préciser via Other
     - `retirer une feature` — préciser via Other

  b. Stack V2 — correct ?
     - `valider` — Next.js + FastAPI me convient
     - `modifier` — préciser via Other

  c. Breaking changes acceptés ?
     - `oui, c'est une V2, les changements sont assumés`
     - `non, je veux maintenir la compatibilité` → ajuster le plan

  d. Plan validé ?
     - `oui, on peut démarrer la V2`
     - `non` → corriger, re-présenter
```

---

### Phase 5 — Créer le projet V2 (Archipel from scratch)

Une fois le plan validé :

#### 5.1 Initialiser le projet V2

Lancer `/bootstrap` dans le répertoire cible de la V2 :
- Utiliser le nom et le type décidés en Phase 3
- Stack selon le plan validé

Le répertoire V2 est **complètement séparé** du répertoire source.
Si la V2 doit vivre côté à côté :
```bash
# Structure recommandée
<nom-projet>-source/     ← jamais touché
<nom-projet>-v2/         ← projet Archipel créé ici
```

#### 5.2 Copier le plan de migration

```bash
cp docs/migration-plan.md <v2_path>/docs/migration-plan.md
```

---

### Phase 6 — Implémentation feature par feature

Pour chaque feature dans l'inventaire (en ordre de priorité) :

#### 6.1 Créer la spec depuis la feature extraite

Créer `docs/PRD-<feature>.md` dans le projet V2 en s'appuyant sur :
- La description dans `migration-plan.md`
- Les tests de la source qui documentent le comportement attendu
- Les contrats API listés dans le plan

> Ne jamais copier-coller de code depuis la source.
> Utiliser la source uniquement pour comprendre le **comportement** et les **règles métier**.

#### 6.2 Lancer le pipeline Archipel pour chaque feature

```
/spec    → spec de la feature lue depuis docs/PRD-<feature>.md
/design  → DRD de la feature (shadcn/Trident selon type)
/feature → implémentation Archipel-standard
```

Pendant `/feature`, consulter la source pour :
- Comprendre un algorithme ou une règle métier complexe
- Identifier les cas limites documentés dans les anciens tests
- Valider qu'un contrat API est correct

Ne **jamais** pour :
- Copier du code
- Réutiliser une structure de fichiers
- Importer des patterns non-Archipel

#### 6.3 Suivi dans `docs/migration-plan.md`

Mettre à jour le statut de chaque feature après implémentation :
```markdown
| 1 | Auth            | Connexion / déconnexion        | core      | ✅ Fait    |
| 2 | Products list   | Lister et filtrer les produits | core      | 🔄 En cours|
```

---

### Phase 7 — Validation de couverture

Une fois toutes les features core implémentées :

#### 7.1 Vérifier la couverture des features

```bash
# Compter les features core dans le plan
grep "| core" docs/migration-plan.md | grep -c "✅ Fait"
grep "| core" docs/migration-plan.md | grep -c "À faire\|🔄"
```

Si des features core sont encore en "À faire" → les implémenter avant de continuer.

#### 7.2 Gates Archipel

```bash
# Coverage web
cd apps/web && npm test -- --coverage --coverageThreshold='{"global":{"lines":80}}'

# Coverage api
cd apps/api && python -m pytest --cov=. --cov-report=term-missing --cov-fail-under=80

# Lint web
cd apps/web && npx eslint src/ --max-warnings 0

# Lint api
cd apps/api && ruff check . && ruff format --check .
```

```
TANT QUE (gates KO) :
  1. Identifier la cause exacte
  2. Corriger (tests, lint, coverage)
  3. Relancer les gates
  4. Revenir au début de la boucle
```

#### 7.3 Écrire dans lessons.md si problèmes récurrents

Si un pattern d'erreur s'est répété (ex : modèle de données mal conçu, auth pattern incorrect),
écrire une entrée dans `tasks/lessons.md` avec les tags `#architecture` et/ou `#db`.

---

### Phase 8 — Rapport final

Produire `docs/modernization-report.md` dans le projet V2 :

```markdown
# Rapport de modernisation V2 — <nom projet>

Date : <ISO>
Source analysée : <source_path>
Stratégie appliquée : <Big Bang | Strangler Fig>
Niveau : <1 | 2 | 3>

## Features migrées

| Feature              | Source                          | V2                          | Statut |
|----------------------|---------------------------------|-----------------------------|--------|
| Auth                 | custom JWT dans <source/auth>   | NextAuth + Prisma           | ✅     |
| Products list        | <source/pages/products>         | app/products/ (SC)          | ✅     |

## Changements breaking assumés
<liste des contrats ou comportements intentionnellement modifiés>

## Améliorations V2 par rapport à la source
- TypeScript strict (la source avait <X% de couverture TS)
- Coverage : <X%> (la source avait <Y%>)
- Lint : 0 warnings (la source avait <N> warnings)
- Architecture : Archipel-standard (Server Components, Dependency Injection, etc.)

## Ce qui n'a pas été migré
<features hors périmètre V2 avec justification>

## Prochaine étape recommandée
`/ship` sur la branche `main` du projet V2.
```

---

## Critère de sortie

- `docs/migration-plan.md` existe avec toutes les features core en statut `✅ Fait`
- Tous les gates passent : coverage > 80%, lint clean, 0 secrets
- `docs/modernization-report.md` existe
- La codebase source est intacte (jamais modifiée)
- Prochaine commande affichée : `/ship`

---

## Principe fondamental

**La source est une bibliothèque, pas un modèle.**  
On la lit pour comprendre ce que le produit fait.  
On ne la touche pas. On n'en copie pas le code.  
Le projet V2 est Archipel-standard dès la première ligne.
