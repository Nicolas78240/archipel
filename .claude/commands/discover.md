# /discover — Discovery Agent (POC)

Explore un espace problème, identifie les opportunités, produit un Brief
et valide la faisabilité technique avant d'engager /spec.
Correspond à l'étape "Discovery & Research" du workflow AI-Assisted.

Mode : Human+AI collaborative — l'agent explore, l'humain valide.

---

## Usage

```
/discover <espace problème en une phrase>
```

Exemple : `/discover améliorer la gestion des notifications pour les GOs Club Med`

---

## Protocole d'exécution

### Phase 1 — Exploration automatique

#### 1.1 Lire le contexte projet existant
```bash
cat .archipel/project.json 2>/dev/null || echo "Nouveau projet"
ls docs/ 2>/dev/null
```

#### 1.2 Recherche de l'espace problème

Pour chaque angle ci-dessous, produire 3-5 observations :

**Angle utilisateur :**
- Qui est impacté ? (persona, rôle, fréquence d'usage)
- Quel est le pain point actuel ?
- Quelle est la valeur attendue ?

**Angle technique :**
- Quelles APIs / services existants sont concernés ?
- Quelle stack est la plus adaptée (dérivé de project.json) ?
- Y a-t-il des contraintes techniques connues ?

**Angle business :**
- Quel est l'impact mesurable ? (KPI, metric)
- Quel est le coût de ne rien faire ?
- Y a-t-il des dépendances avec d'autres projets ?

#### 1.3 Analyse de faisabilité (POC mental)

Évaluer rapidement :
```
Complexité estimée : [faible | moyenne | élevée]
Risque technique   : [faible | moyen | élevé]
Valeur estimée     : [faible | moyenne | élevée]
Recommandation     : [go | go-avec-poc | no-go + raison]
```

---

### Phase 2 — Questions de cadrage (AskUserQuestion)

**Batch 1 :**
1. **Périmètre** — Quelle est la frontière de ce problème ?
   - `core feature` — c'est le cœur du projet
   - `amélioration` — c'est une évolution d'existant
   - `exploration` — on ne sait pas encore si ça vaut le coup

2. **Urgence** — Quel est le driver ?
   - `opportunité` — on veut tester quelque chose de nouveau
   - `pain utilisateur` — des utilisateurs souffrent maintenant
   - `dette technique` — on règle un problème interne

3. **Validation souhaitée** — Jusqu'où aller dans ce /discover ?
   - `brief only` — juste cadrer le problème, /spec ensuite
   - `poc technique` — vérifier la faisabilité avant de s'engager
   - `full discovery` — exploration complète avec alternatives

---

### Phase 3 — Produire les livrables

#### 3.1 `docs/brief.md` — Le Brief

```markdown
# Brief — <titre du problème>
Date : <ISO>
Statut : Draft

## Problème
<Description claire du problème en 2-3 phrases>

## Utilisateurs concernés
<Qui, combien, fréquence>

## Opportunité
<Ce qu'on pourrait faire, en une phrase>

## Valeur attendue
<Metric ou outcome mesurable>

## Hors périmètre
<Ce qu'on ne fait PAS dans cette initiative>

## Recommandation
[go | go-avec-poc | no-go]
Raison : <justification courte>

## Prochaine étape
→ /spec "<idée en une phrase>"
```

#### 3.2 Si `poc technique` demandé — `docs/poc.md`

```markdown
# POC — <titre>

## Question technique à valider
<Ce qu'on cherche à prouver>

## Approche
<Comment valider en minimum de code>

## Critères de succès
- [ ] ...

## Résultat
[en cours | validé | invalidé]
Notes : <observations>
```

---

### Phase 4 — Boucle de validation humaine

Présenter le brief généré et demander validation via AskUserQuestion :

- `valider` — le brief est correct, aller vers `/spec`
- `corriger` — des ajustements sont nécessaires (préciser lesquels via "Other")
- `no-go` — l'idée n'est pas viable, documenter et abandonner

**Si `corriger` :** intégrer le feedback, régénérer le brief, re-présenter.
**Répéter jusqu'à obtenir `valider` ou `no-go`.**

```bash
test -f docs/brief.md && echo "✅ Brief produit"
```

---

## Critère de sortie

La commande ne se termine QUE si l'une de ces conditions est vraie :
- Brief validé par l'humain → `docs/brief.md` avec statut `Validé` et prochaine étape `/spec`
- No-go explicite → `docs/brief.md` avec statut `Abandonné` et raison documentée
