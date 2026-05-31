# Skill — FastAPI (Python 3.12+)

## Règles absolues

### Pydantic v2
- **Tous les modèles héritent de `BaseModel`** (Pydantic v2)
- **Pas de `dict` brut** en entrée/sortie des endpoints
- Utiliser `model_config = ConfigDict(...)` (pas la classe `Config` v1)
- Validators : `@field_validator` (pas `@validator` v1)

```python
# ✅ Correct — Pydantic v2
from pydantic import BaseModel, ConfigDict, field_validator

class UserCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    email: str
    name: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        if "@" not in v:
            raise ValueError("Invalid email")
        return v.lower()

# ❌ Interdit — Pydantic v1 style
class UserCreate(BaseModel):
    class Config:
        anystr_strip_whitespace = True

    @validator("email")
    def validate_email(cls, v):
        ...
```

### Endpoints async
- **Tous les endpoints sont `async def`** — jamais de `def` synchrone
- Exception justifiée uniquement si librairie tierce bloquante (CPU-bound) → `run_in_executor`

```python
# ✅ Correct
@router.get("/users/{user_id}")
async def get_user(user_id: str, db: AsyncSession = Depends(get_db)) -> UserResponse:
    ...

# ❌ Interdit
@router.get("/users/{user_id}")
def get_user(user_id: str):  # sync dans FastAPI = thread pool, pas de connection pooling async
    ...
```

### Dependency Injection
- **Pas de globals mutables** : toujours passer via `Depends()`
- Session DB : `Depends(get_db)` — une session par requête
- Settings : `Depends(get_settings)` — singleton via `lru_cache`
- Auth : `Depends(get_current_user)`

```python
from functools import lru_cache
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

@lru_cache
def get_settings() -> Settings:
    return Settings()

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        yield session
```

### Structure — séparation des responsabilités
```
apps/api/
  main.py           ← App FastAPI, lifespan, include_router
  routers/          ← Routes uniquement, pas de logique métier
    users.py
    products.py
  services/         ← Logique métier (fonctions pures async)
    user_service.py
  repositories/     ← Accès DB (SQLAlchemy async)
    user_repo.py
  models/           ← SQLAlchemy ORM models
    user.py
  schemas/          ← Pydantic schemas (request/response)
    user.py
  dependencies/     ← Dépendances FastAPI (auth, db, settings)
    auth.py
    database.py
```

**Règle** : les routes ne font qu'appeler des services. Zéro logique métier dans `routers/`.

```python
# ✅ Correct — router délègue au service
@router.post("/users", status_code=201)
async def create_user(
    payload: UserCreate,
    service: UserService = Depends(get_user_service),
) -> UserResponse:
    return await service.create(payload)

# ❌ Interdit — logique métier dans la route
@router.post("/users", status_code=201)
async def create_user(payload: UserCreate, db: AsyncSession = Depends(get_db)) -> UserResponse:
    existing = await db.execute(select(User).where(User.email == payload.email))
    if existing.scalar():
        raise HTTPException(400, "Email already used")
    user = User(**payload.model_dump())
    db.add(user)
    await db.commit()
    return UserResponse.model_validate(user)
```

### Tests (pytest + httpx)
```python
# Utiliser AsyncClient avec ASGITransport — pas de serveur réel
from httpx import ASGITransport, AsyncClient
from main import app

@pytest.mark.asyncio
async def test_create_user():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.post("/users", json={"email": "test@example.com", "name": "Test"})
    assert response.status_code == 201
```
- Mocks DB : utiliser une DB de test réelle (SQLite async ou Postgres de test)
- Pas de mock sur les repositories — tester l'intégration vraie
- Coverage minimum : 80%
