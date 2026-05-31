# PRD — RougeBleu
**Tracker NHL / Canadiens de Montréal**
**Version** : 1.1 | **Statut** : Validé | **Auteur** : Nicolas | **Projet** : Archipel
**Saison active** : 2025-2026 (`20252026`) — Playoffs en cours
**Contexte playoffs** : Les Canadiens de Montréal sont en **Finale de Conférence Est** (mai 2026)

---

## 1. Vision

RougeBleu est une application web personnelle qui agrège les données NHL en temps réel pour suivre les Canadiens de Montréal : résultats, classements, stats joueurs et calendrier. L'app persiste les données en base pour permettre une analyse historique et des visualisations de tendances sur la saison.

---

## 2. Problème

Les sources officielles (NHL.com, ESPN) sont lourdes, remplies de pub, et n'offrent aucune personnalisation. Un fan developer veut un dashboard propre, rapide, centré sur son équipe, avec la capacité d'annoter, comparer et analyser les données.

---

## 3. Goals / Non-Goals

### ✅ Goals (MVP)
- Afficher les résultats des matchs des Canadiens (live + historique)
- Synchroniser et persister les données NHL via l'API officielle
- Afficher le classement NHL en temps réel (division, conférence, ligue)
- Consulter les stats des joueurs actifs du roster MTL
- Planifier les prochains matchs (calendrier + countdown)
- **Playoffs 2025-2026** : afficher le bracket de la Finale de Conférence Est
- **Badge Playoffs** : indicateur visuel "PLAYOFFS" sur le dashboard quand game_type = playoffs
- **Synchro playoffs** : les crons doivent supporter les matchs playoffs (game_type `P` vs `R`)

### ✅ Goals (V2)
- Notifications (email/webhook) pour les game days
- Comparaison de performances joueurs saison vs saison
- Système d'annotations personnelles sur les matchs
- Prédiction de classement fin de saison (modèle simple)

### ❌ Non-Goals
- Support multi-équipes (centré MTL uniquement)
- Application mobile native
- Fonctionnalités sociales / partage
- Authentification multi-utilisateur

---

## 4. User Stories

| ID | En tant que... | Je veux... | Afin de... |
|----|---------------|-----------|-----------|
| US-01 | Fan des Canadiens | Voir le score du dernier match | Savoir le résultat sans ouvrir ESPN |
| US-02 | Fan des Canadiens | Voir le prochain match avec countdown | Anticiper et ne pas le rater |
| US-03 | Fan des Canadiens | Voir le classement de la division Atlantic | Savoir où se situe MTL |
| US-04 | Fan des Canadiens | Consulter les stats d'un joueur (G, A, PTS, +/-) | Suivre la progression individuelle |
| US-05 | Fan des Canadiens | Voir l'historique des matchs de la saison | Analyser les séquences win/loss |
| US-06 | Fan des Canadiens | Voir les stats de l'équipe (PP%, PK%, shots) | Analyser les tendances collectives |
| US-07 | Dev / Admin | Déclencher une synchro manuelle des données | Forcer un refresh sans attendre le cron |

---

## 5. Features MVP

### 5.1 Dashboard Home
- Score du dernier match (résultat + période + scoreurs)
- Prochain match (adversaire, lieu, date + countdown live)
- Record saison actuel (W-L-OTL)
- Position dans la division Atlantic

### 5.2 Résultats (Game Log)
- Liste paginée des matchs de la saison
- Filtres : mois, victoire/défaite, domicile/extérieur
- Détail par match : scoreurs, gardien, shots, PP goals

### 5.3 Classement
- Tableau de la division Atlantic
- Toggle : Division / Conférence Est / Ligue
- Colonnes : GP, W, L, OTL, PTS, GF, GA, DIFF

### 5.4 Roster & Stats Joueurs
- Liste du roster actif MTL
- Stats offensifs : G, A, PTS, +/-, TOI
- Stats défensifs / gardien : GAA, SV%
- Recherche / filtre par position

### 5.5 Calendrier
- Vue mensuelle des matchs
- Code couleur : victoire / défaite / à venir
- Clic sur un match → détail

