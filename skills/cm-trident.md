# Skill — Trident UI (Club Med)

Design system officiel Club Med. Basé sur Tailwind 4 + shadcn + composants propriétaires.
Applicable uniquement aux projets `type: clubmed`.

---

## Règle absolue — Tailwind 4, jamais 3

Trident UI est construit sur Tailwind 4. Tailwind 3 est incompatible (clip-path arbitraire,
variables CSS custom). Ne jamais installer `tailwindcss@3.x` sur un projet clubmed.

---

## Setup initial

### package.json — dépendances obligatoires

```json
{
  "devDependencies": {
    "tailwindcss": "^4.2.1",
    "@tailwindcss/postcss": "^4.2.1",
    "postcss": "^8.5"
  }
}
```

```bash
cd apps/web
npm install -D tailwindcss@^4.2.1 @tailwindcss/postcss@^4.2.1 postcss@^8.5
```

### postcss.config.js

```javascript
module.exports = { plugins: { "@tailwindcss/postcss": {} } };
```

### globals.css — structure obligatoire

```css
@import "tailwindcss";

/* Trident spacing : 1px = 1 unité (remplacé à 0.25rem dans le contenu app) */
:root {
  --spacing: 0.0625rem;
}

/* Tokens couleurs Trident */
@theme {
  --color-ultramarine: #1E2643;
  --color-saffron:     #FDBE00;
  --color-lightSand:   #F6EFE7;
  --color-lightGrey:   #CCCCCC;
  --color-darkGrey:    #333333;
  --color-middleGrey:  #666666;
  --color-pearl:       #F7F7F7;
  --radius-pill:       9999px;
  --font-sans:         Inter, system-ui, sans-serif;
}
```

Pas de `@tailwind base/components/utilities`. Pas de `@import "shadcn/tailwind.css"`.

### tailwind.config.ts — minimal

```typescript
// Tailwind 4 : la config principale est dans globals.css (@theme)
export default { content: ["./src/**/*.{ts,tsx}"] };
```

---

## SidebarLayout — installation

Le registry Trident a un bug connu : `@/ui/hooks/useSlots` est listé comme dépendance npm
au lieu d'un fichier local. Le registry installe bien le composant, mais plante sur ce hook.

**Solution : registry + création manuelle de `useSlots.ts`.**

```bash
cd apps/web
mkdir -p src/hooks

# 1. Installer depuis le registry (ignorera l'erreur useSlots)
echo "y" | npx shadcn@latest add https://develop.trident-ui.pro.clubmed/r/sidebar-layout.json || true

# 2. Créer useSlots.ts manuellement (corrige le bug)
cat > src/hooks/useSlots.ts << 'EOF'
import { Children, isValidElement, ReactNode } from "react"

export function useSlots(
  children: ReactNode,
  slotNames: string[]
): Record<string, ReactNode> {
  const slots: Record<string, ReactNode> = {}

  Children.forEach(children, (child) => {
    if (!isValidElement(child)) return
    const slot = (child.props as { "data-slot"?: string })["data-slot"]
    if (slot && slotNames.includes(slot)) {
      slots[slot] = child
    }
  })

  return slots
}
EOF

# 3. Activer les icônes Trident dans next.config.ts
# Ajouter transpilePackages: ["@clubmed/trident-icons"]
```

`next.config.ts` :

```typescript
const nextConfig = {
  transpilePackages: ["@clubmed/trident-icons"],
}
export default nextConfig
```

---

## Règle d'or du spacing

Trident impose `--spacing: 0.0625rem` globalement (1px = 1 unité).
Conséquence : `p-4 = 4px`, `w-11 = 11px` — ce qui casse tout le contenu non-Trident.

**Tout contenu applicatif doit être wrappé** avec `--spacing: 0.25rem` pour retrouver
le comportement Tailwind standard (p-4 = 16px, w-11 = 44px) :

```tsx
// ✅ Pattern obligatoire dans AppLayout
<SidebarLayout ...>
  <div style={{ "--spacing": "0.25rem" } as React.CSSProperties} className="h-full">
    {children}
  </div>
</SidebarLayout>

// ❌ Sans wrapper — p-4 = 4px, layouts cassés
<SidebarLayout ...>
  {children}
</SidebarLayout>
```

---

## SidebarLayout — props API

```tsx
import { SidebarLayout } from "@/components/ui/SidebarLayout"

// Exemples d'icônes valides : "Home", "CalendarDefault", "Settings",
// "Search", "Edit", "Delete", "Login", "Folder", "Menu"
// Liste complète : node_modules/@clubmed/trident-icons/Iconics.d.ts

<SidebarLayout
  items={[
    { label: "Dashboard", icon: "Home",            href: "/" },
    { label: "Projets",   icon: "CalendarDefault", href: "/projects" },
  ]}
  activeIndex={activeIndex}
  header={<div className="flex-1 flex items-center">...</div>}
  logoutAction={{ callback: handleLogout, label: "Se déconnecter" }}
>
  <div style={{ "--spacing": "0.25rem" } as React.CSSProperties} className="h-full">
    {children}
  </div>
</SidebarLayout>
```

