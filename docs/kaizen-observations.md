# Kaizen Observations — RougeBleu V1→V5
Date : 2026-05-22
Builds analysés : V1, V2, V3, V4, V5
Mode : observation uniquement

---

## Patterns détectés

### [KAI-01] Vérification visuelle absente après correction de bug
**Observé** : V5 — l'agent corrige du code (standings repository, ScoreCard query) mais ne navigue pas sur la page pour confirmer que le bug est résolu. Il coche la tâche parce que le code compile.
**Fréquence** : 3 fois sur 5 builds (V3, V4, V5)
**Impact** : Bugs persistent sur plusieurs itérations. FIX-6 et FIX-8 ont nécessité 3 passes chacun.
**Agent concerné** : `nextjs-dev`, `fastapi-dev`, `build-orchestrator`
**Amélioration proposée** : Après toute correction de bug UI ou data, l'agent nextjs-dev doit retourner un screenshot Playwright de la page corrigée dans son JSON de résultat. Sans screenshot, la tâche est rejetée par build-orchestrator.
**Priorité** : haute

---

### [KAI-02] Layer mal identifié avant correction
**Observé** : V5 — bug de doublons standings corrigé dans le repository (backend) alors que la cause était dans page.tsx (frontend ne passait pas `season`). Plusieurs aller-retours inutiles.
**Fréquence** : 2 fois sur 5 builds (V4, V5)
**Impact** : Temps perdu, bug persistant après "correction".
**Agent concerné** : `build-orchestrator`, `nextjs-dev`, `fastapi-dev`
**Amélioration proposée** : Avant de coder un fix, l'agent doit produire un diagnostic en 3 lignes : "Layer : frontend/backend/DB", "Fichier exact : ...", "Cause : ...". Le build-orchestrator valide ce diagnostic avant d'invoquer l'agent dev.
**Priorité** : haute

---

### [KAI-03] JSX sémantique dans UI-SPECS — nextjs-dev réinterprète
**Observé** : V3, V4 — ui-designer produisait `className="card"` au lieu de `className="bg-[hsl(var(--surface))] border border-[hsl(var(--border))] rounded-lg p-4"`. nextjs-dev traduisait à sa façon.
**Fréquence** : 2 fois (V3, V4). Corrigé en V5.
**Impact** : Design incohérent entre le brief et l'implémentation. V3 et V4 avaient un look générique.
**Agent concerné** : `ui-designer`
**Amélioration proposée** : Ajouter dans `ui-designer` un gate de validation automatique — avant d'écrire UI-SPECS.md, vérifier que le JSX ne contient aucune classe sémantique custom (`card`, `badge-*`, `score-*`). Si trouvé, réécrire en atomique avant de sortir.
**Priorité** : haute

---

### [KAI-04] design-system sauté silencieusement
**Observé** : V2, V3, V4 — build-orchestrator passait à M1 sans avoir déclenché design-system. L'Étape 0c n'était pas bloquante.
**Fréquence** : 3 fois sur 5 builds. Résolu en V5 avec le hook SubagentStop.
**Impact** : Design générique identique à V1. 3 versions avec le même look.
**Agent concerné** : `build-orchestrator`
**Amélioration proposée** : Le hook `SubagentStop` sur `design-system` vérifie déjà `DESIGN-SYSTEM.md`. Ajouter la même vérification pour `creative-director` → `CREATIVE-BRIEF.md` et `ui-designer` → `UI-SPECS.md` avec longueur minimale (≥ 100 lignes pour UI-SPECS).
**Priorité** : haute

---

### [KAI-05] Synchro de données non déclenchée après implémentation
**Observé** : V4, V5 — l'agent implémente `historical_all` ou `player_stats` mais attend que l'humain lance la synchro. Données absentes à la validation visuelle.
**Fréquence** : 2 fois (V4, V5)
**Impact** : L'app démarre avec des données vides. Nécessite une intervention manuelle.
**Agent concerné** : `build-orchestrator`, `fastapi-dev`
**Amélioration proposée** : Dans l'Étape 1H (smoke test runtime), après le health check, déclencher systématiquement `POST /admin/sync?sync_type=all` et vérifier que les tables principales ont des données (`SELECT COUNT(*) FROM games` > 0). Inclure cette vérification dans le critère de sortie de l'étape.
**Priorité** : haute

---

