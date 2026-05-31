# Lessons Learned — Archipel

## Format d'une leçon

```markdown
### YYYY-MM-DD — [AGENT] Titre court

**Contexte** : dans quelle situation l'erreur s'est produite
**Erreur** : ce qui a mal tourné (code, décision, hypothèse)
**Correction** : ce qui a été fait pour corriger
**Règle** : formulation actionnable pour ne pas reproduire
**Tags** : #architecture | #security | #performance | #maintainability | #resilience | #db | #ci | #config
```

Chaque agent filtre par ses tags au démarrage.
Les entrées les plus récentes sont en haut.

---

## Entrées

### 2026-05-22 — [DESIGN-SYSTEM/V3] postcss.config.js absent — Tailwind 4 ne compile pas

**Contexte** : Build V3 — design-system a généré globals.css avec @import "tailwindcss" (Tailwind 4) mais n'a pas créé postcss.config.js. L'app s'affichait sans aucun style.
**Erreur** : Tailwind 4 nécessite @tailwindcss/postcss comme plugin PostCSS. Sans postcss.config.js, aucune classe CSS n'est compilée.
**Correction** : Création de postcss.config.js : `module.exports = { plugins: { "@tailwindcss/postcss": {} } };`
**Règle** : design-system doit toujours créer postcss.config.js quand il utilise Tailwind 4 (@import "tailwindcss"). Ajouter un gate `test -f apps/web/postcss.config.js` après l'agent design-system.
**Tags** : #config #architecture

### 2026-05-21 — [BUILD/ROUGEBLEU] Bugs runtime invisibles à l'analyse statique

**Contexte** : Build complet RougeBleu M1→M6 en mode autonome. Code sorti propre (ruff, tsc, eslint, 5 review agents). Bugs découverts au premier test manuel en local.
**Erreur** : Deux bugs runtime non détectables statiquement — (1) `game_date` passé en `str` à SQLAlchemy qui attend un objet `date` → `AttributeError: 'str' object has no attribute 'toordinal'`. (2) httpx ne suit pas les redirections 307 par défaut → synchro NHL silencieusement vide.
**Correction** : `date.fromisoformat(raw["gameDate"])` pour le parsing. `follow_redirects=True` sur `httpx.AsyncClient`.
**Règle** : Ajouter un smoke test runtime après chaque milestone backend (synchro API externe, opérations DB). Lancer la vraie stack Docker et déclencher un appel réel. Les mocks ne peuvent pas attraper les incompatibilités de types entre un format JSON externe et un ORM, ni les comportements HTTP d'APIs tierces.
**Tags** : #resilience #architecture

### 2026-04-21 — [BOOTSTRAP] Hooks settings.json — variables d'environnement

**Contexte** : Création du fichier `.claude/settings.json` lors du bootstrap initial.
**Erreur** : Utilisation de `$FILE` et `$COMMAND` directement dans les hooks, alors que Claude Code expose ces valeurs via `TOOL_INPUT_file_path` et `TOOL_INPUT_command`.
**Correction** : Réécriture avec `FILE="${TOOL_INPUT_file_path:-}"` et ajout de `exit 0` pour ne pas bloquer si les outils (prettier, ruff, gitleaks) ne sont pas encore installés.
**Règle** : Les hooks `PostToolUse` et `PreToolUse` utilisent le préfixe `TOOL_INPUT_` pour accéder aux paramètres de l'outil appelé. Toujours ajouter `|| true` et `exit 0` sur les hooks qui appellent des outils optionnels.
**Tags** : #config

---

### 2026-04-21 — [BOOTSTRAP] Alembic — stack async dès le départ

**Contexte** : Choix du driver DB pour Alembic lors du bootstrap.
**Erreur** : Tentation d'utiliser `psycopg2` (sync) par défaut car plus documenté.
**Correction** : Choix de `asyncpg` + `SQLAlchemy[asyncio]` + configuration Alembic async dans `env.py`.
**Règle** : Dans un projet FastAPI, toute la stack DB doit être async dès le premier jour. Mélanger sync/async crée des deadlocks et rend le refactoring coûteux.
**Tags** : #db #architecture

---

*Nouvelles entrées au-dessus de cette ligne.*

### 2026-05-22 — [BUILD/V5] Agent corrige le backend mais pas le frontend — bug persiste

**Contexte** : V5 sprint corrections — bugs de classement (doublons) et ScoreCard (barres blanches) persistent après corrections de l'agent.
**Erreur** : L'agent a corrigé le repository SQLAlchemy (backend correct) mais le bug venait du frontend (page.tsx ne passait pas les bons paramètres à l'API). L'agent suppose que "code compile = bug corrigé".
**Correction** : Identifier la cause racine dans le bon layer (frontend vs backend) avant de coder. Vérifier visuellement avec Playwright après chaque correction.
**Règle** : Après toute correction de bug UI/data, l'agent DOIT naviguer sur la page concernée avec le browser et confirmer visuellement que le bug est résolu. Sans screenshot de confirmation, la tâche n'est pas close.
**Tags** : #resilience #architecture

### 2026-05-29 — [bootstrap] Hooks non copiés lors du bootstrap

**Contexte** : `/bootstrap` sur le projet `assistant`
**Erreur** : `on-stop.sh: No such file or directory` — le script de bootstrap copie `commands/`, `skills/` et `templates/` mais oublie `.claude/hooks/`
**Correction** : copie manuelle de `.claude/hooks/*.sh` dans le projet cible
**Règle** : ajouter `cp -r "$ARCHIPEL_HOME/.claude/hooks" .claude/` dans l'Étape 3b du bootstrap
**Tags** : #config
