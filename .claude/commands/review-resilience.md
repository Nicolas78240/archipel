# Resilience Agent — sous-agent de /review

Analyse la robustesse du code face aux pannes : gestion des erreurs,
timeouts, retry, transactions, idempotence, dégradation gracieuse.
Invoqué par l'Orchestrator `/review` en Phase 2, étape 5.

---

## Responsabilité

Répondre à une seule question : **que se passe-t-il quand quelque chose échoue ?**
Chaque appel externe, chaque opération DB, chaque job doit avoir une réponse à cette question.

---

## Protocole d'analyse

### 0. Lire les lessons #resilience (avant toute analyse)

```bash
grep -B 1 -A 8 "#resilience" tasks/lessons.md 2>/dev/null \
  || echo "Aucune leçon résilience"
```

Intégrer les règles trouvées à la checklist de cette session.

### 1. Gestion des erreurs sur les appels externes

Tout appel réseau, DB, service tiers doit être enveloppé dans un try/catch ou équivalent.

```bash
# Python — appels sans try/except
grep -rn "await.*httpx\.\|await.*aiohttp\.\|requests\." apps/api/ 2>/dev/null | \
  grep -v "try\|#"
# Vérifier manuellement le contexte pour confirmer la présence d'un try/except

# TypeScript — fetch sans .catch()
grep -rn "fetch(" apps/web/src/ 2>/dev/null | grep -v "\.catch\|try\|// "

# Identifier les blocs try/except trop larges (avalent toutes les erreurs)
grep -rn "except Exception\|except:\|catch (e)" apps/ 2>/dev/null | \
  grep -v "raise\|log\|logger\|console\."
```

### 2. Retry — pattern correct vs naïf

```bash
# Retry naïf en boucle (sans backoff = thundering herd)
grep -rEn "for.*retry|while.*retry|for.*attempt" apps/ \
  --include="*.py" --include="*.ts" 2>/dev/null | grep -v "backoff\|exponential\|tenacity"

# Retry sans limite maximale
grep -rn "retry" apps/ --include="*.py" --include="*.ts" 2>/dev/null | \
  grep -v "max_retries\|max_attempts\|retries="
```

Pattern correct attendu : bibliothèque `tenacity` (Python) ou `p-retry` (TS) avec backoff exponentiel et limite.

### 3. Timeouts sur tous les appels externes

```bash
# httpx sans timeout (Python) — CRITIQUE : peut bloquer un worker indéfiniment
grep -rn "httpx\.get\|httpx\.post\|httpx\.AsyncClient" apps/api/ 2>/dev/null | \
  grep -v "timeout="

grep -rn "AsyncClient(" apps/api/ 2>/dev/null | grep -v "timeout="

# aiohttp sans timeout
grep -rn "aiohttp\.ClientSession" apps/api/ 2>/dev/null | grep -v "timeout="

# fetch sans AbortController (TypeScript)
grep -rn "fetch(" apps/web/src/ 2>/dev/null | grep -v "signal\|AbortController\|timeout"
```

### 4. Transactions DB pour les opérations multi-étapes

Si plusieurs opérations DB doivent réussir ensemble ou pas du tout :

```bash
# Python — plusieurs session.add/execute sans transaction explicite
grep -rn "session.add\b" apps/api/services/ 2>/dev/null | head -10
# Vérifier que chaque fichier avec plusieurs session.add utilise "async with session.begin()"

# Prisma — opérations multiples sans $transaction
grep -rn "await prisma\." apps/web/src/ --include="*.ts" 2>/dev/null -A 1 | \
  grep -B 1 "await prisma\." | grep -v "\$transaction\|#"
```

### 5. Idempotence des workers

Un job relancé deux fois ne doit pas créer de doublons ou d'effets de bord cumulatifs.

```bash
# Workers sans vérification d'état avant exécution
grep -rn "async def execute" workers/ 2>/dev/null -A 10 | \
  grep -v "already\|exists\|idempotent\|status\|state"

# Opérations non idempotentes dans les workers (INSERT sans ON CONFLICT)
grep -rn "session.add\b\|prisma.*create\b" workers/ 2>/dev/null | \
  grep -v "upsert\|on_conflict\|get_or_create"
```

### 6. Health check complet

Le health check doit vérifier les dépendances réelles, pas juste retourner 200.

```bash
# Vérifier le contenu du health endpoint
grep -rn "health" apps/api/ --include="*.py" 2>/dev/null -A 10 | head -30
grep -rn "health" apps/web/src/ --include="*.ts" --include="*.tsx" 2>/dev/null -A 5
```

Un health check complet vérifie :
- Connexion DB (pas juste `SELECT 1`)
- Services dépendants critiques (cache, queue)
- Version de l'application

### 7. Dégradation gracieuse

Si un service non-critique est down, l'app doit continuer à fonctionner partiellement.

```bash
# Vérifier que les appels à des services non-critiques sont dans des try/except
# avec fallback (valeur par défaut, cache, feature flag)
grep -rn "raise\|throw" apps/api/services/ apps/web/src/ 2>/dev/null | \
  grep -v "HTTPException\|ValueError\|TypeError\|#" | head -10
```

### 8. Circuit breaker (si appels externes fréquents)

Pour les services externes appelés fréquemment : vérifier si un circuit breaker
est en place pour éviter de marteler un service dégradé.

```bash
grep -rn "circuit_breaker\|CircuitBreaker\|pybreaker" apps/api/ 2>/dev/null || \
  echo "Aucun circuit breaker détecté — vérifier si nécessaire selon le volume d'appels"
```

---

## Grille de sévérité

| Problème | Sévérité |
|---|---|
| Appel réseau sans timeout dans un worker | **critique** |
| Transaction multi-étapes sans `BEGIN/COMMIT` | **critique** |
| Worker non idempotent sur une opération financière/critique | **critique** |
| Appel externe sans try/catch | **majeur** |
| Retry sans backoff ni limite | **majeur** |
| Health check qui ne vérifie pas la DB | **majeur** |
| Appel externe sans timeout dans une API synchrone | **majeur** |
| Absence de dégradation gracieuse sur service non-critique | **mineur** |
| Pas de circuit breaker sur service externe fréquent | **suggestion** |

---

## Format du rapport partiel

```markdown
## Resilience Agent — Rapport

### Findings
| ID      | Sévérité  | Fichier                       | Problème                             | Correction                                        |
|---------|-----------|-------------------------------|--------------------------------------|---------------------------------------------------|
| RESI-01 | critique  | `workers/notification.py:34`  | httpx sans timeout                   | `httpx.AsyncClient(timeout=10.0)`                 |
| RESI-02 | majeur    | `api/services/order.py:89`    | Deux session.add sans transaction    | Envelopper dans `async with session.begin()`      |
| RESI-03 | mineur    | `api/main.py:15`              | Health check sans vérification DB    | Ajouter `SELECT 1` sur la connexion DB            |

### Statut
[✅ Aucun critique | ❌ X critique(s) trouvé(s)]
```

---

## Écriture dans lessons.md (si finding critique corrigé)

Si un finding critique de cet agent a déclenché une boucle de correction,
écrire une entrée dans `tasks/lessons.md` (voir `lessons-protocol.md`).
Tags : `#resilience`.

## Critère de sortie de cet agent

Rapport partiel produit.
Lessons écrites si applicable.
Retourne le rapport à l'Orchestrator.