| Prop | Type | Note |
|------|------|------|
| `items` | `Array<{label, icon, href}>` | **`items`** — icônes : voir `Iconics.d.ts` |
| `activeIndex` | `number` | Index de l'item actif |
| `children` avec `data-slot` | `ReactNode` | Slots : `header`, `header-logo`, `header-actions` |
| children sans slot | `ReactNode` | Contenu principal (rendu dans `<main>`) |

---

## Dropdown user menu — pattern

Toujours utiliser `style={{ minWidth: "280px" }}` (pixels explicites) pour la largeur,
pas `min-w-280` (avec `--spacing: 0.0625rem` sur le parent = 17.5rem × 0.0625 = 1.09rem ≠ 280px).

---

## Azure AD — profil utilisateur (SSO Club Med)

### Graph API — champs disponibles après SSO

```python
# Backend FastAPI — appelé dans le callback SSO
azure_user = await get_user_info(azure_access_token)
# Retourne : id (oid), displayName, mail, userPrincipalName,
#            jobTitle, department, officeLocation

photo_url = await get_user_photo(azure_access_token)
# Retourne : "data:image/jpeg;base64,..." ou None
```

### Table users — colonnes à prévoir dès le bootstrap DB

```sql
azure_oid        VARCHAR(255) UNIQUE,  -- object ID Entra ID
sso_provider     VARCHAR(50),          -- 'azure'
photo_url        TEXT,                 -- base64 data URL (rechargé à chaque connexion)
job_title        VARCHAR(255),
department       VARCHAR(255),
office_location  VARCHAR(255)
-- password_hash nullable (pas de login local sur clubmed)
```

Profil mis à jour à chaque connexion (jamais en cache statique) via `update_sso_profile()` dans `repositories/users.py`.

### Schéma Pydantic — GET /auth/me

```python
class UserRead(BaseModel):
    id: str
    email: str
    name: str
    role: str           # admin | manager | user (assigné manuellement — pas depuis Azure)
    hepta: str | None   # identifiant interne Club Med (assigné manuellement par admin)
    job_title: str | None
    department: str | None
    office_location: str | None
    photo_url: str | None
    is_active: bool
```

### Affichage profil dans le header — pattern standard

```tsx
{/* Section profil dans le dropdown user */}
<div className="p-4 bg-gray-50 border-b border-gray-200">
  <div className="flex items-start gap-3">

    {/* Photo Azure AD (base64 data URL) */}
    {user?.photo_url ? (
      <img
        src={user.photo_url}
        alt={user.name}
        className="w-11 h-11 rounded-full object-cover flex-shrink-0"
      />
    ) : (
      /* Fallback : initiales sur fond saffron */
      <div className="w-11 h-11 rounded-full bg-saffron flex items-center
                      justify-center text-black font-bold text-sm flex-shrink-0">
        {user?.name?.split(" ").map(n => n[0]).slice(0, 2).join("")}
      </div>
    )}

    <div className="flex-1 min-w-0">
      <p className="font-semibold text-darkGrey text-sm truncate">{user?.name}</p>
      {user?.job_title       && <p className="text-xs text-middleGrey truncate">{user.job_title}</p>}
      {user?.department      && <p className="text-xs text-middleGrey truncate">{user.department}</p>}
      {user?.office_location && <p className="text-xs text-middleGrey truncate">{user.office_location}</p>}
      <p className="text-xs text-middleGrey truncate mt-1">{user?.email}</p>
    </div>

  </div>
</div>
```

**Points d'attention :**
- `photo_url` est une base64 data URL (50-100 Ko) — ne jamais stocker en cookie ou localStorage, uniquement en mémoire React (contexte)
- `hepta` : identifiant interne Club Med, renseigné manuellement par un admin dans `/admin/users` — Azure AD ne le fournit pas
- `role` (admin/manager/user) : assigné manuellement — ne pas utiliser Azure AD Groups
- Affichage compact dans la sidebar : photo 32px + nom + chevron
- Affichage complet dans le dropdown : photo 44px + toutes les infos + rôle + déconnexion

---

## Checklist avant de coder le premier composant

- [ ] `tailwindcss@^4.2.1` installé (vérifier `package.json`)
- [ ] `postcss.config.js` présent avec `@tailwindcss/postcss`
- [ ] `globals.css` commence par `@import "tailwindcss"` (pas `@tailwind`)
- [ ] `--spacing: 0.0625rem` dans `:root` de `globals.css`
- [ ] `SidebarLayout.tsx` copié depuis GentilGantt (pas du registry)
- [ ] `transpilePackages: ["@clubmed/trident-icons"]` dans `next.config.ts`
- [ ] Contenu applicatif wrappé avec `--spacing: 0.25rem`
- [ ] Dropdown largeurs en `px` explicites (pas en classes Tailwind)
