# Skill — shadcn/ui

Design system par défaut pour les projets `perso`.
Composants Radix UI + Tailwind CSS + animations Framer Motion.
Non applicable aux projets `clubmed` (utiliser Trident à la place).

---

## Philosophie

shadcn/ui n'est pas une dépendance npm — c'est du **code copié dans le projet**.
Chaque composant ajouté avec `npx shadcn@latest add` crée un fichier dans
`apps/web/src/components/ui/` que tu possèdes et peux modifier librement.

Conséquence : **ne jamais modifier les fichiers `ui/` directement**.
Créer des wrappers dans `components/features/` qui composent les primitives `ui/`.

---

## Setup initial

```bash
cd apps/web

# Initialiser shadcn dans le projet Next.js
npx shadcn@latest init

# Répondre aux questions :
# Style        → Default (ou New York si préférence)
# Base color   → Neutral (s'adapte à n'importe quelle palette Figma)
# CSS vars     → Yes (obligatoire pour le theming dynamique)
```

Cela crée :
- `components/ui/` — dossier des primitives
- `lib/utils.ts` — fonction `cn()` pour merger les classes Tailwind
- `app/globals.css` — variables CSS de theming (--background, --primary, etc.)
- Met à jour `tailwind.config.ts`

---

## Ajouter un composant

```bash
# Syntaxe
npx shadcn@latest add <composant>

# Exemples
npx shadcn@latest add button
npx shadcn@latest add dialog
npx shadcn@latest add form
npx shadcn@latest add table

# Plusieurs à la fois
npx shadcn@latest add button input label form card dialog toast
```

---

## Catalogue complet — mapping Figma → shadcn

| Composant Figma          | Commande shadcn             | Fichier créé                |
|--------------------------|-----------------------------|-----------------------------|
| Button / CTA             | `add button`                | `ui/button.tsx`             |
| Input / TextField        | `add input`                 | `ui/input.tsx`              |
| Textarea                 | `add textarea`              | `ui/textarea.tsx`           |
| Select / Dropdown        | `add select`                | `ui/select.tsx`             |
| Checkbox                 | `add checkbox`              | `ui/checkbox.tsx`           |
| Radio Group              | `add radio-group`           | `ui/radio-group.tsx`        |
| Switch / Toggle          | `add switch`                | `ui/switch.tsx`             |
| Slider                   | `add slider`                | `ui/slider.tsx`             |
| Label                    | `add label`                 | `ui/label.tsx`              |
| Form (validation)        | `add form`                  | `ui/form.tsx`               |
| Card / Tile              | `add card`                  | `ui/card.tsx`               |
| Badge / Tag              | `add badge`                 | `ui/badge.tsx`              |
| Modal / Dialog           | `add dialog`                | `ui/dialog.tsx`             |
| Sheet / Drawer           | `add sheet`                 | `ui/sheet.tsx`              |
| Alert / Banner           | `add alert`                 | `ui/alert.tsx`              |
| Toast / Notification     | `add sonner`                | `ui/sonner.tsx`             |
| Tooltip                  | `add tooltip`               | `ui/tooltip.tsx`            |
| Popover                  | `add popover`               | `ui/popover.tsx`            |
| Dropdown Menu            | `add dropdown-menu`         | `ui/dropdown-menu.tsx`      |
| Context Menu             | `add context-menu`          | `ui/context-menu.tsx`       |
| Command / Search         | `add command`               | `ui/command.tsx`            |
| Combobox                 | `add combobox`              | `ui/combobox.tsx`           |
| Table / Grid             | `add table`                 | `ui/table.tsx`              |
| Data Table               | `add data-table`            | `ui/data-table.tsx`         |
| Tabs                     | `add tabs`                  | `ui/tabs.tsx`               |
| Accordion                | `add accordion`             | `ui/accordion.tsx`          |
| Collapsible              | `add collapsible`           | `ui/collapsible.tsx`        |
| Navigation Menu          | `add navigation-menu`       | `ui/navigation-menu.tsx`    |
| Breadcrumb               | `add breadcrumb`            | `ui/breadcrumb.tsx`         |
| Pagination               | `add pagination`            | `ui/pagination.tsx`         |
| Calendar / DatePicker    | `add calendar`              | `ui/calendar.tsx`           |
| Date Range Picker        | `add date-picker`           | `ui/date-picker.tsx`        |
| Avatar                   | `add avatar`                | `ui/avatar.tsx`             |
| Skeleton / Loader        | `add skeleton`              | `ui/skeleton.tsx`           |
| Progress                 | `add progress`              | `ui/progress.tsx`           |
| Separator                | `add separator`             | `ui/separator.tsx`          |
| Scroll Area              | `add scroll-area`           | `ui/scroll-area.tsx`        |
| Aspect Ratio             | `add aspect-ratio`          | `ui/aspect-ratio.tsx`       |
| Resizable Panels         | `add resizable`             | `ui/resizable.tsx`          |
| Carousel                 | `add carousel`              | `ui/carousel.tsx`           |
| Chart                    | `add chart`                 | `ui/chart.tsx`              |
| Sidebar                  | `add sidebar`               | `ui/sidebar.tsx`            |

