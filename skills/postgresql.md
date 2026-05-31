# Skill — PostgreSQL

## Règles absolues

### Nommage — snake_case partout
- Tables : `snake_case` pluriel → `user_sessions`, `product_variants`
- Colonnes : `snake_case` → `created_at`, `updated_at`, `user_id`
- Index : `idx_<table>_<colonne(s)>` → `idx_users_email`
- Contraintes : `fk_<table>_<colonne>`, `uq_<table>_<colonne>`

### Migrations — jamais à la main

**Côté TypeScript (Prisma) :**
```bash
# Créer une migration après modification du schema
cd shared/db/prisma
npx prisma migrate dev --name <description-en-snake-case>

# Appliquer en prod
npx prisma migrate deploy

# JAMAIS
ALTER TABLE users ADD COLUMN foo TEXT;  # ← interdit
```

**Côté Python (Alembic) :**
```bash
# Générer automatiquement depuis les modèles SQLAlchemy
cd shared/db/alembic
alembic revision --autogenerate -m "<description>"
alembic upgrade head

# JAMAIS de migration manuelle sans --autogenerate
```

### Prisma (TypeScript)

```prisma
// schema.prisma — conventions
model UserSession {
  id         String   @id @default(cuid())
  user_id    String   @map("user_id")
  created_at DateTime @default(now()) @map("created_at")
  updated_at DateTime @updatedAt @map("updated_at")

  user User @relation(fields: [user_id], references: [id], onDelete: Cascade)

  @@index([user_id])
  @@map("user_sessions")  // ← nom de table snake_case
}
```

- Toujours mapper les noms camelCase JS vers snake_case DB avec `@map`
- Toujours inclure `created_at` et `updated_at`
- Soft delete : utiliser `deleted_at DateTime?` plutôt que `is_deleted Boolean`
- Relations : toujours définir `onDelete` explicitement

### SQLAlchemy (Python)

```python
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy.sql import func

class Base(DeclarativeBase):
    pass

class UserSession(Base):
    __tablename__ = "user_sessions"  # snake_case

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"))
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())
```

### Connexions async
- Toujours utiliser `asyncpg` + `SQLAlchemy[asyncio]` côté Python
- Pool configuré : `pool_size=5`, `max_overflow=10`, `pool_recycle=3600`
- Connection string format : `postgresql+asyncpg://user:pass@host:5432/db`

### Index et performance
- Index sur toutes les FK
- Index sur les colonnes de filtre fréquentes (`status`, `type`, `created_at`)
- Pas d'index inutile (coût en écriture)
- EXPLAIN ANALYZE avant tout index en prod

### Secrets
- `DATABASE_URL` uniquement via variables d'environnement
- Jamais de credentials dans le code ou les fichiers versionnés
- En prod : Secret Manager (GCP) ou Key Vault (Azure)