### [KAI-06] Ports Docker en conflit entre versions
**Observé** : V4 — web V4 démarrait sur le même port que V3. Le test visuel montrait V3 sans qu'on le sache.
**Fréquence** : 1 fois (V4). Résolu avec ports figés dans project.json.
**Impact** : Tests sur la mauvaise version. Diagnostic erroné.
**Agent concerné** : `/bootstrap`, `build-orchestrator`
**Amélioration proposée** : Le hook `on-bash.sh` doit intercepter `docker compose up` et vérifier que les ports du projet courant ne sont pas déjà utilisés par un autre projet Archipel. Lire `project.json` de tous les projets dans `~/Dev/` et croiser les ports.
**Priorité** : moyenne

---

### [KAI-07] Tools manquants dans les frontmatters d'agents
**Observé** : V2 — architect sans `Write` → ne pouvait pas créer IMPL-*.md. 5 review agents sans `Write` → ne pouvaient pas écrire dans lessons.md.
**Fréquence** : 1 fois (V2), mais affectait 6 agents simultanément.
**Impact** : L'orchestrateur compensait en écrivant lui-même les fichiers → violation de l'isolation.
**Agent concerné** : Tous les agents custom
**Amélioration proposée** : Ajouter dans le hook `SubagentStop` une vérification des tools déclarés — si l'agent est censé produire un fichier (architect → IMPL, design-system → DESIGN-SYSTEM.md) et que `Write` n'est pas dans ses tools, bloquer avec message d'erreur avant même l'invocation.
**Priorité** : moyenne

---

### [KAI-08] Tests sans vraie PostgreSQL (SQLite)
**Observé** : V1, V2, V3 — les tests FastAPI utilisaient SQLite in-memory au lieu de PostgreSQL. Bugs de types (JSONB, VARCHAR length) non détectés.
**Fréquence** : 3 fois (V1, V2, V3). Résolu en V4 avec docker-compose.test.yml.
**Impact** : Coverage à 98% mais bugs runtime au premier test réel. Fausse confiance.
**Agent concerné** : `test-writer`
**Amélioration proposée** : `test-writer` doit vérifier en début de protocole que `TEST_DATABASE_URL` pointe vers PostgreSQL (contient `postgresql+asyncpg`) et non SQLite. Si SQLite détecté → bloquer et demander à build-orchestrator de démarrer la DB de test.
**Priorité** : moyenne

---

### [KAI-09] postcss.config.js absent — Tailwind 4 silencieusement cassé
**Observé** : V3 — globals.css avec @import "tailwindcss" sans postcss.config.js → app sans style.
**Fréquence** : 1 fois (V3). Auto-créé depuis V4.
**Impact** : App visuellement cassée. Nécessite intervention manuelle.
**Agent concerné** : `design-system`, `build-orchestrator`
**Amélioration proposée** : Le hook `on-write.sh` sur Write de `globals.css` vérifie et crée postcss.config.js automatiquement. Déjà implémenté en V5 — **pattern validé, garder en place**.
**Priorité** : faible (déjà résolu)

---

## Recommandations pour V6

### Priorité immédiate (impact direct sur qualité)

1. **KAI-01** — Ajouter screenshot Playwright dans le JSON de retour de nextjs-dev après correction de bug
2. **KAI-02** — Diagnostic layer obligatoire avant tout fix (3 lignes : layer, fichier, cause)
3. **KAI-05** — Smoke test avec synchro données + vérification COUNT(*) > 0

### Priorité court terme

4. **KAI-03** — Gate validation JSX atomique dans ui-designer avant écriture UI-SPECS.md
5. **KAI-04** — Vérification longueur UI-SPECS.md ≥ 100 lignes dans SubagentStop

### Déjà résolus — surveiller la non-régression

- KAI-06 : ports figés dans project.json ✅
- KAI-07 : tools Write dans tous les agents ✅
- KAI-08 : docker-compose.test.yml avec PostgreSQL ✅
- KAI-09 : postcss.config.js auto-créé ✅

---

## Métriques V1→V5

| Version | Bugs post-build | Corrections manuelles | Design quality | Tests runtime |
|---------|----------------|----------------------|----------------|---------------|
| V1 | 2 critiques | 2 | générique | ❌ aucun |
| V2 | 3 critiques | 4 | générique | ❌ aucun |
| V3 | 1 critique (postcss) | 1 | meilleur (brief ok) | ❌ partiel |
| V4 | 2 (ports, docker) | 2 | correct | ⚠️ partiel |
| V5 | 3 (layer, synchro) | 6+ | bon | ✅ présent |

**Tendance** : Qualité technique croissante (tests, design), mais bugs de validation persistants (layer, données).

**Conclusion** : La factory produit du code de qualité croissante. Le goulot d'étranglement principal est la **boucle de validation** — l'agent code correctement mais ne confirme pas visuellement que le résultat final est juste.
