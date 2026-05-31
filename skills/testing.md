# Skill — Testing

## Règle universelle

**Coverage minimum : 80%** (lignes, branches, fonctions, statements)
Bloquant en CI. Ne pas merger en dessous.

---

## Web — Jest + React Testing Library

### Configuration Jest (`apps/web/jest.config.ts`)
```typescript
import type { Config } from "jest";
import nextJest from "next/jest.js";

const createJestConfig = nextJest({ dir: "./" });

const config: Config = {
  testEnvironment: "jsdom",
  setupFilesAfterFramework: ["<rootDir>/jest.setup.ts"],
  coverageThreshold: {
    global: { lines: 80, branches: 80, functions: 80, statements: 80 },
  },
};

export default createJestConfig(config);
```

### Principes RTL
```typescript
// ✅ Tester le comportement utilisateur
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

test("submits form with valid data", async () => {
  const user = userEvent.setup();
  const onSubmit = jest.fn();
  render(<LoginForm onSubmit={onSubmit} />);

  await user.type(screen.getByLabelText(/email/i), "test@example.com");
  await user.type(screen.getByLabelText(/password/i), "secret123");
  await user.click(screen.getByRole("button", { name: /sign in/i }));

  expect(onSubmit).toHaveBeenCalledWith({ email: "test@example.com", password: "secret123" });
});

// ❌ Ne pas tester les détails d'implémentation
test("calls setState on input change", () => {
  const wrapper = shallow(<LoginForm />);
  wrapper.find("input").first().simulate("change", { target: { value: "test" } });
  expect(wrapper.state("email")).toBe("test"); // ← test d'implémentation, pas de comportement
});
```

### Mocks
- Mocker uniquement les appels externes (fetch, DB, services tiers)
- Utiliser `jest.mock()` au niveau module, pas au niveau test
- Réinitialiser avec `jest.clearAllMocks()` dans `beforeEach`

```typescript
// Mock fetch pour les Server Components
global.fetch = jest.fn(() =>
  Promise.resolve({ json: () => Promise.resolve([{ id: "1", name: "Product" }]) })
) as jest.Mock;
```

---

## API — pytest + httpx

### Configuration (`apps/api/pyproject.toml`)
```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]

[tool.coverage.report]
fail_under = 80
omit = ["tests/*"]
```

### Pattern standard
```python
import pytest
from httpx import ASGITransport, AsyncClient
from main import app

@pytest.mark.asyncio
async def test_create_user() -> None:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.post(
            "/users",
            json={"email": "test@example.com", "name": "Test User"},
        )
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "test@example.com"

# Test d'erreur
@pytest.mark.asyncio
async def test_create_user_duplicate_email() -> None:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/users", json={"email": "dup@example.com", "name": "First"})
        response = await client.post("/users", json={"email": "dup@example.com", "name": "Second"})
    assert response.status_code == 409
```

### Fixtures DB
```python
# conftest.py
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

TEST_DB_URL = "sqlite+aiosqlite:///:memory:"

@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    engine = create_async_engine(TEST_DB_URL)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with sessionmaker(engine, class_=AsyncSession)() as session:
        yield session
    await engine.dispose()
```

### Mocks pour services externes
```python
from unittest.mock import AsyncMock, patch

@pytest.mark.asyncio
async def test_send_notification() -> None:
    with patch("services.notification.send_push") as mock_send:
        mock_send.return_value = AsyncMock(return_value={"sent": True})
        # ... test
```

---

## Commandes CI

```bash
# Web
cd apps/web && npm run test:coverage

# API
cd apps/api && python -m pytest --cov=. --cov-report=term-missing --cov-fail-under=80

# Vérification rapide (sans coverage)
cd apps/web && npm test -- --passWithNoTests
cd apps/api && python -m pytest --tb=short
```
