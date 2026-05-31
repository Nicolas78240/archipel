# Skill — Next.js (TypeScript strict)

## Règles absolues

### TypeScript
- **Strict mode only** : `tsconfig.json` avec `"strict": true`, `"noImplicitAny": true`, `"noUncheckedIndexedAccess": true`
- **No `any`** : jamais. Utiliser `unknown` + type guard si nécessaire
- **Interfaces > types** : préférer `interface Foo {}` à `type Foo = {}`
  - Exception : unions, intersections, mapped types → `type` accepté
- **Pas de `as`** sans assertion explicite et commentaire justificatif

### Composants
- **Server Components first** : tout composant est Server Component par défaut
  - Ajouter `"use client"` uniquement si interaction côté client requise
  - Règle : si pas de `useState`, `useEffect`, event handlers → Server Component
- **Pas de `useEffect` pour le fetching** : utiliser `fetch` dans les Server Components ou `use()` hook
- **Async Server Components** : utiliser `async function Page()` et `await fetch()`

### Fetching
```typescript
// ✅ Correct — Server Component
async function ProductList() {
  const products = await fetch('/api/products').then(r => r.json())
  return <ul>{products.map(p => <li key={p.id}>{p.name}</li>)}</ul>
}

// ❌ Interdit — useEffect pour fetcher
function ProductList() {
  const [products, setProducts] = useState([])
  useEffect(() => { fetch('/api/products').then(...).then(setProducts) }, [])
  // ...
}
```

### Design system (projets perso)

**shadcn/ui est le design system par défaut** pour les projets `perso`.
Référence complète : `skills/shadcn.md`.

Règles d'utilisation dans Next.js :
- Les primitives shadcn vivent dans `components/ui/` — **ne jamais les modifier**
- Créer des wrappers métier dans `components/features/` qui composent `ui/`
- Utiliser `cn()` de `lib/utils.ts` pour les classes conditionnelles
- Theming via CSS vars dans `app/globals.css` (mappé depuis Figma)

Pour les projets `clubmed` : utiliser Trident UI (skill `cm-trident`), pas shadcn.

**Règles absolues clubmed**

- **Tailwind 4 uniquement** — Trident est incompatible avec Tailwind 3
- **Ne jamais créer de layout custom** — header, nav, sidebar = SidebarLayout Trident
- **Wrapper contenu obligatoire** — tout contenu applicatif doit être dans :
  ```tsx
  <div style={{ "--spacing": "0.25rem" } as React.CSSProperties} className="h-full">
  ```
  Sans ce wrapper : `p-4 = 4px` au lieu de `16px` (Trident impose `--spacing: 0.0625rem`)

L'installation est faite automatiquement par `/bootstrap` (depuis GentilGantt, pas le registry).
Référence complète : `skills/cm-trident.md`.

### Structure fichiers
```
src/
  app/              ← App Router (layouts, pages, routes, Server Actions)
  components/
    ui/             ← Primitives shadcn (générées, ne pas modifier)
    features/       ← Wrappers métier composant les primitives ui/
  lib/
    utils.ts        ← cn() helper (créé par shadcn init)
  hooks/            ← Custom hooks (uniquement si "use client")
  types/            ← Interfaces partagées
```

### Naming
- Fichiers composants : `PascalCase.tsx`
- Fichiers utilitaires : `camelCase.ts`
- Dossiers : `kebab-case`
- Props interfaces : `interface ButtonProps {}` (pas `type`)

### Performance
- Utiliser `next/image` pour toutes les images
- Utiliser `next/font` pour les polices
- Lazy load les composants lourds avec `dynamic()`
- Préférer les Server Actions aux API routes pour les mutations

### Tests (Jest + React Testing Library)
```typescript
// Tester le comportement, pas l'implémentation
// ✅ Tester ce que l'utilisateur voit
expect(screen.getByRole('button', { name: /submit/i })).toBeInTheDocument()

// ❌ Ne pas tester les détails d'implémentation
expect(wrapper.find('Button').props().onClick).toBeDefined()
```
- Coverage minimum : 80% (lignes, branches, fonctions)
- Mocks : uniquement pour les appels externes (DB, API tierces)
- `@testing-library/user-event` pour les interactions utilisateur
