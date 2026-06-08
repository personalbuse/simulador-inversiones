---
name: python-backend
description: Python/FastAPI backend development with async SQLAlchemy, Pydantic v2, and security best practices. Use for backend tasks, API endpoints, DB models, migrations.
license: MIT
metadata:
  author: fiup
  version: "1.0"
---

# Python Backend — FastAPI + SQLAlchemy async

## Stack
- Python 3.12+, FastAPI 0.135, SQLAlchemy 2.0 async, PostgreSQL 16, Redis 7
- Auth: JWT (HS256) + bcrypt, 2FA with Resend
- External: Finnhub, ExchangeRate-API

## Conventions
- **Async siempre**: `async def`, `await`, `AsyncSession`
- **Auth**: `Depends(get_current_user)` valida `is_active` + `password_version`
- **Admin**: `require_admin` re-lee rol de DB, no del JWT
- **Rate limit**: `@limiter.limit("X/minute")` en endpoints públicos/admin
- **Transacciones**: `with_for_update()` al modificar User.balance o Portfolio
- **Pydantic v2**: `Field(..., min_length, max_length, pattern)`, `EmailStr`, `SecretStr`
- **Errores**: `HTTPException(status_code, detail)` en inglés, logs con `logger.warning/error`
- **Config**: `settings.X` de `app/core/config.py`, nunca hardcodear URLs/secretos

## Anti-patterns prohibidos
| ❌ No | ✅ Sí |
|---|---|
| Código bloqueante en endpoints | `async def` + `await` |
| Confiar en JWT claims para rol/is_active | Re-leer de DB en cada request |
| Loggear tokens/passwords/API keys | `logger.info` sin payload sensible |
| Hardcodear URLs o secrets | `settings.X` |

## Estructura
```
app/
├── api/v1/       # routers
├── core/         # config, security, rate_limiter
├── models/       # SQLAlchemy models
├── repositories/ # data access layer
├── schemas/      # Pydantic v2 schemas
├── services/     # business logic
└── db/           # session, connection
```

## Comandos
```bash
cd backend
ruff check .              # lint
mypy app/                 # type check
pytest -v                 # tests
alembic upgrade head      # migrations
uvicorn app.main:app --reload --port 8000
```
