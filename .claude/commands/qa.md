# /qa — QA Agent

Validation complète avant release : tests automatisés, tests fonctionnels,
tests de régression, validation UX sur les flows critiques.
Correspond à l'étape "Automated Tests & Validation" du workflow AI-Assisted.

Mode : AI-led & Human-validated — l'agent exécute, l'humain valide les flows UI.

---

## Usage

```
/qa                     ← QA complète sur la branche courante
/qa <JIRA-ID>           ← QA ciblée sur la feature du ticket
/qa --regression        ← QA de régression sur main (avant release)
```

---

## Protocole d'exécution

### Phase 1 — Lire le contexte

```bash
cat .archipel/project.json
cat docs/PRD.md 2>/dev/null          # critères d'acceptation
cat docs/DRD.md 2>/dev/null          # flows à valider
git diff main --name-only 2>/dev/null # périmètre modifié
```

Extraire les **critères d'acceptation** du PRD — ce sont les cas de test prioritaires.

---

### Phase 2 — Tests automatisés

#### 2.1 Boucle tests automatisés (tant que KO → corriger et relancer)

```
TANT QUE (coverage < 80% OU tests KO) :
  1. Identifier les tests qui échouent ou les zones non couvertes
  2. Écrire ou corriger les tests concernés
  3. Relancer la suite complète
  4. Revenir au début de la boucle
```

**Web (Jest + React Testing Library) :**
```bash
cd apps/web && npm run test:coverage
# Si coverage < 80% → écrire les tests manquants, relancer
# Si tests KO → corriger le code ou le test, relancer
```

**API (pytest) :**
```bash
cd apps/api && python -m pytest --cov=. --cov-report=term-missing --cov-fail-under=80 -v
# Si coverage < 80% → écrire les tests manquants, relancer
# Si tests KO → corriger le code ou le test, relancer
```

Vérifier également :
- Tous les endpoints nouveaux testés (happy path + erreurs)
- Cas limites couverts (payload vide, valeurs nulles, données invalides)
- Tests d'intégration avec DB de test (pas de mocks sur les repositories)

#### 2.2 Tests E2E (Playwright — si `stack == nextjs`)

```bash
# Vérifier que Playwright est installé
cd apps/web && npx playwright --version 2>/dev/null || echo "Playwright non installé — skip E2E"

# Si installé : lancer les tests E2E
cd apps/web && npx playwright test --reporter=list
```

Les tests E2E couvrent les flows critiques du DRD :
- Flow principal (happy path de bout en bout)
- Flow d'erreur principal (saisie invalide, ressource manquante)
- Navigation et états de loading

Si Playwright n'est pas encore configuré dans le projet, créer un test minimal :
```typescript
// apps/web/e2e/smoke.spec.ts
import { test, expect } from "@playwright/test"

test("homepage loads", async ({ page }) => {
  await page.goto("/")
  await expect(page).not.toHaveTitle(/error/i)
})
```

#### 2.3 Lint final

```bash
cd apps/web && npx eslint src/ --max-warnings 0
cd apps/api && ruff check . && ruff format --check .
```

#### 2.4 Type check

```bash
cd apps/web && npx tsc --noEmit
```

---

### Phase 3 — Validation fonctionnelle (depuis le DRD/PRD)

Pour chaque critère d'acceptation du PRD, produire un cas de test :

```markdown
### CA-01 : <titre du critère>
**Flow** : <référence au DRD>
**Données de test** : <inputs>
**Résultat attendu** : <output>
**Statut** : [auto-testé ✅ | à valider manuellement 👤]
```

Les cas marqués **👤 à valider manuellement** sont listés pour l'humain.

---

### Phase 4 — Tests de régression (si `--regression`)

Vérifier que les fonctionnalités existantes ne sont pas cassées :

```bash
# Lancer la suite complète
cd apps/web && npm test -- --passWithNoTests
cd apps/api && python -m pytest --tb=short

# Vérifier le health endpoint
curl -f http://localhost:3000/health 2>/dev/null || echo "App non démarrée"
curl -f http://localhost:8000/health 2>/dev/null || echo "API non démarrée"
```

Comparer avec le snapshot de coverage de la branche main :
```bash
git stash && npm run test:coverage 2>/dev/null
git stash pop
```

---

### Phase 5 — Boucle de validation humaine

Présenter la liste des cas **à valider manuellement** et boucler jusqu'à décision finale.

```
TANT QUE (décision != "QA OK" ET décision != "QA bloquée") :
  1. Présenter les cas à valider manuellement
  2. Demander via AskUserQuestion :

     a. Flows UI validés manuellement ?
        - `tous validés` — j'ai testé tous les flows listés
        - `partiellement` — flows non testés : (préciser via "Other")
        - `non démarré`  — l'app n'est pas accessible

     b. (Si stack nextjs) Mobile vérifié ?
        - `oui`              — testé sur mobile ou DevTools responsive
        - `non prioritaire`  — feature desktop only
        - `non testé`        — à faire avant release

     c. Décision QA
        - `QA OK`      → sortir de la boucle, aller vers /ship
        - `QA partielle` → créer tickets pour les points en suspens, sortir
        - `QA bloquée`   → identifier les cas en échec, retourner en /feature
                           puis REVENIR en /qa (re-lancer QA complète)

  3. Si `QA bloquée` : après retour de /feature, reprendre Phase 2
     (re-lancer tous les tests automatisés)
  4. Revenir au début de la boucle
```

---

### Phase 6 — Rapport QA

```markdown
# QA Report — <feature ou version>
Date : <ISO>
Branch : <nom de branche>

## Résumé des tests automatisés
| Suite     | Tests | Pass | Fail | Coverage |
|-----------|-------|------|------|----------|
| Web (Jest)| X     | X    | X    | X%       |
| API (pytest)| X   | X    | X    | X%       |

## Critères d'acceptation
| ID     | Description              | Auto | Manuel | Statut |
|--------|--------------------------|------|--------|--------|
| CA-01  | <titre>                  | ✅   | -      | PASS   |
| CA-02  | <titre>                  | ✅   | 👤     | PASS   |

## Issues trouvées
| Sévérité | Description | Ticket | Statut |
|----------|-------------|--------|--------|
| ...

## Décision
[QA OK ✅ | QA partielle ⚠️ | QA bloquée ❌]
```

---

### Phase 7 — Mise à jour du suivi

```bash
JIRA=$(python3 -c "import json; d=json.load(open('.archipel/project.json')); print(d.get('jira_project',''))" 2>/dev/null)
```

**Mode Jira (`jira_project` défini) :**
- Passer le ticket en "QA Done" si OK via MCP Atlassian
- Créer des tickets `[QA] <description>` pour les issues non bloquantes

**Mode solo (`jira_project` absent) :**
- Ajouter les issues trouvées dans `docs/tasks.md` sous une section `## Issues QA`
- Retourner en `/feature` si bloquant

---

## Critère de sortie

- Coverage ≥ 80% (web + api)
- Lint propre
- Rapport QA produit
- Validation humaine obtenue sur les flows manuels
- Décision explicite : QA OK | QA partielle | QA bloquée
- Prochaine étape suggérée : `/ship` ou retour en `/feature`
