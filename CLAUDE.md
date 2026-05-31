# Archipel — Software Factory

Forge personnelle de Nicolas Girault (Head of Engineering, Club Med gMDT).
Couvre ses side projects personnels et Club Med-adjacents.
Seul orchestrateur : Nicolas. Pas d'équipe, pas de process d'approbation.

---

## Pipeline standard

```
/discover → /spec → /design → /feature → /review → /qa → /ship
```

| Commande    | Agent                      | Livrable                        | Mode              |
|-------------|----------------------------|---------------------------------|-------------------|
| `/bootstrap` | —                          | `.archipel/project.json`        | Wizard interactif |
| `/adopt`     | —                          | `project.json` + adoption-plan  | Rétro-analyse     |
| `/modernize` | Modernization Agent        | Projet V2 Archipel from scratch | Human-AI collab   |
| `/discover` | Discovery Agent (POC)      | `brief.md` + go/no-go           | Human+AI          |
| `/spec`     | PM/PO Agent + Architect    | `PRD.md` + `ADR.md` + Jira      | Human-AI collab   |
| `/design`   | Designer Agent             | `DRD.md` (flows + composants)   | Human-AI collab   |
| `/feature`  | Developer Agent            | Code + tests + migrations       | AI-led            |
| `/review`   | Reviewer Orchestrator      | Rapport 5 dimensions            | Human-AI collab   |
| `/qa`       | QA Agent                   | QA report + validation          | AI-led + Human    |
| `/ship`     | —                          | Deploy prod (perso ou clubmed)  | AI-led            |

### Étapes optionnelles selon le contexte
- `/discover` — optionnel si l'idée est déjà claire
- `/design` — optionnel pour les features purement backend
- `/review` et `/qa` — **toujours obligatoires** avant `/ship`

### Commandes hors pipeline (projets existants)
- `/adopt` — onboarding d'un projet existant dans Archipel (non destructif)
- `/modernize --source <path>` — réécriture V2 greenfield d'une codebase existante

---

## Gates (bloquants avant tout push)

- **Coverage** : minimum 80% (Jest pour web, pytest pour api)
- **No secrets** : gitleaks scan obligatoire avant `git push`
- **Lint clean** : eslint (TS/TSX), ruff (Python) — zéro warning
- **Migrations versionnées** : toujours via Prisma migrate (TS) ou Alembic (Python), jamais à la main
- **Review OK** : `/review` doit retourner "merge OK" — zéro finding critique
- **QA OK** : `/qa` doit retourner "QA OK" ou "QA partielle" avec tickets créés

---

## Dual-deploy — règle absolue

Avant tout `/ship`, lire `.archipel/project.json` :

```json
{ "type": "perso" }   → GitHub Actions → GCP → prod direct
{ "type": "clubmed" } → GitLab CI → Azure → staging → validation manuelle → prod
```

Ne jamais hardcoder la cible. Toujours dériver depuis `project.json`.

---

## Stack par type de projet

| Config          | perso            | clubmed               |
|-----------------|------------------|-----------------------|
| Git remote      | GitHub           | GitLab                |
| CI/CD           | GitHub Actions   | GitLab CI             |
| Cloud target    | GCP              | Azure                 |
| Deploy strategy | Direct → prod    | Staging → prod        |
| PostgreSQL      | Cloud SQL (GCP)  | Azure Database for PG |

---

## Apps du monorepo

- `apps/web/` — Next.js (TypeScript strict, server-first)
- `apps/api/` — FastAPI (Python 3.12+, Pydantic v2)
- `workers/` — Jobs async Python
- `shared/db/prisma/` — Schema + migrations TypeScript
- `shared/db/alembic/` — Migrations Python

---

## Self-improvement

- Toute erreur rencontrée → documenter dans `tasks/lessons.md`
- Format : date ISO, contexte, erreur, correction, règle à retenir (voir `lessons-protocol.md`)
- Logs de session → `tasks/session-log.md` — **une entrée par commande exécutée**

### Format session-log

```markdown
### YYYY-MM-DD — /commande [JIRA-ID optionnel]
**Action** : ce qui a été fait
**Livrable** : fichiers créés ou modifiés
**Résultat** : OK | KO | Partiel
**Prochaine étape** : /commande suggérée
```

Agents qui écrivent dans session-log : `/bootstrap`, `/ship`.
Les autres agents écrivent dans `lessons.md` uniquement (si boucle déclenchée).

---

## Agents spécialisés (`.claude/agents/`)

Invoqués par les commandes orchestratrices via `Agent()`. Chacun a un contexte isolé.

| Agent | Rôle | Invoqué par |
|-------|------|-------------|
| `architect` | Plan d'implémentation technique autonome | `/feature` étape 2 |
| `nextjs-dev` | Composants, pages, Server Actions | `/feature` étape 4 |
| `fastapi-dev` | Endpoints, services, repositories | `/feature` étape 4 |
| `db-dev` | Schémas, migrations, index | `/feature` étape 3 |
| `test-writer` | Tests Jest + pytest, coverage ≥ 80% | `/feature` étape 5 |
| `review-security` | Secrets, injections, auth, XSS | `/feature` étape 6 |
| `review-architecture` | SoC, patterns, typage | `/feature` étape 6 |
| `review-performance` | N+1, pagination, index | `/feature` étape 6 |
| `review-maintainability` | Complexité, nommage, duplication | `/feature` étape 6 |
| `review-resilience` | Erreurs, timeouts, cas limites | `/feature` étape 6 |

---

## Règles de code

Voir les skills pour les détails :
- `skills/nextjs.md` — conventions TypeScript/Next.js
- `skills/fastapi.md` — conventions Python/FastAPI
- `skills/postgresql.md` — conventions base de données
- `skills/git.md` — conventions git/commits
- `skills/testing.md` — conventions tests
- `skills/security.md` — validation, secrets, auth, XSS, injection SQL
- `skills/performance.md` — N+1, pagination, concurrence, cache, index
- `skills/cm-trident.md` — Trident UI, SidebarLayout, spacing, Azure AD (clubmed uniquement)

---

## Fichiers clés

```
.archipel/project.json  ← config projet actif (généré par /bootstrap)
.archipel/config/gcp.yml    ← template deploy perso
.archipel/config/azure.yml  ← template deploy clubmed
ci/github-actions/deploy.yml  ← pipeline perso
ci/gitlab-ci/deploy.yml       ← pipeline clubmed
```
