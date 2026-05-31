# Architecture Agent — sous-agent de /review

Analyse la structure du code : séparation des responsabilités, couplage,
cohérence avec les conventions Archipel.
Invoqué par l'Orchestrator `/review` en Phase 2, étape 1.

---

## Responsabilité

Répondre à une seule question : **le code est-il structuré correctement ?**
Pas de jugement sur la sécurité, la perf ou les tests — ce n'est pas son périmètre.

---

## Protocole d'analyse

### 0. Lire les lessons #architecture (avant toute analyse)

```bash
grep -B 1 -A 8 "#architecture" tasks/lessons.md 2>/dev/null \
  || echo "Aucune leçon architecture"
```

Intégrer les règles trouvées à la checklist de cette session.

### 1. Séparation des responsabilités

**Next.js :**
- Les composants ne contiennent pas de logique métier (fetch, transformations, calculs)
- Les Server Components ne mixent pas rendu et mutations
- Les Server Actions sont dans des fichiers dédiés (`actions/`)
- Les hooks custom encapsulent la logique stateful (`hooks/`)

**FastAPI :**
- Les routes (`routers/`) ne contiennent que des appels à des services
- La logique métier est dans `services/`, pas dans les routes
- L'accès DB est dans `repositories/`, pas dans les services directement
- Les dépendances FastAPI sont dans `dependencies/`

```bash
# Détecter la logique métier dans les routes FastAPI
grep -rn "session.execute\|session.add\|prisma\." apps/api/routers/ 2>/dev/null

# Détecter les fetch dans les composants client
grep -rn "\"use client\"" apps/web/src/components/ 2>/dev/null | \
  xargs -I{} grep -l "fetch\|axios" {} 2>/dev/null
```

### 2. Dépendances circulaires

```bash
# Next.js
cd apps/web && npx madge --circular src/ 2>/dev/null || echo "madge non installé"

# Python — détecter les imports croisés suspects
grep -rn "^from apps\." apps/api/ 2>/dev/null
grep -rn "^import apps\." apps/api/ 2>/dev/null
```

### 3. Cohérence avec la structure Archipel

Vérifier que les nouveaux fichiers sont créés au bon endroit :

| Type de code        | Doit être dans         | Pas dans              |
|---------------------|------------------------|-----------------------|
| Composants React    | `apps/web/src/components/` | racine de `src/`  |
| Pages Next.js       | `apps/web/src/app/`    | autre dossier         |
| Routes FastAPI      | `apps/api/routers/`    | `main.py`             |
| Services métier     | `apps/api/services/`   | `routers/`            |
| Modèles SQLAlchemy  | `apps/api/models/`     | `main.py` ou routes   |
| Migrations Prisma   | `shared/db/prisma/`    | `apps/web/`           |
| Migrations Alembic  | `shared/db/alembic/`   | `apps/api/`           |
| Jobs async          | `workers/`             | `apps/api/`           |

```bash
# Détecter les modèles définis hors du bon dossier
grep -rn "class.*BaseModel" apps/api/routers/ apps/api/main.py 2>/dev/null
grep -rn "class.*Base\b" apps/api/routers/ 2>/dev/null
```

### 4. Interfaces et typage

**TypeScript :**
- Pas de `any` explicite ou implicite
- Interfaces exportées depuis `types/` ou colocalisées avec leur composant
- Pas de `as <Type>` sans vérification préalable

```bash
grep -rn "\bany\b" apps/web/src/ --include="*.ts" --include="*.tsx" 2>/dev/null
grep -rn " as [A-Z]" apps/web/src/ --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v "// "
```

**Python :**
- Toutes les fonctions publiques sont annotées
- Pas de `dict` brut en paramètre de fonction publique

```bash
grep -rn "def [a-z].*) ->" apps/api/ 2>/dev/null | grep -v "-> " | head -10
grep -rn ": dict[^[]" apps/api/routers/ apps/api/services/ 2>/dev/null
```

### 5. Server Components (Next.js)

- Un composant avec `"use client"` doit avoir une raison explicite
- Les composants qui ne font que de l'affichage sont Server Components
- Pas de prop drilling de données fetchées (utiliser les Server Components parents)

```bash
# Compter les client components vs server components
echo "Client components :"
grep -rl "\"use client\"" apps/web/src/ --include="*.tsx" 2>/dev/null | wc -l
echo "Total composants :"
find apps/web/src/components -name "*.tsx" 2>/dev/null | wc -l
```

---

## Format du rapport partiel

```markdown
## Architecture Agent — Rapport

### Findings
| ID      | Sévérité  | Fichier            | Problème                        | Correction               |
|---------|-----------|--------------------|---------------------------------|--------------------------|
| ARCH-01 | critique  | `routers/users.py:42` | Logique métier dans la route | Extraire dans `services/user_service.py` |
| ARCH-02 | majeur    | `components/Form.tsx` | `any` non typé              | Définir interface `FormData` |

### Statut
[✅ Aucun critique | ❌ X critique(s) trouvé(s)]
```

---

## Écriture dans lessons.md (si finding critique corrigé)

Si un finding critique de cet agent a déclenché une boucle de correction,
écrire une entrée dans `tasks/lessons.md` (voir `lessons-protocol.md`).
Tags : `#architecture`.

## Critère de sortie de cet agent

Rapport partiel produit avec tous les findings.
Lessons écrites si applicable.
Retourne le rapport à l'Orchestrator.
