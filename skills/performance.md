# Skill — Performance

Utilisé par le `/review` (dimension Performance) et pendant `/feature`.

---

## Règles absolues

### Base de données — éviter les N+1

```typescript
// ✅ Eager loading avec Prisma
const users = await prisma.user.findMany({
  include: {
    posts: true,        // joint en une requête
    profile: true,
  },
  take: 20,             // toujours paginer
  skip: offset,
})

// ❌ N+1 — une requête par user
const users = await prisma.user.findMany()
for (const user of users) {
  user.posts = await prisma.post.findMany({ where: { userId: user.id } }) // N requêtes !
}
```

```python
# ✅ SQLAlchemy — selectinload
from sqlalchemy.orm import selectinload

result = await session.execute(
    select(User)
    .options(selectinload(User.posts))  # joint en 2 requêtes max
    .limit(20)
    .offset(offset)
)

# ❌ N+1
users = (await session.execute(select(User))).scalars().all()
for user in users:
    posts = (await session.execute(select(Post).where(Post.user_id == user.id))).all()
```

### Concurrence — pas de await en boucle

```typescript
// ✅ Parallèle avec Promise.all
const [user, posts, settings] = await Promise.all([
  getUser(id),
  getPosts(id),
  getSettings(id),
])

// ❌ Séquentiel inutile
const user = await getUser(id)
const posts = await getPosts(id)      // attend user, inutile
const settings = await getSettings(id) // attend posts, inutile
```

```python
# ✅ asyncio.gather
import asyncio

user, posts, settings = await asyncio.gather(
    get_user(id),
    get_posts(id),
    get_settings(id),
)

# ❌ Séquentiel inutile
user = await get_user(id)
posts = await get_posts(id)
```

### Pagination — obligatoire sur toutes les listes

```python
# ✅ Pagination systématique
from pydantic import BaseModel

class PaginationParams(BaseModel):
    page: int = 1
    per_page: int = 20

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.per_page

@router.get("/items")
async def list_items(
    pagination: PaginationParams = Depends(),
    db: AsyncSession = Depends(get_db),
) -> Page[ItemResponse]:
    total = await db.scalar(select(func.count(Item.id)))
    items = (await db.execute(
        select(Item).limit(pagination.per_page).offset(pagination.offset)
    )).scalars().all()
    return Page(items=items, total=total, **pagination.model_dump())

# ❌ Retourner toute la table
@router.get("/items")
async def list_items(db: AsyncSession = Depends(get_db)):
    return (await db.execute(select(Item))).scalars().all()  # OOM possible
```

### Next.js — Server Components first

```typescript
// ✅ Fetch côté serveur, zéro JS client
async function ProductList({ categoryId }: { categoryId: string }) {
  const products = await getProducts(categoryId)  // s'exécute sur le serveur
  return <ul>{products.map(p => <ProductCard key={p.id} product={p} />)}</ul>
}

// ❌ useEffect = round-trip client → serveur → client
"use client"
function ProductList({ categoryId }: { categoryId: string }) {
  const [products, setProducts] = useState<Product[]>([])
  useEffect(() => {
    fetch(`/api/products?category=${categoryId}`)
      .then(r => r.json())
      .then(setProducts)
  }, [categoryId])
  // ...
}
```

### Images — next/image obligatoire

```typescript
// ✅ next/image — optimisation automatique (WebP, lazy, responsive)
import Image from "next/image"

<Image
  src="/hero.jpg"
  alt="Description explicite"
  width={800}
  height={600}
  priority={isAboveFold}  // LCP image
/>

// ❌ <img> brut — pas d'optimisation
<img src="/hero.jpg" alt="Hero" />
```

### Index DB — obligatoires sur les colonnes de filtre

```prisma
// ✅ Index sur toutes les FK et colonnes de filtre
model Post {
  id         String   @id
  user_id    String
  status     String
  created_at DateTime @default(now())

  @@index([user_id])           // FK
  @@index([status, created_at]) // filtre fréquent combiné
}
```

```python
# SQLAlchemy
from sqlalchemy import Index

class Post(Base):
    __tablename__ = "posts"
    id: Mapped[str] = mapped_column(primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    status: Mapped[str] = mapped_column(index=True)

    __table_args__ = (
        Index("idx_posts_status_created", "status", "created_at"),
    )
```

### Cache — stratégie par type de données

```typescript
// Next.js fetch caching
const data = await fetch(url, {
  next: {
    revalidate: 60,    // revalider après 60s (ISR)
    tags: ["products"] // invalidation par tag
  }
})

// Invalider depuis une Server Action
import { revalidateTag } from "next/cache"
revalidateTag("products")
```

---

## Checklist performance (avant chaque merge)

- [ ] Pas de N+1 queries (eager loading configuré)
- [ ] Pas de `await` en boucle (utiliser `Promise.all` / `asyncio.gather`)
- [ ] Toutes les listes paginées (`limit` + `offset`)
- [ ] Index DB sur FK et colonnes de filtre
- [ ] Images via `next/image`
- [ ] Fetching en Server Components (pas de `useEffect` pour la data)
- [ ] Timeouts configurés sur les appels externes
