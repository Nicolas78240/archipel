# /design — Designer Agent

Reçoit un PRD. Produit un DRD (Design Reference Document) ancré dans la réalité :
frames Figma lues via MCP, tokens extraits, composants Trident mappés (clubmed)
ou Tailwind proposés (perso).

Mode : Human-AI collaborative — l'agent lit et structure, l'humain valide.

Prérequis : `FIGMA_ACCESS_TOKEN` dans l'environnement (optionnel mais recommandé).

---

## Usage

```
/design <JIRA-ID>                          ← lit docs/PRD.md + demande URL Figma
/design <JIRA-ID> <url-figma>              ← lit Figma directement
/design <JIRA-ID> --no-figma               ← génération depuis PRD uniquement
```

---

## Protocole d'exécution

### Phase 1 — Lire le contexte projet

```bash
cat .archipel/project.json
cat docs/PRD.md
cat docs/brief.md 2>/dev/null
```

Extraire depuis `project.json` :
- `type` → `perso` ou `clubmed` (détermine le design system)
- `stack` → confirmer que `nextjs` est présent

---

### Phase 2 — Source de design (AskUserQuestion si non fourni en argument)

Si aucune URL Figma n'est passée en argument :

1. **Source du design**
   - `Figma` — j'ai un fichier Figma avec les maquettes (je vais fournir l'URL)
   - `Figma partiel` — j'ai des maquettes mais pas pour toute la feature
   - `Aucun` — pas de maquettes, générer depuis le PRD uniquement

2. **Design system** (si `type == perso` uniquement — question non posée pour clubmed)
   - `shadcn/ui` — **défaut recommandé** : Radix UI + Tailwind + theming CSS vars (voir `skills/shadcn.md`)
   - `Tailwind CSS pur` — classes utilitaires uniquement, pas de primitives
   - `shadcn/ui déjà installé` — déjà présent dans le projet, utiliser l'existant
   - `autre` — préciser via "Other"

> Si `type == clubmed` → **Trident activé automatiquement**, pas de question.
> Si source == `Figma` → demander l'URL du fichier Figma.

---

### Phase 3 — Extraction Figma (si URL fournie)

#### 3.1 Connexion via MCP Figma

```
Outil : mcp__figma__get_file
Paramètre : fileId extrait de l'URL Figma
  Ex: https://www.figma.com/file/ABC123/... → fileId = "ABC123"
```

#### 3.2 Identifier les frames de la feature

```
Outil : mcp__figma__get_file_nodes
→ Lister les frames/pages en rapport avec la feature (filtrer par nom ou section)
```

Pour chaque frame identifiée :
- Nom de la frame → nom de la vue/écran dans le DRD
- Route suggérée (dérivée du nom)
- Description de ce que l'utilisateur fait sur cet écran

#### 3.3 Extraire les composants utilisés

```
Outil : mcp__figma__get_file_components
→ Liste des composants instanciés dans les frames de la feature
```

Pour chaque composant Figma trouvé :

**Si `type == clubmed` → mapping Trident :**
```
Composant Figma         →  Composant Trident
────────────────────────────────────────────
Button / CTA            →  <TridentButton>
Input / TextField       →  <TridentInput>
Modal / Dialog          →  <TridentModal>
Card                    →  <TridentCard>
Navigation              →  <TridentNav>
Badge / Tag             →  <TridentBadge>
Alert / Toast           →  <TridentToast>
Tableau / List          →  <TridentTable>
Formulaire              →  <TridentForm>
[non trouvé dans Trident] → composant custom, nommer avec préfixe du projet
```

Invoquer le skill `cm-trident` pour valider les noms exacts des composants disponibles.

**Si `type == perso` → mapping shadcn/ui (référence complète dans `skills/shadcn.md`) :**

Si shadcn n'est pas encore installé → lancer `npx shadcn@latest init` dans `apps/web/`.

