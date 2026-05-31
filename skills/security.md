# Skill — Sécurité

Utilisé par le `/review` (dimension Sécurité) et pendant `/feature`.

---

## Règles absolues

### Secrets
- **Jamais de secrets dans le code** : clés API, passwords, tokens, connection strings
- Uniquement via variables d'environnement (`process.env.X` ou `os.environ["X"]`)
- En prod : Secret Manager (GCP) ou Key Vault (Azure) — jamais de `.env` committé
- Ajouter `.env*` dans `.gitignore` dès le premier commit

```bash
# Vérifier avant tout push
gitleaks detect --no-git
```

### Validation des entrées — API (Pydantic v2)

```python
# ✅ Toujours valider avec Pydantic, jamais de dict brut
from pydantic import BaseModel, field_validator, EmailStr

class UserCreate(BaseModel):
    email: EmailStr          # validation built-in
    name: str
    age: int

    @field_validator("age")
    @classmethod
    def age_must_be_positive(cls, v: int) -> int:
        if v < 0 or v > 150:
            raise ValueError("Age invalide")
        return v

# ❌ Interdit
@router.post("/users")
async def create_user(data: dict):  # dict brut = pas de validation
    ...
```

### Validation des entrées — Web (Zod)

```typescript
import { z } from "zod"

const UserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  age: z.number().int().min(0).max(150),
})

// Dans une Server Action
export async function createUser(formData: FormData) {
  const parsed = UserSchema.safeParse({
    email: formData.get("email"),
    name: formData.get("name"),
  })
  if (!parsed.success) {
    return { error: parsed.error.flatten() }
  }
  // utiliser parsed.data — typé et validé
}
```

### SQL — jamais de concaténation

```python
# ✅ ORM SQLAlchemy uniquement
result = await session.execute(
    select(User).where(User.email == email)  # paramétré automatiquement
)

# ❌ Interdit — injection SQL possible
query = f"SELECT * FROM users WHERE email = '{email}'"
result = await session.execute(text(query))
```

### Rendu HTML — sanitisation obligatoire

```typescript
// ✅ Toujours sanitiser avant rendu HTML brut
import DOMPurify from "dompurify"

const clean = DOMPurify.sanitize(userContent)
// puis utiliser dans un contexte contrôlé

// ❌ Jamais sans sanitisation préalable
// innerHTML = userContent  ← XSS direct
```

### Authentification et autorisation

```python
# Toujours vérifier l'auth avec Depends()
from fastapi import Depends, HTTPException, status

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    user = verify_token(token)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    return user

# Sur tous les endpoints privés
@router.get("/profile")
async def get_profile(current_user: User = Depends(get_current_user)) -> UserResponse:
    ...

# ❌ Endpoint sans auth
@router.get("/admin/users")
async def list_all_users(db: AsyncSession = Depends(get_db)):  # pas d'auth !
    ...
```

### CORS — jamais de wildcard en production

```python
# ✅ Liste explicite des origines
from fastapi.middleware.cors import CORSMiddleware

origins = os.environ.get("ALLOWED_ORIGINS", "").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,     # liste explicite
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

# ❌ Interdit en prod
app.add_middleware(CORSMiddleware, allow_origins=["*"])
```

### Uploads de fichiers

```python
import os
from pathlib import Path

UPLOAD_DIR = Path("/tmp/uploads").resolve()

def safe_path(filename: str) -> Path:
    # Empêcher le path traversal
    clean_name = Path(filename).name  # retire les ../ etc.
    target = (UPLOAD_DIR / clean_name).resolve()
    if not str(target).startswith(str(UPLOAD_DIR)):
        raise ValueError("Path traversal détecté")
    return target
```

### Logs — pas de données sensibles

```python
# ✅ Logger les IDs, pas les valeurs sensibles
logger.info("user.login", extra={"user_id": user.id, "ip": request.client.host})

# ❌ Interdit
logger.info(f"Login: email={user.email}, password={password}")  # PII + secret en clair
```

---

## Checklist sécurité (avant chaque merge)

- [ ] Aucun secret dans le code (`gitleaks detect --no-git`)
- [ ] Toutes les entrées validées (Pydantic / Zod)
- [ ] Aucune requête SQL brute
- [ ] Auth vérifiée sur les endpoints privés
- [ ] CORS configuré avec liste explicite
- [ ] Logs sans PII ni secrets
- [ ] `.env` dans `.gitignore`
