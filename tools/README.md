# Archipel Monitor

Dashboard temps réel de la Software Factory Archipel.

## Architecture

```
tools/monitor.js                          → serveur SSE local (port 3999)
apps/web/src/app/monitor/page.tsx         → route Next.js /monitor
apps/web/src/components/monitor/          → composant React ArchipelLive
```

Le serveur `monitor.js` lit les fichiers `tasks/live-events.jsonl` de chaque projet enregistré et les broadcast via SSE. Le dashboard Next.js se connecte et visualise les événements en temps réel.

## Lancer

```bash
# Terminal 1 — serveur SSE
npm run monitor          # http://localhost:3999

# Terminal 2 — dashboard Next.js
cd apps/web && npm run dev   # http://localhost:3998/monitor
```

## Modes

| URL | Comportement |
|-----|-------------|
| `http://localhost:3998/monitor` | Projets réels depuis le monitor |
| `http://localhost:3998/monitor?demo=true` | Simulation avec projets fictifs — cycle complet /discover→/ship |

## Endpoints monitor (port 3999)

| Route | Description |
|-------|-------------|
| `GET /events` | SSE — stream des événements de tous les feeds |
| `GET /projects` | Liste des projets enregistrés + agents + feedExists |
| `GET /agents` | Agents détectés dans `.claude/agents/` |
| `GET /health` | Status JSON (clients, projets, feeds watchés, uptime) |
| `GET /push?json=...` | Injection debug d'un événement |

## Projets enregistrés

Définis dans `.archipel/projects.json` à la racine d'Archipel.
Chaque projet bootstrappé avec `/bootstrap` est automatiquement ajouté.

```json
{
  "projects": [
    { "name": "GentilGantt",   "path": "/Users/caussni/Dev/GentilGantt",   "type": "clubmed", "cloud": "Azure" },
    { "name": "assistant",     "path": "/Users/caussni/Dev/assistant",     "type": "perso",   "cloud": "GCP"   },
    { "name": "gMDTPlanningv2","path": "/Users/caussni/Dev/gMDTPlanningv2","type": "clubmed", "cloud": "Azure" }
  ]
}
```

## Format des événements (`tasks/live-events.jsonl`)

Chaque ligne est un objet JSON émis par les hooks Claude Code :

```json
{ "ts": "14:32:07", "hook": "on-bash", "type": "ok",      "project": "GentilGantt", "msg": "git push main → gitleaks OK" }
{ "ts": "14:32:09", "hook": "on-write","type": "write",   "project": "GentilGantt", "msg": "eslint src/components/Gantt.tsx" }
{ "ts": "14:32:11", "hook": "on-stop", "type": "blocked", "project": "GentilGantt", "msg": "coverage 71% < 80%" }
```

| Champ | Valeurs |
|-------|---------|
| `type` | `ok` `blocked` `warn` `info` `agent` `write` `success` |
| `hook` | identifiant du hook déclencheur |
| `agent` | id de l'agent si applicable |
| `rework` | `{ "from": "review", "to": "feature" }` si rework détecté |

## Ce que visualise le dashboard

- **Pipeline** `/discover → /spec → /design → /feature → /review → /qa → /ship` avec position courante
- **Agents assignés** par stage — états ACTIVE / DONE / NEXT / PENDING / firing
- **Hooks** — 16 hooks avec état actif (s'allume au déclenchement) + tooltip détail
- **Garage** — agents non assignés au projet, disponibles au survol
- **Feed d'événements** — stream en temps réel avec timestamp et durée
- **Reworks** — arcs animés droite→gauche quand un agent demande un retour arrière