### 5.6 Synchro Backend (Cron)
- Synchro automatique toutes les heures (scores + standings)
- Synchro quotidienne roster + stats joueurs
- Endpoint `/admin/sync` pour déclenchement manuel

---

## 6. External API — NHL Official API

**Base URL** : `https://api-web.nhle.com`
**Auth** : Aucune (API publique, non documentée officiellement mais stable)
**Rate limit** : ~10 req/s recommandé

| Endpoint | Usage |
|----------|-------|
| `GET /v1/standings/now` | Classement NHL en temps réel |
| `GET /v1/club-schedule-season/MTL/{season}` | Calendrier complet MTL |
| `GET /v1/gamecenter/{gameId}/landing` | Détail d'un match |
| `GET /v1/score/now` | Scores en cours (live) |
| `GET /v1/roster/MTL/current` | Roster actif |
| `GET /v1/player/{playerId}/landing` | Stats d'un joueur |
| `GET /v1/club-stats/MTL/now` | Stats équipe globales |

**Stratégie de synchro** :
- Les données sont fetchées par le backend Python et persistées en PostgreSQL
- Le front Next.js ne contacte **jamais** l'API NHL directement → tout passe par le backend
- Cache PostgreSQL + TTL géré par le backend pour limiter les appels externes

---

## 7. Data Model (PostgreSQL)

```sql
-- Matchs
CREATE TABLE games (
  id            VARCHAR(20) PRIMARY KEY,  -- gameId NHL
  season        VARCHAR(8) NOT NULL,       -- ex: 20252026 (saison active)
  game_date     DATE NOT NULL,
  home_team     VARCHAR(3) NOT NULL,
  away_team     VARCHAR(3) NOT NULL,
  home_score    INTEGER,
  away_score    INTEGER,
  game_state    VARCHAR(20),               -- FUT, LIVE, OFF, FINAL
  period        INTEGER,
  period_time   VARCHAR(10),
  venue         VARCHAR(100),
  raw_payload   JSONB,                     -- payload complet NHL stocké
  synced_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Classement (snapshot)
CREATE TABLE standings_snapshots (
  id            SERIAL PRIMARY KEY,
  captured_at   TIMESTAMPTZ DEFAULT NOW(),
  team_abbr     VARCHAR(3) NOT NULL,
  season        VARCHAR(8) NOT NULL,
  gp            INTEGER,
  wins          INTEGER,
  losses        INTEGER,
  ot_losses     INTEGER,
  points        INTEGER,
  gf            INTEGER,
  ga            INTEGER,
  conference    VARCHAR(20),
  division      VARCHAR(20),
  raw_payload   JSONB
);

-- Joueurs
CREATE TABLE players (
  id            INTEGER PRIMARY KEY,       -- playerId NHL
  first_name    VARCHAR(100),
  last_name     VARCHAR(100),
  position      VARCHAR(5),
  jersey_number INTEGER,
  headshot_url  TEXT,
  active        BOOLEAN DEFAULT TRUE,
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Stats joueurs (snapshot par synchro)
CREATE TABLE player_stats_snapshots (
  id            SERIAL PRIMARY KEY,
  player_id     INTEGER REFERENCES players(id),
  season        VARCHAR(8),
  captured_at   TIMESTAMPTZ DEFAULT NOW(),
  goals         INTEGER DEFAULT 0,
  assists       INTEGER DEFAULT 0,
  points        INTEGER DEFAULT 0,
  plus_minus    INTEGER DEFAULT 0,
  toi_per_game  VARCHAR(10),
  -- Gardien
  gaa           NUMERIC(4,2),
  save_pct      NUMERIC(5,3),
  raw_payload   JSONB
);

-- Log de synchro
CREATE TABLE sync_log (
  id            SERIAL PRIMARY KEY,
  sync_type     VARCHAR(50),              -- games | standings | roster | player_stats
  triggered_by  VARCHAR(20),             -- cron | manual
  status        VARCHAR(20),             -- success | error
  records_synced INTEGER,
  error_message TEXT,
  started_at    TIMESTAMPTZ DEFAULT NOW(),
  finished_at   TIMESTAMPTZ
);
```

---

## 8. Stack Technique

