# Patterns établis

> Fichier maintenu par `architect` et `kaizen` après chaque feature.
> **Les agents dev lisent ce fichier avant d'écrire du code.**
> Format : `## [Contexte] — [Nom du pattern]` + chemin du fichier de référence + règle d'usage.

---

## Comment utiliser ce fichier

- **architect** : injecter les sections pertinentes dans `IMPL-*.md` → section "Réutilisation obligatoire"
- **nextjs-dev / fastapi-dev** : lire avant de créer tout nouveau fichier
- **kaizen / review-maintainability** : ajouter une entrée quand un pattern mérite d'être réutilisé

---

## Ajouter un pattern

```markdown
## [Stack] — Nom du pattern
**Fichier de référence** : `chemin/vers/fichier.ts`
**Usage** : quand utiliser ce pattern (1-2 lignes)
**Ne pas recréer** : quelles alternatives sont interdites
```

---

*Ce fichier est vide au bootstrap. Il se remplit au fil des builds.*
*Premier pattern détecté → le documenter ici immédiatement.*
