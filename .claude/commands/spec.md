# /spec — Idée → PRD + ADR + tickets Jira

Reçoit une idée en une phrase. Produit un PRD, un ADR, et des tickets Jira.
S'arrête quand les tickets sont créés et confirmés.

---

## Usage

```
/spec <idée en une phrase>
```

Exemple : `/spec Ajouter un système de notifications push pour les alertes de déploiement`

---

## Protocole d'exécution

### Étape 1 — Lire le contexte projet

```bash
cat .archipel/project.json

# Si /discover a été lancé avant, consommer le brief produit
cat docs/brief.md 2>/dev/null || echo "Pas de brief — utiliser l'argument CLI directement"
```

Extraire de `project.json` : `name`, `stack`, `type` pour contextualiser les specs.
Si `docs/brief.md` existe : intégrer le périmètre, la valeur attendue et les hors-périmètres
déjà validés par l'humain lors du /discover — ne pas les reposer comme questions ouvertes.

### Étape 2 — Générer `docs/PRD.md`

Structure obligatoire :

```markdown
# PRD — <titre de la feature>

## Contexte
<Pourquoi cette feature ? Quel problème résout-elle ?>

## Objectif
<Ce que l'utilisateur pourra faire après implémentation>

## Périmètre
### In scope
- ...
### Out of scope
- ...

## User Stories
- En tant que <rôle>, je veux <action> afin de <bénéfice>

## Critères d'acceptation
- [ ] ...

## Stack concernée
<nextjs | python-api | workers — dérivé de project.json>

## Dépendances
<Autres features, services externes, migrations DB>
```

### Étape 3 — Générer `docs/ADR.md`

Structure obligatoire :

```markdown
# ADR — <titre>

## Statut
Proposé

## Contexte
<Situation technique actuelle>

## Décision
<Choix technique retenu et pourquoi>

## Alternatives considérées
| Option | Avantages | Inconvénients |
|--------|-----------|---------------|
| ...    | ...       | ...           |

## Conséquences
<Impact sur la codebase, les migrations, les tests>
```

### Étape 4 — Tickets (optionnel selon project.json)

```bash
JIRA=$(python3 -c "import json; d=json.load(open('.archipel/project.json')); print(d.get('jira_project',''))" 2>/dev/null)
```

**Si `jira_project` est défini** → créer via MCP Atlassian :
- 1 ticket Epic : `[EPIC] <titre de la feature>`
- 1 ticket Story par User Story du PRD
- 1 ticket Tech : `[TECH] Migrations DB` si schéma modifié

**Si `jira_project` est absent (mode solo)** → créer `docs/tasks.md` :

```markdown
# Tasks — <titre feature>

## Backlog
- [ ] <tâche 1>
- [ ] <tâche 2>
...
```

### Étape 5 — Boucle de validation humaine

Présenter le PRD et l'ADR, demander validation via AskUserQuestion :

1. **PRD** — périmètre et critères d'acceptation corrects ?
   - `valider`
   - `ajuster le périmètre` — préciser via Other
   - `revoir les critères` — préciser via Other

2. **ADR** — décisions techniques acceptables ?
   - `valider`
   - `changer l'approche` — préciser via Other

Répéter jusqu'à validation sur PRD ET ADR.

```bash
test -f docs/PRD.md && test -f docs/ADR.md && echo "✅ Specs validées"
```

---

## Critère de sortie

- PRD validé par l'humain
- ADR validé par l'humain
- Tickets Jira créés **OU** `docs/tasks.md` créé (mode solo)
- `docs/PRD.md` et `docs/ADR.md` avec statut `Validé`
