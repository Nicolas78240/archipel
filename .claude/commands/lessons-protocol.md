# Protocol Lessons — référence partagée par tous les agents

Ce fichier définit le protocole de lecture et d'écriture de `tasks/lessons.md`.
Il est inclus par référence dans tous les agents — ne pas dupliquer, pointer ici.

---

## LECTURE — obligatoire au démarrage de chaque agent

Chaque agent filtre les lessons par ses tags avant d'analyser.

```bash
# Lire les lessons pertinentes (filtrer par tag de l'agent)
grep -A 7 "#<tag>" tasks/lessons.md 2>/dev/null || echo "Aucune leçon pour ce tag"
```

**Tags par agent :**
- Architecture Agent    → `#architecture`
- Security Agent        → `#security`
- Performance Agent     → `#performance`
- Maintainability Agent → `#maintainability`
- Resilience Agent      → `#resilience`
- `/feature`            → `#architecture #db`
- `/spec`               → (pas de tag — lire les 5 dernières entrées)
- `/ship`               → `#ci #config`

**Comportement attendu :**
Si une leçon dit "toujours vérifier X avant Y", l'agent ajoute X à sa liste de vérification
pour cette session. Les leçons sont des règles additionnelles, pas des substituts au protocole.

---

## ÉCRITURE — obligatoire quand une erreur est corrigée dans une boucle

Quand la boucle de correction d'un agent se déclenche (un finding critique ou majeur
est identifié ET corrigé), écrire une entrée dans `tasks/lessons.md`.

**Déclencheurs d'écriture :**
- `/feature` : la boucle tests/lint a nécessité plus d'une itération
- `/review-*` : un finding critique a été corrigé avant merge
- `/qa` : la boucle QA a nécessité un retour en `/feature`
- `/ship` : le pipeline CI a échoué et a dû être corrigé
- N'importe quelle commande : une hypothèse s'est avérée fausse

**Format à respecter :**
```markdown
### YYYY-MM-DD — [AGENT] Titre court

**Contexte** : <situation — projet, feature, commande lancée>
**Erreur** : <ce qui a mal tourné — code précis si possible>
**Correction** : <ce qui a été fait>
**Règle** : <formulation actionnable, commençant par un verbe>
**Tags** : #<tag(s)>
```

**Où insérer :** après la ligne `## Entrées`, avant la première entrée existante.
(Les entrées les plus récentes en haut.)

---

## CONSULTATION MANUELLE

Pour consulter les lessons par thème :
```bash
grep -B 1 -A 8 "#security" tasks/lessons.md
grep -B 1 -A 8 "#performance" tasks/lessons.md
grep -B 1 -A 8 "#architecture" tasks/lessons.md
```

Pour voir les 5 dernières erreurs (tous agents) :
```bash
grep -n "^### " tasks/lessons.md | head -5
```

---

## PARTAGE CROSS-PROJETS

Les lessons sont par défaut locales au projet (`tasks/lessons.md`).
Pour partager une leçon universelle (ex: un pattern d'erreur qui ne dépend pas du contexte
du projet), la dupliquer dans `~/.archipel/lessons-global.md` avec le même format.

```bash
# Lire les lessons globales en plus des locales
grep -B 1 -A 8 "#<tag>" ~/.archipel/lessons-global.md 2>/dev/null || true
grep -B 1 -A 8 "#<tag>" tasks/lessons.md 2>/dev/null || echo "Aucune leçon"
```

Les agents ne lisent pas automatiquement le fichier global — l'humain décide
quelles leçons méritent d'être promues au rang global.
