# Skill — Figma (MCP)

Utilisé par `/design` pour lire les maquettes, extraire les tokens
et mapper les composants vers Trident (clubmed) ou Tailwind (perso).

---

## Configuration

Le MCP Figma est déclaré dans `.mcp.json` à la racine du projet.
Il s'active automatiquement si `FIGMA_ACCESS_TOKEN` est présent dans l'environnement.

```bash
# Créer un token sur https://www.figma.com/developers/api#access-tokens
export FIGMA_ACCESS_TOKEN=fig_xxxxxxxxxxxxxxxx

# Vérifier que le MCP répond
# (Claude Code charge le MCP au démarrage si .mcp.json est présent)
```

---

## Extraire le fileId depuis une URL Figma

```
https://www.figma.com/file/ABC123xyz/Mon-Projet?node-id=0%3A1
                           ↑
                        fileId = "ABC123xyz"

https://www.figma.com/design/DEF456uvw/Mon-Projet
                             ↑
                          fileId = "DEF456uvw"
```

---

## Outils MCP disponibles

### `mcp__figma__get_file`
Lit la structure complète d'un fichier Figma.
```
Input  : { "fileId": "ABC123" }
Output : { pages, components, styles, ... }
```
Utiliser pour : découvrir la structure du fichier, lister les pages.

### `mcp__figma__get_file_nodes`
Lit des nœuds spécifiques (frames, composants, groupes).
```
Input  : { "fileId": "ABC123", "ids": ["1:2", "3:4"] }
Output : { nodes: { "1:2": { ... }, "3:4": { ... } } }
```
Utiliser pour : lire le contenu d'une frame spécifique.

### `mcp__figma__get_file_components`
Liste tous les composants définis dans le fichier.
```
Input  : { "fileId": "ABC123" }
Output : { components: [ { key, name, description, ... } ] }
```
Utiliser pour : identifier les composants réutilisables, mapper vers Trident.

### `mcp__figma__get_file_styles`
Liste les styles (couleurs, textes, effets) définis dans le fichier.
```
Input  : { "fileId": "ABC123" }
Output : { styles: [ { key, name, styleType, ... } ] }
```
Utiliser pour : extraire les tokens de design (couleurs, typographie).

### `mcp__figma__get_image`
Exporte un nœud en image (PNG/SVG).
```
Input  : { "fileId": "ABC123", "ids": ["1:2"], "format": "svg" }
Output : { images: { "1:2": "<url>" } }
```
Utiliser pour : exporter des icônes ou illustrations en SVG.

---

## Workflow type dans /design

```
1. Extraire fileId depuis l'URL
2. get_file → identifier les pages et frames de la feature
3. get_file_components → lister les composants utilisés
4. get_file_styles → extraire couleurs + typographie
5. Pour chaque composant :
   - clubmed → mapper vers Trident (invoquer cm-trident pour valider)
   - perso   → mapper vers Tailwind/shadcn
6. Pour chaque style :
   - mapper vers tailwind.config.ts ou variables CSS
```

---

## Mapping Figma → Trident (clubmed)

| Pattern de nom Figma     | Composant Trident      | Import                              |
|--------------------------|------------------------|-------------------------------------|
| Button, CTA, Action      | TridentButton          | `@trident/button`                   |
| Input, TextField, Field  | TridentInput           | `@trident/input`                    |
| Select, Dropdown         | TridentSelect          | `@trident/select`                   |
| Modal, Dialog, Overlay   | TridentModal           | `@trident/modal`                    |
| Card, Tile               | TridentCard            | `@trident/card`                     |
| Badge, Tag, Chip         | TridentBadge           | `@trident/badge`                    |
| Alert, Banner            | TridentAlert           | `@trident/alert`                    |
| Toast, Notification      | TridentToast           | `@trident/toast`                    |
| Table, List, Grid        | TridentTable           | `@trident/table`                    |
| Nav, Header, Menu        | TridentNav             | `@trident/nav`                      |
| Tabs                     | TridentTabs            | `@trident/tabs`                     |
| Accordion                | TridentAccordion       | `@trident/accordion`                |
| Checkbox                 | TridentCheckbox        | `@trident/checkbox`                 |
| Radio                    | TridentRadio           | `@trident/radio`                    |
| Switch, Toggle           | TridentSwitch          | `@trident/switch`                   |
| Spinner, Loader          | TridentSpinner         | `@trident/spinner`                  |