```
Composant Figma              →  Composant shadcn             →  Commande d'ajout
─────────────────────────────────────────────────────────────────────────────────
Button / CTA                 →  <Button>                     →  add button
Input / TextField            →  <Input>                      →  add input
Select / Dropdown            →  <Select>                     →  add select
Modal / Dialog               →  <Dialog>                     →  add dialog
Sheet / Drawer latéral       →  <Sheet>                      →  add sheet
Card / Tile                  →  <Card>                       →  add card
Badge / Tag                  →  <Badge>                      →  add badge
Toast / Notification         →  <Sonner>                     →  add sonner
Alert / Banner               →  <Alert>                      →  add alert
Table / Grid                 →  <Table>                      →  add table
Tabs                         →  <Tabs>                       →  add tabs
Accordion                    →  <Accordion>                  →  add accordion
Calendar / DatePicker        →  <Calendar>                   →  add calendar
Formulaire avec validation   →  <Form> + react-hook-form     →  add form
Avatar                       →  <Avatar>                     →  add avatar
Skeleton                     →  <Skeleton>                   →  add skeleton
Pagination                   →  <Pagination>                 →  add pagination
[non trouvé dans shadcn]     →  composant custom Tailwind dans components/features/
```

Règle : **toujours wrapper les primitives `ui/` dans `components/features/`**.
Ne jamais modifier les fichiers `ui/` directement (voir `skills/shadcn.md`).

#### 3.4 Extraire les tokens de design

```
Outil : mcp__figma__get_file_styles
→ Couleurs, typographies, espacements définis dans le fichier Figma
```

Mapper vers les tokens du projet :
- Couleurs → variables CSS ou tokens Tailwind (`tailwind.config.ts`)
- Typographie → `font-family`, `text-*` classes Tailwind ou tokens Trident
- Espacements → `gap-*`, `p-*`, `m-*` ou tokens Trident

#### 3.5 Extraire les interactions et états

Pour chaque composant interactif, noter depuis Figma :
- États visibles : `default`, `hover`, `focus`, `disabled`, `error`, `loading`
- Transitions documentées dans Figma (prototype links)

---

### Phase 4 — Génération sans Figma (si `--no-figma` ou aucune URL)

Générer les flows, composants et tokens **depuis le PRD uniquement** :
- User Stories → flows utilisateur
- Critères d'acceptation → états des composants (succès, erreur, loading)
- Stack détectée → proposer les composants adaptés (Trident ou Tailwind)

#### Phase 4b — Design System (projets `perso` uniquement, systématique)

Appeler le tool **Agent** avec :
```
subagent_type : "design-system"
prompt        : "
  Domaine et contexte :
  <contenu de docs/PRD.md — sections Vision et Stack>

  Type projet : <perso>
  Stack : nextjs

  Analyser le domaine, déduire la direction visuelle, définir les tokens,
  écrire globals.css + tailwind.config.ts + composants UI de base.
  Produire docs/DESIGN-SYSTEM.md.
"
```

Attendre que l'agent ait écrit `docs/DESIGN-SYSTEM.md` avant de passer à la Phase 5.
Le DRD devra référencer ce document.

---

### Phase 5 — Produire `docs/DRD.md`

```markdown
# DRD — <titre de la feature>
Date : <ISO>
PRD source : docs/PRD.md
Figma source : <url ou "aucune">
Design system : <Trident (clubmed) | shadcn/ui (perso, défaut) | Tailwind pur | custom>
Statut : Draft

## Écrans / Vues

| Vue            | Route          | Frame Figma        | Description                    |
|----------------|----------------|--------------------|--------------------------------|
| <nom>          | <path>         | <nom frame Figma>  | <ce que l'utilisateur y fait>  |

## User Flows

### Flow principal : <action>
```
[État initial]
    ↓ <action utilisateur>
[État intermédiaire]
    ↓ <action utilisateur>
[État final / succès]
    ↓ (erreur possible)
