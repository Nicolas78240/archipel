# Performance Agent — sous-agent de /review

Analyse les problèmes de performance : requêtes DB inefficaces, concurrence
mal gérée, absence de pagination, cache manquant.
Invoqué par l'Orchestrator `/review` en Phase 2, étape 3.

---

## Responsabilité

Répondre à une seule question : **le code va-t-il créer des problèmes de performance en production ?**
Référence : `skills/performance.md` pour les patterns corrects.

---

## Protocole d'analyse

### 0. Lire les lessons #performance (avant toute analyse)

```bash
grep -B 1 -A 8 "#performance" tasks/lessons.md 2>/dev/null \
  || echo "Aucune leçon performance"
```

Intégrer les règles trouvées à la checklist de cette session.

### 1. Requêtes N+1

Pattern : une requête dans une boucle qui itère sur les résultats d'une autre requête.

```bash
# Python — await/execute dans une boucle
grep -rn "for.*in.*:" apps/api/ --include="*.py" -A 5 2>/dev/null | \
  grep -A 4 "for.*in" | grep "await.*session\|await.*execute\|await.*get\b"

# TypeScript — prisma dans une boucle
grep -rn "\.map.*async\|for.*await" apps/web/src/ --include="*.ts" --include="*.tsx" 2>/dev/null | \
  grep -v "Promise\.all"
```

Vérifier que les relations sont chargées avec `include` (Prisma) ou `selectinload` (SQLAlchemy).

```bash
# Prisma — findMany sans include sur des relations utilisées ensuite
grep -rn "findMany\b" apps/ --include="*.ts" 2>/dev/null
# Vérifier manuellement que les champs de relation ne sont pas accédés en boucle après

# SQLAlchemy — select sans options de chargement
grep -rn "select(User\|select(Post\|select(Product" apps/api/ 2>/dev/null | \
  grep -v "selectinload\|joinedload\|subqueryload"
```

### 2. Await dans les boucles (concurrence séquentielle inutile)

```bash
# forEach + async (anti-pattern : forEach n'attend pas les Promises)
grep -rn "\.forEach.*async" apps/web/src/ apps/api/ 2>/dev/null

# for...of avec await (séquentiel — souvent remplaçable par Promise.all)
grep -rn "for.*of.*{" apps/web/src/ --include="*.ts" --include="*.tsx" -A 3 2>/dev/null | \
  grep "await "

# Python — await en boucle
grep -rEn "for .* in .*:" apps/api/ --include="*.py" -A 2 2>/dev/null | grep "await "
```

### 3. Endpoints sans pagination

```bash
# FastAPI — retour de liste sans limit/offset
grep -rn "\.all()\|\.fetchall()\|scalars().all()" apps/api/ 2>/dev/null | \
  grep -v "test\|#"

# Prisma — findMany sans take/skip
grep -rn "findMany({" apps/ --include="*.ts" 2>/dev/null | \
  grep -v "take:\|skip:\|cursor:"

# Routes qui retournent des listes sans paramètres de pagination
grep -rn "List\[.*Response\]\|list\[.*\]" apps/api/routers/ 2>/dev/null
```

### 4. Index manquants

Analyser les colonnes utilisées dans les `WHERE`, `ORDER BY`, `JOIN` des requêtes :

```bash
# SQLAlchemy — filtres sur colonnes potentiellement non indexées
grep -rEn "\.where\(.*\.(status|type|email|user_id|created_at)\b" apps/api/ 2>/dev/null

# Prisma — filtres sur colonnes sans @index dans le schema
grep -rn "where:.*{" apps/ --include="*.ts" 2>/dev/null | head -10
# Comparer avec le schema.prisma pour vérifier les @@index
```

### 5. Images non optimisées (Next.js)

```bash
# <img> au lieu de next/image
grep -rn "<img " apps/web/src/ --include="*.tsx" 2>/dev/null | grep -v "// \|<!--"

# Images sans width/height (cause layout shift)
grep -rn "Image " apps/web/src/ --include="*.tsx" 2>/dev/null -A 2 | \
  grep -v "width\|height\|fill"
```

### 6. Fetching côté client au lieu de Server Components

```bash
# useEffect avec fetch (à remplacer par Server Component)
grep -rn "useEffect" apps/web/src/ --include="*.tsx" -A 5 2>/dev/null | grep "fetch\|axios"

# useState pour stocker des données fetchées
grep -rn "useState<.*\[\]>" apps/web/src/ --include="*.tsx" 2>/dev/null | head -10
```

### 7. Re-renders inutiles

```bash
# Fonctions inline dans les props (recrée à chaque render)
grep -rn "onClick={() =>" apps/web/src/ --include="*.tsx" 2>/dev/null | \
  grep -v "simple\|// ok" | head -10

# Objets/arrays inline dans les props
grep -rn "style={{" apps/web/src/ --include="*.tsx" 2>/dev/null | head -5
```

### 8. Timeouts sur les appels externes

```bash
# fetch sans AbortController/signal
grep -rn "fetch(" apps/web/src/ 2>/dev/null | grep -v "signal\|AbortController\|timeout"

# httpx/aiohttp sans timeout (Python)
grep -rn "httpx\.\|aiohttp\." apps/api/ 2>/dev/null | grep -v "timeout="
```

---

## Grille de sévérité

| Problème | Sévérité |
|---|---|
| N+1 sur une liste > 100 items probable | **critique** |
| Endpoint qui retourne toute une table sans pagination | **critique** |
| Await séquentiel sur des opérations indépendantes (> 3) | **majeur** |
| N+1 sur une liste < 100 items | **majeur** |
| Pagination absente sur petite liste | **mineur** |
| Index manquant sur colonne de filtre | **majeur** |
| `<img>` au lieu de `next/image` | **mineur** |
| useEffect pour fetching | **majeur** |
| Fetch sans timeout | **mineur** |

---

## Format du rapport partiel

```markdown
## Performance Agent — Rapport

### Findings
| ID      | Sévérité | Fichier                    | Problème                        | Correction                           |
|---------|----------|----------------------------|---------------------------------|--------------------------------------|
| PERF-01 | critique | `api/services/product.py:67` | findAll() sans pagination     | Ajouter limit/offset, voir skills/performance.md |
| PERF-02 | majeur   | `web/src/app/page.tsx:23`  | useEffect pour fetch produits   | Migrer en Server Component async     |

### Statut
[✅ Aucun critique | ❌ X critique(s) trouvé(s)]
```

---

## Écriture dans lessons.md (si finding critique corrigé)

Si un finding critique de cet agent a déclenché une boucle de correction,
écrire une entrée dans `tasks/lessons.md` (voir `lessons-protocol.md`).
Tags : `#performance`.

## Critère de sortie de cet agent

Rapport partiel produit.
Lessons écrites si applicable.
Retourne le rapport à l'Orchestrator.