Si un composant Figma ne correspond à aucun pattern → composant custom,
nommer avec le préfixe du projet (ex: `GanttRow`, `BookingCard`).

---

## Mapping Figma → shadcn/ui (perso — défaut recommandé)

Référence complète dans `skills/shadcn.md`.
Setup : `npx shadcn@latest init` dans `apps/web/` si pas encore fait.

| Pattern de nom Figma     | Composant shadcn     | Commande d'ajout          |
|--------------------------|----------------------|---------------------------|
| Button / CTA             | `<Button>`           | `add button`              |
| Input / TextField        | `<Input>`            | `add input`               |
| Textarea                 | `<Textarea>`         | `add textarea`            |
| Select / Dropdown        | `<Select>`           | `add select`              |
| Checkbox                 | `<Checkbox>`         | `add checkbox`            |
| Switch / Toggle          | `<Switch>`           | `add switch`              |
| Form + validation        | `<Form>`             | `add form`                |
| Card / Tile              | `<Card>`             | `add card`                |
| Badge / Tag              | `<Badge>`            | `add badge`               |
| Modal / Dialog           | `<Dialog>`           | `add dialog`              |
| Sheet / Drawer           | `<Sheet>`            | `add sheet`               |
| Alert / Banner           | `<Alert>`            | `add alert`               |
| Toast / Notification     | `<Sonner>`           | `add sonner`              |
| Tooltip                  | `<Tooltip>`          | `add tooltip`             |
| Popover                  | `<Popover>`          | `add popover`             |
| Dropdown Menu            | `<DropdownMenu>`     | `add dropdown-menu`       |
| Table / Grid             | `<Table>`            | `add table`               |
| Tabs                     | `<Tabs>`             | `add tabs`                |
| Accordion                | `<Accordion>`        | `add accordion`           |
| Navigation               | `<NavigationMenu>`   | `add navigation-menu`     |
| Calendar / DatePicker    | `<Calendar>`         | `add calendar`            |
| Avatar                   | `<Avatar>`           | `add avatar`              |
| Skeleton / Loader        | `<Skeleton>`         | `add skeleton`            |
| Pagination               | `<Pagination>`       | `add pagination`          |
| Progress                 | `<Progress>`         | `add progress`            |
| [non trouvé dans shadcn] | composant custom     | `components/features/`    |

---

## Tokens — convention de nommage

```typescript
// tailwind.config.ts — ajouter les tokens extraits de Figma
export default {
  theme: {
    extend: {
      colors: {
        // Nom Figma "Primary/500" → primary.500
        primary: {
          50:  "#E6F0FF",
          500: "#0066CC",  // extrait de Figma
          900: "#003366",
        },
      },
      fontFamily: {
        // Nom Figma "Body" → font-body
        body: ["Inter", "sans-serif"],
      },
    },
  },
}
```

---

## Erreurs courantes

| Erreur | Cause | Solution |
|--------|-------|---------|
| `FIGMA_ACCESS_TOKEN not set` | Variable d'env manquante | `export FIGMA_ACCESS_TOKEN=fig_xxx` |
| `403 Forbidden` | Token invalide ou expiré | Régénérer sur figma.com/developers |
| `404 Not Found` | fileId incorrect ou accès privé | Vérifier l'URL et les permissions de partage |
| `Component not found in Trident` | Composant custom non documenté | Invoquer `cm-trident` pour recherche avancée |