[État d'erreur + message]
```

## Composants

### À créer
| Composant         | Source              | Type         | Props clés              | États                         |
|-------------------|---------------------|--------------|-------------------------|-------------------------------|
| <nom>             | Trident / custom    | server/client| <liste>                 | default, loading, error       |

### À modifier
| Composant         | Fichier             | Modification                |
|-------------------|---------------------|-----------------------------|
| <nom>             | <path>              | <description>               |

## Design System
Design system : <voir docs/DESIGN-SYSTEM.md>
Tokens principaux :
| Token | Valeur | Usage |
|-------|--------|-------|
| --primary | <hex> | CTA, actif |
| --background | <hex> | Fond |
| --surface | <hex> | Cards |

## Tokens extraits de Figma

### Couleurs
| Nom Figma          | Valeur hex   | Mapping Tailwind/Trident     |
|--------------------|--------------|------------------------------|
| Primary/500        | #0066CC      | `text-primary-500`           |

### Typographie
| Style Figma        | Font / Size / Weight | Classe Tailwind              |
|--------------------|----------------------|------------------------------|
| Heading/H1         | Inter 32px Bold      | `text-3xl font-bold`         |

## États des composants clés
| Composant     | default | hover | focus | disabled | loading | error |
|---------------|---------|-------|-------|----------|---------|-------|
| SubmitButton  | ✅      | ✅    | ✅    | ✅       | ✅      | -     |

## Accessibilité
- [ ] Tous les inputs ont un `<label>` associé
- [ ] Focus visible sur tous les éléments interactifs
- [ ] Contraste minimum 4.5:1 (WCAG AA) — vérifier avec tokens extraits
- [ ] Navigation clavier complète
- [ ] `aria-live` sur les zones de feedback dynamique

## Questions ouvertes
<Ce qui nécessite validation humaine — notamment les divergences Figma / Trident>
```

---

### Phase 6 — Boucle de validation humaine

Présenter le DRD section par section :

```
TANT QUE (DRD non validé) :
  1. Présenter les sections via AskUserQuestion :

     a. Écrans et flows — corrects ?
        - `valider` — les flows couvrent le PRD
        - `ajouter / corriger` — préciser via "Other"

     b. Mapping composants — correct ?
        - `valider` — les composants Trident/Tailwind sont bons
        - `changer un composant` — préciser via "Other"
        - `composant Figma non reconnu` — décrire le composant custom à créer

     c. Tokens — corrects ?
        - `valider` — les couleurs/typos sont bien mappées
        - `ajuster` — préciser via "Other"

     d. Questions ouvertes résolues ?
        - `oui, toutes résolues` → sortir de la boucle
        - `non` → répondre aux questions, mettre à jour le DRD, reboucler

  2. Si correction → mettre à jour le DRD, re-présenter la section
  3. Répéter
```

---

### Phase 7 — Vérification finale

```bash
test -f docs/DRD.md && \
python3 -c "
content = open('docs/DRD.md').read()
assert 'Statut : Validé' in content or 'Statut: Validé' in content, 'DRD non validé'
print('✅ DRD validé')
" 2>/dev/null || echo "⚠️ Penser à passer le statut à Validé"
```

---

## Critère de sortie

La commande ne se termine QUE si :
- `docs/DRD.md` existe avec statut `Validé`
- Tous les flows validés par l'humain
- Tous les composants mappés (Trident ou custom documenté)
- Zéro question ouverte bloquante
- Prochaine commande affichée : `/feature <JIRA-ID>`

---

## Configuration requise

```bash
# Vérifier que le MCP Figma est disponible
echo $FIGMA_ACCESS_TOKEN | head -c 5  # doit afficher les 5 premiers chars du token

# Si non configuré :
# Aller sur https://www.figma.com/developers/api#access-tokens
# Créer un Personal Access Token
# Ajouter dans l'environnement : export FIGMA_ACCESS_TOKEN=fig_xxx...
```

Le MCP Figma est déclaré dans `.mcp.json` à la racine du projet.
Il est actif automatiquement si `FIGMA_ACCESS_TOKEN` est dans l'environnement.
