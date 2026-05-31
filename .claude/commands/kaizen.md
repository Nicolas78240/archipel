# /kaizen — Amélioration continue de la factory

Analyse les livrables d'un build terminé et capitalise sur les apprentissages
pour améliorer les agents et commandes Archipel.

**État : EN ATTENTE — activer après validation de V3**

---

## Usage

```
/kaizen --observe     ← après un build, analyse sans modifier
/kaizen --improve     ← propose et applique des améliorations (validation humaine)
```

---

## Condition d'activation

Ne pas invoquer avant que ces trois conditions soient réunies :
1. Au moins 3 builds complets exécutés (V1, V2, V3 minimum)
2. V3 stable — pas de régression sur les bugs de V1/V2
3. Les gates fondamentaux fonctionnent (DESIGN-SYSTEM.md, IMPL-*.md sur disque, corrections via agents)

---

## Protocole

### Mode `--observe`

Appeler le tool **Agent** avec :
```
subagent_type : "kaizen"
prompt        : "
  Mode : observation uniquement

  Build report :
  <contenu de docs/build-report.md>

  Lessons accumulées :
  <contenu de tasks/lessons.md>

  Plans d'implémentation produits :
  <liste des docs/IMPL-*.md avec leur contenu>

  Identifier les patterns d'erreurs récurrentes, d'agents défaillants,
  de qualité et de séquence. Produire docs/kaizen-observations.md.
  Ne modifier aucun fichier agent ou commande.
"
```

### Mode `--improve`

Lire `docs/kaizen-observations.md` puis appeler le tool **Agent** :
```
subagent_type : "kaizen"
prompt        : "
  Mode : amélioration avec validation humaine

  Observations accumulées :
  <contenu de docs/kaizen-observations.md>

  Présenter les 3 améliorations à plus fort impact.
  Attendre validation humaine avant toute modification.
"
```

---

## Critère de sortie

**Mode `--observe`** : `docs/kaizen-observations.md` produit ou mis à jour.
**Mode `--improve`** : modifications appliquées uniquement sur ce qui a été validé.
