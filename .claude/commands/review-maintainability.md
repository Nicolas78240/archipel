# Maintainability Agent — sous-agent de /review

Analyse la lisibilité et la maintenabilité du code : nommage, duplication,
complexité, conventions, dette technique explicite.
Invoqué par l'Orchestrator `/review` en Phase 2, étape 4.

---

## Responsabilité

Répondre à une seule question : **dans 6 mois, quelqu'un (ou toi-même) pourra-t-il comprendre et modifier ce code sans se battre ?**

---

## Protocole d'analyse

### 0. Lire les lessons #maintainability (avant toute analyse)

```bash
grep -B 1 -A 8 "#maintainability" tasks/lessons.md 2>/dev/null \
  || echo "Aucune leçon maintenabilité"
```

Intégrer les règles trouvées à la checklist de cette session.

### 1. Fonctions trop longues (> 40 lignes)

```bash
# Python — fonctions longues
awk '/^(async )?def /{fn=$0; count=0} {count++} count>40 {print FILENAME ":" NR " — " fn}' \
  $(find apps/api -name "*.py" 2>/dev/null) 2>/dev/null | head -10

# TypeScript — fonctions longues (approximation)
grep -n "^  [a-z].*=.*=>" apps/web/src/ -r --include="*.ts" --include="*.tsx" 2>/dev/null | head -5
```

### 2. Nommage non explicite

```bash
# Variables à un caractère ou non descriptives (hors boucles for i in ...)
grep -rEn "\b(data|res|tmp|temp|val|obj|item|x|y|z)\s*[=:]" \
  apps/ --include="*.ts" --include="*.tsx" --include="*.py" 2>/dev/null | \
  grep -v "for\|#\|//\|test\|__"

# Fonctions sans verbe d'action dans le nom
grep -rEn "^(async )?def [a-z][a-z_]+\(" apps/api/ 2>/dev/null | \
  grep -vE "def (get_|set_|create_|update_|delete_|list_|find_|check_|validate_|send_|build_|parse_|format_|handle_|process_|run_|load_|save_|fetch_)"
```

### 3. Code dupliqué

Rechercher des blocs de code similaires (3+ occurrences = extraction obligatoire) :

```bash
# Blocs Python dupliqués (approximation par patterns répétés)
grep -rn "await session.execute" apps/api/ 2>/dev/null | \
  awk -F: '{print $2}' | sort | uniq -c | sort -rn | head -5

# Patterns répétés dans les composants React
grep -rn "className=\"" apps/web/src/ --include="*.tsx" 2>/dev/null | \
  awk -F'"' '{print $2}' | sort | uniq -c | sort -rn | head -10
```

### 4. TODO / FIXME sans ticket

```bash
grep -rEn "(TODO|FIXME|HACK|XXX|BUG)\b" \
  apps/ --include="*.ts" --include="*.tsx" --include="*.py" 2>/dev/null | \
  grep -vE "(ARCH|JIRA|PROJ)-[0-9]+"
```

Un TODO sans ticket = dette non traçable. Soit créer le ticket, soit supprimer le TODO.

### 5. Conventions de nommage

```bash
# snake_case pour les colonnes DB (Prisma)
grep -rn "@map\|@@map" shared/db/prisma/schema.prisma 2>/dev/null
# Vérifier que tous les champs ont un @map si le nom Prisma est camelCase

# snake_case pour les tables et colonnes (SQLAlchemy)
grep -rn "__tablename__" apps/api/models/ 2>/dev/null | grep -v "snake_case_name"

# PascalCase pour les composants React
find apps/web/src/components -name "*.tsx" 2>/dev/null | \
  grep -vE "/[A-Z][a-zA-Z]+\.tsx$"
```

### 6. Commentaires explicatifs vs commentaires redondants

```bash
# Commentaires qui répètent ce que le code dit déjà (bruit)
grep -rEn "#\s*(get|set|return|check|create|update|delete)\s+the\s+\w+" \
  apps/api/ 2>/dev/null | head -5

# Code mort commenté
grep -rEn "^#.*=.*\(|^//.*function|^//.*const " \
  apps/ --include="*.py" --include="*.ts" 2>/dev/null | head -10
```

### 7. Complexité cyclomatique excessive

Chercher les fonctions avec beaucoup de branches imbriquées :

```bash
# Python — if imbriqués profondément
grep -rn "^        if \|^            if " apps/api/ --include="*.py" 2>/dev/null | head -10

# TypeScript — conditions complexes
grep -rn "if.*&&.*&&.*&&" apps/web/src/ --include="*.ts" --include="*.tsx" 2>/dev/null
```

### 8. Tests qui testent l'implémentation plutôt que le comportement

```bash
# Mocks excessifs dans les tests (signe de couplage)
grep -rn "jest\.mock\|patch(" apps/web/src/ apps/api/tests/ 2>/dev/null | wc -l

# Tests avec accès aux internals du composant
grep -rn "\.instance()\|\.state()\|\.props()" apps/web/src/ 2>/dev/null
```

---

## Grille de sévérité

| Problème | Sévérité |
|---|---|
| Fonction > 100 lignes | **critique** |
| Code mort significatif (> 20 lignes) | **majeur** |
| Duplication > 3 fois d'un bloc > 10 lignes | **majeur** |
| Fonction > 40 lignes | **mineur** |
| Nommage non descriptif sur variable partagée | **mineur** |
| TODO sans ticket | **mineur** |
| Convention de nommage violée | **mineur** |
| Commentaire redondant | **suggestion** |

---

## Format du rapport partiel

```markdown
## Maintainability Agent — Rapport

### Findings
| ID      | Sévérité   | Fichier                        | Problème                          | Correction                          |
|---------|------------|--------------------------------|-----------------------------------|-------------------------------------|
| MAINT-01| mineur     | `api/services/order_service.py:12` | Fonction `process` : 67 lignes | Extraire `validate_order()` et `apply_discount()` |
| MAINT-02| mineur     | `web/src/components/Form.tsx:8`    | TODO sans ticket Jira         | Créer ticket ou supprimer           |

### Statut
[✅ Aucun critique | ⚠️ X mineur(s)]
```

---

## Écriture dans lessons.md (si finding critique corrigé)

Si un finding critique de cet agent a déclenché une boucle de correction,
écrire une entrée dans `tasks/lessons.md` (voir `lessons-protocol.md`).
Tags : `#maintainability`.

## Critère de sortie de cet agent

Rapport partiel produit.
Lessons écrites si applicable.
Retourne le rapport à l'Orchestrator.
