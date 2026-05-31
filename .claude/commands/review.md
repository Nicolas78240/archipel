# /review — Reviewer Orchestrator

Coordonne 5 agents de review spécialisés sur le diff courant.
Consolide leurs rapports, gère la boucle de correction, prend la décision finale.

Mode : Human-AI collaborative — agents analysent en parallèle, humain valide les critiques.

---

## Usage

```
/review                 ← review du diff courant (vs main)
/review <JIRA-ID>       ← review de la branche feat/<JIRA-ID>
/review --full          ← review complète de la codebase
/review --agent secu    ← lancer uniquement l'agent Sécurité
```

---

## Les 5 agents sous-jacents

| Agent | Fichier | Responsabilité |
|-------|---------|----------------|
| Architecture Agent | `review-architecture.md` | Structure, séparation des responsabilités, couplage |
| Security Agent | `review-security.md` | Secrets, injections, auth, CORS, PII |
| Performance Agent | `review-performance.md` | N+1, pagination, concurrence, index, cache |
| Maintainability Agent | `review-maintainability.md` | Lisibilité, duplication, nommage, conventions |
| Resilience Agent | `review-resilience.md` | Erreurs, timeouts, retry, transactions, idempotence |

---

## Protocole d'exécution

### Phase 1 — Préparer le contexte (partagé avec tous les agents)

```bash
# Périmètre du diff
git diff main --name-only 2>/dev/null || git diff HEAD~1 --name-only

# Contenu complet du diff
git diff main 2>/dev/null || git diff HEAD~1

# Contexte projet
cat .archipel/project.json
```

Transmettre à chaque agent :
- La liste des fichiers modifiés
- Le diff complet
- La stack active (nextjs / python-api / workers)

---

### Phase 2 — Lancer les 5 agents (séquentiellement, dans cet ordre)

L'ordre n'est pas arbitraire : Architecture d'abord (les autres dépendent de la structure),
Sécurité en deuxième (bloquant absolu), puis les trois restants.

```
1. → Architecture Agent   (review-architecture.md)
2. → Security Agent       (review-security.md)
3. → Performance Agent    (review-performance.md)
4. → Maintainability Agent(review-maintainability.md)
5. → Resilience Agent     (review-resilience.md)
```

Chaque agent produit son rapport partiel avec ses findings classés par sévérité.

---

### Phase 3 — Consolider les rapports

```markdown
# Review consolidée — <branche>
Date : <ISO>

## Tableau de synthèse
| Agent           | Critiques | Majeurs | Mineurs | Statut  |
|-----------------|-----------|---------|---------|---------|
| Architecture    | X         | X       | X       | ✅/❌   |
| Sécurité        | X         | X       | X       | ✅/❌   |
| Performance     | X         | X       | X       | ✅/❌   |
| Maintenabilité  | X         | X       | X       | ✅/❌   |
| Résilience      | X         | X       | X       | ✅/❌   |
| **TOTAL**       | **X**     | **X**   | **X**   |         |

## ❌ Critiques bloquants (tous agents confondus)
[ARCH-01] ...
[SECU-01] ...

## ⚠️ Majeurs
...

## 💡 Mineurs / Suggestions
...

## ✅ Points positifs
...
```

---

### Phase 4 — Boucle de correction

```
TANT QUE (critiques > 0) :
  1. Présenter les critiques à l'humain (AskUserQuestion)
  2. Action choisie :
     - `corriger maintenant` → /feature → corrections → REVENIR en /review
       (Phase 2 complète, tous les agents re-lancés sur le nouveau diff)
     - `accepter le risque`  → justification + ticket Jira [REVIEW] → sortir
     - `bloquer la PR`       → documenter, ne pas merger → sortir
  3. Répéter
```

---

### Phase 5 — Décision finale + Jira

- Créer un ticket `[REVIEW] <finding>` pour chaque majeur non corrigé
- Afficher la décision : `merge OK` | `merge avec tickets` | `PR bloquée`
- Si `merge OK` ou `merge avec tickets` → suggérer `/qa`

---

## Critère de sortie

- Les 5 agents ont produit leur rapport
- Zéro critique sans décision explicite
- Décision finale affichée
- Prochaine étape : `/qa`
