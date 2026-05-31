# ADR — RougeBleu
**Architecture Decision Records**
**Version** : 1.0 | **Projet** : Archipel / RougeBleu | **Auteur** : Nicolas

---

## ADR-001 — Source de données NHL : API officielle nhle.com

**Date** : 2026-05-21
**Statut** : ✅ Accepté

### Contexte
Plusieurs sources de données NHL existent : API officielle non documentée (`api-web.nhle.com`), APIs tierces payantes (SportRadar, SportsData.io), ou scraping HTML.

### Options évaluées

| Option | Avantages | Inconvénients |
|--------|-----------|---------------|
| `api-web.nhle.com` (officielle) | Gratuite, données canoniques, stable depuis 2023 | Non documentée officiellement |
| SportRadar / SportsData.io | Documentée, SLA | Payante (~$150/mois), overkill pour usage perso |
| Scraping NHL.com | Gratuit | Fragile, ToS risqués, maintenance lourde |

### Décision
**Utiliser `api-web.nhle.com`** — l'API publique officielle NHL.

### Justification
- Gratuite et sans clé API
- Données source vérité (même backend que l'app officielle NHL)
- Communauté active qui documente les endpoints (gitlab.com/dword-design/nhl-api)
- Pour un usage perso/faible volume, la stabilité est suffisante
- En cas de cassure, les endpoints sont réversibles rapidement

### Conséquences
- Wrapper `nhl_client.py` à maintenir si l'API évolue
- Pas de SLA → géré par le `sync_log` et les alertes d'erreur
- Stocker les `raw_payload` JSONB en DB pour pouvoir re-parser sans re-fetcher

---

## ADR-002 — Backend : Python / FastAPI vs Node.js

**Date** : 2026-05-21
**Statut** : ✅ Accepté

### Contexte
Le frontend étant Next.js (Node.js), on pourrait unifier sur un monorepo Node. Mais le projet Archipel teste intentionnellement le stack Python backend.

### Options évaluées

| Option | Avantages | Inconvénients |
|--------|-----------|---------------|
| FastAPI (Python) | Async natif, Pydantic, typage fort, APScheduler, ML-ready | Runtime séparé du front |
| Next.js API Routes | Monorepo unifié, DX simple | Pas de vrai scheduler, moins idiomatique pour data sync |
| Express / Fastify | Familier Node | Pas de gain vs Next.js routes pour ce use case |

### Décision
**FastAPI (Python 3.12)**

### Justification
- Cœur du projet Archipel : valider le pattern Next.js ↔ Python ↔ PostgreSQL
- `httpx` async parfait pour les appels concurrents NHL
- `APScheduler` intégré dans le process FastAPI, pas d'infra Celery/Redis
- `SQLAlchemy 2.x` async + Alembic = gestion migrations propre
- Pattern extensible : future intégration ML/prédiction en Python natif

### Conséquences
- CORS à configurer entre port 3000 (Next) et 8000 (FastAPI)
- Docker Compose obligatoire pour orchestrer les deux services
- Le front utilise ses propres API Routes comme proxy → le browser ne contacte jamais FastAPI directement

---

## ADR-003 — Base de données : PostgreSQL avec JSONB

**Date** : 2026-05-21
**Statut** : ✅ Accepté

### Contexte
Les données NHL sont des objets JSON complexes et changeants. On doit choisir entre schéma strict, schéma hybride, ou NoSQL.

### Options évaluées

| Option | Avantages | Inconvénients |
|--------|-----------|---------------|
| PostgreSQL (colonnes normalisées) | Requêtes SQL, index, performances | Schéma rigid si l'API NHL change |
| PostgreSQL (JSONB hybride) | Schéma partiel + raw stocké | Légère complexité |
| MongoDB | Flexible | Overkill, infra supplémentaire, pas de SQL |
| SQLite | Zéro infra | Pas adapté si scaling ou accès concurrent |

### Décision
**PostgreSQL 16 avec colonnes normalisées + colonne `raw_payload JSONB`**

### Justification
- Les colonnes normalisées couvrent 90% des besoins de lecture (score, dates, stats)
- `raw_payload JSONB` permet de re-parser sans re-fetcher si le schéma évolue
- PostgreSQL supporte nativement le JSONB avec index GIN
- Alembic gère les migrations proprement
- Cohérent avec l'ecosystème Archipel (stack standard)

### Conséquences
- Double écriture (colonnes + JSON) à chaque sync → coût acceptable pour ce volume
- Si l'API NHL change un champ : re-migrer les colonnes, re-parser depuis `raw_payload`
- Index sur `games.game_date`, `games.game_state`, `standings_snapshots.captured_at`

---

## ADR-004 — Stratégie de synchro et cache

**Date** : 2026-05-21
**Statut** : ✅ Accepté

### Contexte
L'API NHL ne doit pas être appelée à chaque requête front. Il faut définir une stratégie de cache/synchro qui équilibre fraîcheur des données et respect du rate limit.

### Options évaluées

| Option | Avantages | Inconvénients |
|--------|-----------|---------------|
| Redis comme cache | TTL fine-grained, perf | Infra supplémentaire |
| Cache in-memory FastAPI | Simple | Perdu au restart |
| PostgreSQL comme source de vérité + cron | Simple, durable, zéro infra | Latence max = fréquence du cron |
| ISR Next.js | Cache côté front | Données stales possibles |

### Décision
**PostgreSQL comme unique source de vérité + APScheduler cron**

### Justification
- Pas de Redis pour un projet perso : complexité inutile
- Le front lit **toujours** PostgreSQL via FastAPI, jamais l'API NHL directement
- Fréquences de synchro adaptées au contexte :
  - **Pendant un match** : synchro scores toutes les **60 secondes** (détection via `game_state = LIVE`)
  - **Hors match** : toutes les **60 minutes**
  - **Standings** : toutes les **2 heures**
  - **Roster + stats joueurs** : **1x par jour** (00:00 UTC)
- Endpoint `/admin/sync?type=all` pour forcer manuellement

### Conséquences
- Latence maximale des scores live = 60s → acceptable pour usage perso
- Le scheduler doit détecter s'il y a un match en cours pour ajuster la fréquence
- `sync_log` table pour monitorer les échecs de synchro

---

## ADR-005 — Authentification

**Date** : 2026-05-21
**Statut** : ✅ Accepté

### Contexte
L'application est un outil personnel hébergé localement (ou sur un VPS privé). Faut-il une authentification ?

### Options évaluées

| Option | Avantages | Inconvénients |
|--------|-----------|---------------|
| Pas d'auth | Simplicité maximale | Accès libre si exposé sur internet |
| HTTP Basic Auth (nginx) | Simple, 0 code | Config serveur, pas élégante |
| JWT / NextAuth.js | Propre, extensible | Over-engineered pour usage solo |

### Décision
**Pas d'authentification pour le MVP** — protection réseau uniquement (localhost / VPN)

### Justification
- App personnelle : un seul utilisateur
- Déployée en local ou derrière un reverse proxy privé
- L'endpoint `/admin/sync` est le seul sensible → protégé par variable d'environnement `ADMIN_SECRET` dans le header HTTP
- Si exposition publique future → ajouter HTTP Basic Auth côté nginx, sans toucher au code

### Conséquences
- Variable `ADMIN_SECRET` dans `.env` requise pour les routes `/admin/*`
- FastAPI middleware vérifie le header `X-Admin-Secret` sur les routes admin
- Documenté dans le README pour ne pas exposer accidentellement

---

## ADR-006 — Stratégie de déploiement

**Date** : 2026-05-21
**Statut** : ✅ Accepté

### Contexte
Le projet fait partie d'Archipel — la software factory perso. Le déploiement doit être reproductible et cohérent avec les autres projets.

### Décision
**Docker Compose pour le dev local. Deployable sur VPS via Docker Compose + Caddy reverse proxy.**

### Stack de déploiement

```yaml
# docker-compose.yml (structure)
services:
  db:
    image: postgres:16-alpine
    volumes: [postgres_data:/var/lib/postgresql/data]
    env_file: .env

  backend:
    build: ./backend
    depends_on: [db]
    env_file: .env
    ports: ["8000:8000"]

  frontend:
    build: ./frontend
    depends_on: [backend]
    ports: ["3000:3000"]
    env_file: .env
```

### Variables d'environnement requises

```env
# .env
POSTGRES_USER=rougebleu
POSTGRES_PASSWORD=<secret>
POSTGRES_DB=rougebleu
DATABASE_URL=postgresql+asyncpg://rougebleu:<secret>@db:5432/rougebleu
NEXT_PUBLIC_API_URL=http://backend:8000
ADMIN_SECRET=<secret>
NHL_TEAM=MTL
NHL_SEASON=20242025
```

### Justification
- Docker Compose = reproductible sur n'importe quelle machine Archipel
- Caddy sur VPS = HTTPS automatique, reverse proxy simple
- Pas de Kubernetes : overkill pour un projet perso

---

## Résumé des décisions

| ADR | Décision | Statut |
|-----|----------|--------|
| ADR-001 | NHL API officielle api-web.nhle.com | ✅ Accepté |
| ADR-002 | FastAPI Python comme backend | ✅ Accepté |
| ADR-003 | PostgreSQL + colonnes normalisées + JSONB | ✅ Accepté |
| ADR-004 | PostgreSQL comme cache + APScheduler cron | ✅ Accepté |
| ADR-005 | Pas d'auth MVP, ADMIN_SECRET header | ✅ Accepté |
| ADR-006 | Docker Compose + Caddy VPS | ✅ Accepté |