| Couche | Technologie | Justification |
|--------|-------------|---------------|
| Frontend | Next.js 15 (App Router, TypeScript) | SSR + ISR pour les pages de classement, RSC pour le dashboard |
| Backend | Python 3.12 + FastAPI | Async natif, idéal pour les appels API NHL concurrents |
| ORM | SQLAlchemy 2.x + Alembic | Migrations versionnées |
| Database | PostgreSQL 16 | JSONB pour stocker les payloads raw NHL |
| Scheduler | APScheduler (in-process) | Cron jobs simples sans infra supplémentaire |
| HTTP Client | httpx (async) | Compatible async FastAPI |
| Styling | Tailwind CSS + shadcn/ui | Dark mode, couleurs MTL (rouge #AF1E2D, bleu #192168) |
| Icons | Lucide React | |
| Charts | Recharts | Tendances, sparklines |
| Containerisation | Docker Compose | dev local : next + fastapi + postgres |

---

## 9. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Next.js (Port 3000)                   │
│   App Router / RSC / Client Components                   │
│   API Routes → proxy vers FastAPI                        │
└────────────────────┬────────────────────────────────────┘
                     │ HTTP / fetch
┌────────────────────▼────────────────────────────────────┐
│                FastAPI (Port 8000)                        │
│  /api/games  /api/standings  /api/players  /admin/sync   │
│  APScheduler → cron NHL sync                             │
│  httpx → NHL Official API                                │
└────────────────────┬────────────────────────────────────┘
                     │ SQLAlchemy async
┌────────────────────▼────────────────────────────────────┐
│               PostgreSQL (Port 5432)                      │
│   games | standings_snapshots | players                  │
│   player_stats_snapshots | sync_log                      │
└─────────────────────────────────────────────────────────┘
                     │ External
        ┌────────────▼──────────────┐
        │  api-web.nhle.com         │
        │  NHL Official Public API  │
        └───────────────────────────┘
```

---

## 10. KPIs de Succès

| KPI | Cible MVP |
|-----|-----------|
| Temps de chargement dashboard | < 1.5s (données en cache DB) |
| Fraîcheur des scores live | Synchro toutes les 60s pendant les matchs |
| Fraîcheur standings | Toutes les heures |
| Couverture saison | 100% des matchs MTL persistés |
| Uptime local | N/A (app perso, best effort) |

---

## 11. Folder Structure

```
rougebleu/
├── frontend/                    # Next.js
│   ├── app/
│   │   ├── page.tsx             # Dashboard
│   │   ├── games/page.tsx       # Game log
│   │   ├── standings/page.tsx   # Classement
│   │   ├── roster/page.tsx      # Joueurs
│   │   └── schedule/page.tsx    # Calendrier
│   ├── components/
│   │   ├── ScoreCard.tsx
│   │   ├── StandingsTable.tsx
│   │   ├── PlayerCard.tsx
│   │   └── GameCalendar.tsx
│   └── lib/api.ts               # Fetch helpers → FastAPI
│
├── backend/                     # FastAPI
│   ├── app/
│   │   ├── main.py
│   │   ├── routers/
│   │   │   ├── games.py
│   │   │   ├── standings.py
│   │   │   ├── players.py
│   │   │   └── admin.py
│   │   ├── services/
│   │   │   ├── nhl_client.py    # httpx wrapper NHL API
│   │   │   └── sync_service.py  # logique de synchro
│   │   ├── models/              # SQLAlchemy models
│   │   ├── schemas/             # Pydantic schemas
│   │   └── scheduler.py         # APScheduler config
│   ├── alembic/                 # Migrations
│   └── requirements.txt
│
├── docker-compose.yml
└── README.md
```

---

## 12. Milestones MVP

| Phase | Scope | Durée estimée |
|-------|-------|---------------|
| M1 — Infra | Docker Compose, DB init, FastAPI skeleton, Next.js setup | 2h |
| M2 — NHL Sync | nhl_client.py, sync games + standings, cron | 3h |
| M3 — API Routes | /games, /standings, /players endpoints | 2h |
| M4 — Dashboard | Home page, ScoreCard, NextGame, Record | 3h |
| M5 — Pages | Game log, Standings, Roster, Schedule | 4h |
| M6 — Polish | Dark mode MTL colors, charts, responsive | 2h |
| **Total** | | **~16h** |