---

## Utilisation correcte

### Toujours wrapper, jamais modifier ui/

```typescript
// ✅ Wrapper dans components/features/
// apps/web/src/components/features/SubmitButton.tsx
import { Button } from "@/components/ui/button"
import { Loader2 } from "lucide-react"

interface SubmitButtonProps {
  loading?: boolean
  children: React.ReactNode
}

export function SubmitButton({ loading, children }: SubmitButtonProps) {
  return (
    <Button disabled={loading} type="submit">
      {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
      {children}
    </Button>
  )
}

// ❌ Ne pas modifier ui/button.tsx directement
```

### Utiliser `cn()` pour les classes conditionnelles

```typescript
import { cn } from "@/lib/utils"

<div className={cn(
  "base-classes",
  isActive && "active-classes",
  variant === "destructive" && "text-destructive"
)} />
```

### Formulaires avec react-hook-form + zod

shadcn `Form` est conçu pour s'utiliser avec `react-hook-form` et `zod` :

```typescript
"use client"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"

const schema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
})

export function UserForm() {
  const form = useForm<z.infer<typeof schema>>({
    resolver: zodResolver(schema),
    defaultValues: { email: "", name: "" },
  })

  async function onSubmit(values: z.infer<typeof schema>) {
    // Server Action ou fetch
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="email"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Email</FormLabel>
              <FormControl>
                <Input placeholder="you@example.com" {...field} />
              </FormControl>
              <FormMessage />  {/* affiche l'erreur zod */}
            </FormItem>
          )}
        />
        <Button type="submit">Enregistrer</Button>
      </form>
    </Form>
  )
}
```

---

## Theming depuis Figma

Quand les tokens sont extraits de Figma via MCP, les mapper vers
les variables CSS de shadcn dans `app/globals.css` :

```css
/* app/globals.css */
@layer base {
  :root {
    /* Mappage tokens Figma → variables shadcn */
    --background:   0 0% 100%;          /* Figma: Background/Default */
    --foreground:   222.2 84% 4.9%;     /* Figma: Text/Primary */
    --primary:      221.2 83.2% 53.3%;  /* Figma: Primary/500 */
    --primary-foreground: 210 40% 98%;  /* Figma: Primary/Foreground */
    --destructive:  0 84.2% 60.2%;      /* Figma: Error/500 */
    --muted:        210 40% 96.1%;      /* Figma: Surface/Muted */
    --border:       214.3 31.8% 91.4%;  /* Figma: Border/Default */
    --radius:       0.5rem;             /* Figma: Border Radius/MD */
  }

  .dark {
    /* Tokens dark mode si définis dans Figma */
    --background: 222.2 84% 4.9%;
    --foreground:  210 40% 98%;
    /* ... */
  }
}
```

---

## Dépendances requises

```bash
cd apps/web
npm install react-hook-form @hookform/resolvers zod
npm install lucide-react          # icônes (utilisées par shadcn)
npm install class-variance-authority clsx tailwind-merge  # installés par shadcn init
```

---

## Structure finale attendue

```
apps/web/src/
  components/
    ui/           ← primitives shadcn (ne pas modifier)
      button.tsx
      input.tsx
      dialog.tsx
      ...
    features/     ← wrappers métier qui composent ui/
      SubmitButton.tsx
      UserForm.tsx
      ProductCard.tsx
  lib/
    utils.ts      ← cn() helper (créé par shadcn init)
  app/
    globals.css   ← variables CSS theming (tokens Figma ici)
```
