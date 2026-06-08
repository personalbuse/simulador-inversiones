# FIF.md — Findings, Issues & Fixes Plan

> **Auditoría completa del proyecto Simulador de Inversiones FIUP**
> **Fecha**: 2026-06-06
> **Versión del proyecto auditado**: v2.0.0
> **Alcance**: Backend (FastAPI), Frontend (React 18), Docker, Tests, Configuración, CI/CD
> **Modo**: Read-only audit + plan de remediación

---

## 📊 Resumen ejecutivo

| Fase | Categoría | 🔴 Críticos | 🟠 Altos | 🟡 Medios | 🔵 Bajos | Total |
|:----:|-----------|:-----------:|:--------:|:---------:|:--------:|:-----:|
| **1** | 🔒 Seguridad | 12 | 18 | 14 | 8 | **52** |
| **2** | ⚡ Optimización | 4 | 11 | 13 | 6 | **34** |
| **3** | 🧑‍💻 Usabilidad | 6 | 14 | 16 | 9 | **45** |
| **4** | 🎨 Diseño y Responsividad | 3 | 11 | 9 | 6 | **29** |
| **5** | 🐛 Bugs y Duplicidad | 7 | 12 | 14 | 11 | **44** |
| | **TOTAL** | **32** | **66** | **66** | **40** | **204** |

> 🔴 = bloqueante · 🟠 = importante · 🟡 = mejora · 🔵 = nice-to-have

---

# 🗺️ Roadmap de implementación

| Orden | Fase | Esfuerzo | Dependencias | Sprint sugerido |
|:-----:|------|----------|--------------|-----------------|
| 1 | **Fase 1 — Seguridad** | 32-40h | Ninguna | Sprint 1 (URGENTE) |
| 2 | **Fase 5 — Bugs/Duplicidad** | 28-36h | Ninguna | Sprint 1-2 |
| 3 | **Fase 2 — Optimización** | 24-32h | Post-seguridad | Sprint 2 |
| 4 | **Fase 3 — Usabilidad** | 30-40h | Post-bugs | Sprint 3 |
| 5 | **Fase 4 — Diseño/Responsividad** | 20-28h | Post-usabilidad | Sprint 4 |

---

# 🔒 FASE 1 — SEGURIDAD (52 issues)

> **Prioridad**: URGENTE. Incluye secretos reales commiteados, bypass de auth, y vulnerabilidades explotables.

## 🔴 1.1 Secretos reales commiteados en `.env` (BLOQUEANTE)

- **Archivos**: `/.env:1-30`, `backend/.env:1-14`, `backend/.env.production`
- **Hallazgo**: API keys reales de Finnhub (`d812j2pr01qler4...`), Resend (`re_EevK7Y...`), ExchangeRate (`51554dd7...`), password real de NeonDB (`npg_Iu5BGaKX1Ytp`), JWT SECRET_KEY real. Commiteados al repo.
- **Impacto**: cualquiera con acceso al repo puede usar las API keys (facturación), resetear la DB de producción, falsificar JWTs.
- **Fix**:
  ```bash
  # 1. Rotar TODAS las credenciales en los proveedores
  # 2. Remover del repo
  git rm --cached .env backend/.env
  echo ".env" >> .gitignore
  echo "backend/.env" >> .gitignore
  echo "backend/.env.production" >> backend/.gitignore
  echo "frontend/.env.production" >> frontend/.gitignore
  # 3. Purgar del historial
  pip install git-filter-repo
  git filter-repo --invert-paths --path .env --path backend/.env
  git push origin --force --all
  # 4. Añadir .env.example solo con placeholders detectables
  ```

## 🔴 1.2 `backend/.env.production` no está en `.gitignore`

- **Archivo**: `backend/.gitignore:116`
- **Hallazgo**: Solo `.env` está ignorado; `.env.production` puede commitearse con secretos reales.
- **Fix**: Cambiar línea 116 a `.env\n.env.*\n!.env.example`.

## 🔴 1.3 Endpoints 2FA sin autenticación (CRÍTICO)

- **Archivo**: `app/api/v1/authentication.py:348-447`
- **Hallazgo**: `POST /send-verification-code` y `POST /verify-code` no tienen `Depends(oauth2_scheme)`. Permite email bombing y enumeration de cuentas registradas (404 si no existe vs 200 si existe).
- **Fix**:
  ```python
  @router.post("/send-verification-code")
  @limiter.limit("3/minute")
  async def send_verification_code(
      request: Request,
      payload: EmailSchema,
      current_user: User = Depends(get_current_user_optional),  # opcional
  ):
      # Mensaje genérico siempre
      return {"message": "If the email exists, a code has been sent"}
  ```

## 🔴 1.4 Bypass de rate limit via spoofing de IP

- **Archivo**: `app/core/rate_limiter.py:10-14`
- **Hallazgo**: `get_client_ip` confía ciegamente en `X-Forwarded-For`. Un atacante con botnet evade todos los rate limits.
- **Fix**:
  ```python
  def get_client_ip(request: Request) -> str:
      # Solo confiar en headers si la app está detrás de un proxy conocido
      if settings.TRUST_PROXY:
          forwarded = request.headers.get("X-Forwarded-For")
          if forwarded and request.headers.get("X-Real-IP"):
              return forwarded.split(",")[0].strip()
      return request.client.host
  ```
  Configurar nginx para enviar `X-Real-IP` y `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for`.

## 🔴 1.5 `is_active=False` no impide comprar/vender (CRÍTICO)

- **Archivo**: `app/api/v1/portfolio.py:40-54, 115, 200`
- **Hallazgo**: `get_current_username` solo decodifica JWT sin verificar `is_active`. Un usuario baneado puede seguir operando durante 30 min (vida del token).
- **Fix**:
  ```python
  # Reemplazar Depends(get_current_username) por:
  async def buy(...,
      current_user: User = Depends(get_current_user),  # verifica is_active
  ):
  ```
  Y verificar en `auth_service.py:86` que `is_active` se chequee contra DB fresca, no solo JWT.

## 🔴 1.6 Race condition en `buy`/`sell`

- **Archivo**: `app/api/v1/portfolio.py:106-188`
- **Hallazgo**: El precio se obtiene de Finnhub ANTES del `db.begin()`. Entre ese fetch y la validación `total_cost > balance`, otro request concurrente puede dejar saldo negativo.
- **Fix**:
  ```python
  async with db.begin():
      # Lock user row + portfolio row at once
      user = await db.execute(
          select(User).where(User.id == current_user.id).with_for_update()
      )
      portfolio = await db.execute(
          select(Portfolio).where(...).with_for_update()
      )
      # Re-fetch price INSIDE the transaction
      current_price = await get_stock_price(symbol)
      if current_price is None:
          raise HTTPException(503, "Price feed unavailable")
  ```

## 🔴 1.7 Validación de admin solo por claim `rol` en JWT

- **Archivo**: `app/api/v1/admin.py:22-50, 244-266, 598-626`
- **Hallazgo**: `require_admin` confía en `payload.get("rol") == "admin"`. Si un admin es degradado, su JWT sigue siendo válido 30 min. `adjust_balance` puede vaciar cuentas (`new_balance=0`) sin auditoría.
- **Fix**:
  ```python
  async def require_admin(current_user: User = Depends(get_current_user), db = Depends(get_db)):
      # Re-leer rol fresco de DB
      fresh = await db.execute(select(User).where(User.id == current_user.id))
      user = fresh.scalar_one()
      if user.rol != "admin" or not user.is_active:
          raise HTTPException(403, "Admin privileges required")
      return user
  ```
  Cambiar `BalanceRequest` a aceptar `delta: float` (positivo/negativo) con `reason: str` obligatorio. Registrar IP.

## 🔴 1.8 `SECRET_KEY` sin validación de longitud

- **Archivo**: `app/core/config.py:13, 36`
- **Hallazgo**: Acepta cualquier string. `.env.example` tiene `super_secret_key_change_in_production`. Si no se rota, JWTs falsificables.
- **Fix**:
  ```python
  SECRET_KEY: str = Field(..., min_length=64)
  # Validar en startup que no sea el default
  if settings.SECRET_KEY == "super_secret_key_change_in_production":
      raise RuntimeError("SECRET_KEY must be changed in production")
  ```

## 🔴 1.9 `on_event` deprecado en FastAPI 0.135

- **Archivo**: `app/main.py:159-179`
- **Hallazgo**: `app.on_event("startup")` deprecado desde 0.93. Sin try/except global, app puede arrancar en estado inconsistente.
- **Fix**:
  ```python
  from contextlib import asynccontextmanager

  @asynccontextmanager
  async def lifespan(app: FastAPI):
      # startup
      logger.info("Starting...")
      yield
      # shutdown
      await close_redis_client()
      scheduler.shutdown()
  app = FastAPI(lifespan=lifespan, ...)
  ```

## 🔴 1.10 `CORS_ORIGINS="*"` por defecto

- **Archivo**: `app/core/config.py:23`
- **Fix**: Default explícito `""`. Documentar lista blanca requerida en producción.

## 🟠 1.11 JWT sin `iat`, `aud`, `iss`, `jti`

- **Archivo**: `app/services/auth_service.py:37-49`
- **Hallazgo**: Solo incluye `exp`. No hay forma de revocar tokens. Reutilizable entre apps.
- **Fix**:
  ```python
  payload = {
      "sub": username,
      "iat": now,
      "nbf": now,
      "exp": now + timedelta(minutes=15),  # reducir vida
      "aud": settings.JWT_AUDIENCE,
      "iss": settings.JWT_ISSUER,
      "jti": secrets.token_urlsafe(16),
      "password_version": user.password_version,
  }
  ```
  Y validar `aud`, `iss`, `password_version` en `decode`. Reducir `ACCESS_TOKEN_EXPIRE_MINUTES` a 15 + refresh token.

## 🟠 1.12 Username sin lowercase enforced

- **Archivo**: `app/services/auth_service.py:79-87`, `app/schemas/user.py:25-35`
- **Hallazgo**: Postgres distingue `Admin` vs `admin`. Squatting de identidad visual.
- **Fix**:
  ```python
  # En UserCreate
  @field_validator("username")
  @classmethod
  def lower_username(cls, v: str) -> str:
      return v.lower()
  ```
  Añadir `CheckConstraint("username = lower(username)")` en el modelo.

## 🟠 1.13 Email validation débil

- **Archivo**: `app/schemas/user.py:27`
- **Hallazgo**: Patrón `r'^[\w\.-]+@[\w\.-]+\.\w+$'` permite `a@b.c`. Registro masivo con emails fake.
- **Fix**: Usar `pydantic.EmailStr` y opcionalmente validar contra disposable email list (e.g. `disposable-email-domains`).

## 🟠 1.14 `UserCreate.username` sin patrón estricto

- **Archivo**: `app/schemas/user.py:25`
- **Fix**: `pattern=r'^[a-z0-9_.-]{3,50}$'`.

## 🟠 1.15 Password reset no invalida tokens existentes

- **Archivo**: `app/api/v1/authentication.py:254-290`
- **Hallazgo**: Tras `reset-password`, los tokens JWT emitidos antes siguen válidos 30 min. Un atacante que robó sesión puede seguir usándola.
- **Fix**:
  ```python
  # En User model añadir password_version: int = 0
  # En reset-password:
  user.password_version += 1
  # En JWT payload incluir password_version
  # En get_current_user validar que coincida
  ```

## 🟠 1.16 `adjust_balance` puede vaciar cuentas

- **Archivo**: `app/api/v1/admin.py:244-266`
- **Fix**: Cambiar a `BalanceAdjustmentRequest(delta: float, reason: str)`. Registrar IP, admin_id, before/after en `admin_logs`.

## 🟠 1.17 Maintenance toggle sin 2FA

- **Archivo**: `app/api/v1/admin.py:598-626`
- **Fix**: Requerir código 2FA de admin. Rate limit `1/hora`. Log estructurado con `severity=critical`.

## 🟠 1.18 `suspicious-transactions` división por cero

- **Archivo**: `app/api/v1/admin.py:451-502`
- **Hallazgo**: `(User.current_balance / User.initial_balance).desc()` sin filtro `initial_balance > 0` → 500 si admin ajustó a 0.
- **Fix**:
  ```python
  stmt = select(User).where(User.initial_balance > 0).order_by(
      (User.current_balance / User.initial_balance).desc()
  )
  ```

## 🟠 1.19 `list_users` sin max limit

- **Archivo**: `app/api/v1/admin.py:106-131`
- **Fix**: `limit: int = Query(50, ge=1, le=200)`.

## 🟠 1.20 `flushdb` borra toda Redis

- **Archivo**: `app/api/v1/admin.py:683-702`
- **Fix**: Usar prefijo dedicado `simulador:*` con `SCAN MATCH`:
  ```python
  async for key in redis.scan_iter(match="simulador:*"):
      await redis.delete(key)
  ```

## 🟠 1.21 Dockerfile backend corre como root

- **Archivo**: `backend/Dockerfile:1-16`
- **Fix**:
  ```dockerfile
  RUN groupadd -r appuser && useradd -r -g appuser -u 1000 appuser
  USER appuser
  ```

## 🟠 1.22 `PyJWT[crypto]` instala `ecdsa` y `rsa` con CVEs

- **Archivo**: `backend/requirements.txt:13, 41`
- **Fix**: Cambiar a `PyJWT` sin extras. Solo se usa HS256.

## 🟠 1.23 CSP con `'unsafe-inline'` en scripts

- **Archivo**: `nginx/includes/security.conf:9`
- **Hallazgo**: `script-src 'self' 'unsafe-inline' https://static.cloudflareinsights.com`. Anula defensa XSS de CSP.
- **Fix**: Usar nonces generados por backend o eliminar `'unsafe-inline'` y mover scripts inline a archivos externos.

## 🟠 1.24 nginx.conf activo sin rate limit

- **Archivo**: `nginx/nginx.conf:1-7` (canónico)
- **Hallazgo**: Solo `nginx_backup.conf:18-19` tiene `limit_req_zone`. El canónico es más débil.
- **Fix**: Mover zonas de rate limit de backup a canónico, o consolidar ambos archivos.

## 🟠 1.25 Token en localStorage (XSS-vulnerable)

- **Archivo**: `frontend/src/services/api.ts:13`
- **Fix**: Migrar a cookies `httpOnly` + `SameSite=Strict` (gestionado por backend en set-cookie) o usar `sessionStorage` como mínimo.

## 🟠 1.26 Sentry/Datadog/LogRocket no integrado

- **Archivo**: `frontend/src/components/ErrorBoundary.tsx:23`
- **Fix**: Integrar `@sentry/react` o `bugsnag` con source maps.

## 🟠 1.27 `vite.config.ts:18` sourcemaps en producción

- **Archivo**: `frontend/vite.config.ts:18`
- **Fix**: `sourcemap: mode === 'production' ? 'hidden' : true`.

## 🟠 1.28 HTTPS no forzado en código (delegado a nginx)

- **Archivo**: `app/core/config.py`
- **Fix**: Añadir middleware que redirija HTTP→HTTPS en producción si no se hace en nginx.

## 🟡 1.29 Secrets en logs por accidente

- **Archivos**: múltiples en `app/services/`
- **Fix**: Usar `pydantic.SecretStr` para `FINNHUB_API_KEY`, `RESEND_API_KEY`, `EXCHANGE_RATE_API_KEY`.

## 🟡 1.30 `currency` field sin validación ISO 4217

- **Archivo**: `app/schemas/portfolio.py`
- **Fix**: `pattern=r'^[A-Z]{3}$'`.

## 🟡 1.31 Falta índice compuesto en `transactions`

- **Archivo**: `app/models/base.py:45-58`
- **Fix**: `Index('ix_transactions_user_created', 'user_id', 'created_at.desc())`.

## 🟡 1.32 Sin rate limit en `/complete-module` (farming de dinero)

- **Archivo**: `app/api/v1/learning.py:30-48`
- **Fix**: Crear tabla `completed_modules(user_id, module_id, completed_at)` con `unique(user_id, module_id)`. Verificar antes de sumar.

## 🟡 1.33 Sin rate limit en `/leaderboard`, `/admin/*`, `/stocks/international`

- **Archivos**: varios
- **Fix**: Aplicar `@limiter.limit("30/minute")` o `"60/minute"` según costo.

## 🟡 1.34 Mock data devuelto silenciosamente sin avisar

- **Archivo**: `app/api/v1/stocks.py:113-118`
- **Fix**: Campo `data_source: Literal["live", "cached", "mock"]` en respuesta. Banner en UI si es mock.

## 🟡 1.35 `/stocks/batch` sin auth (scraping)

- **Archivo**: `app/api/v1/stocks.py:86-133`
- **Fix**: Requerir auth o rate limit estricto por IP autenticada.

## 🟡 1.36 `headers` allowlist limitado

- **Archivo**: `app/main.py:63`
- **Fix**: Añadir `X-Requested-With`, `Accept-Language` a `allow_headers`.

## 🟡 1.37 `mimetype` no validado en uploads (PDF reports)

- **Archivo**: `app/services/pdf_report_service.py`
- **Fix**: Validar `Content-Type: application/pdf` en generación.

## 🟡 1.38 `world_indices` MOCK con datos viejos

- **Archivo**: `app/services/world_indices_service.py:44-66`
- **Fix**: Marcar `data_source: "mock"` y `as_of: "2024-XX-XX"`.

## 🟡 1.39 `news_service` MOCK con URLs Unsplash

- **Archivo**: `app/services/news_service.py:12-43`
- **Fix**: Mover imágenes a `public/images/` o `static/`. Marcar como mock.

## 🟡 1.40 Security headers faltantes en FastAPI

- **Archivo**: `app/main.py:1-214`
- **Fix**: Middleware custom que añada:
  ```
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), microphone=(), camera=()
  ```

## 🟡 1.41 Mantenimiento bypass para TODAS las rutas admin

- **Archivo**: `app/main.py:68-88`
- **Fix**: Bypass solo para `/admin/maintenance` mismo. Resto recibe 503.

## 🟡 1.42 Cache leaderboard en proceso (no compartido entre workers)

- **Archivo**: `app/repositories/leaderboard_repository.py:11-36`
- **Fix**: Usar Redis en lugar de dict en memoria.

## 🟡 1.43 Connection pool sin `pool_timeout`

- **Archivo**: `app/db/session.py:10-18`
- **Fix**: `pool_timeout=10` + manejar `TimeoutError` con HTTPException 503.

## 🟡 1.44 `initial_balance=10000.00` hardcoded

- **Archivo**: `app/api/v1/authentication.py:121-122`
- **Fix**: Leer de `SystemConfig.initial_balance`.

## 🟡 1.45 `pdf_report_service` usa `get_event_loop()` deprecado

- **Archivo**: `app/services/pdf_report_service.py:194-197`
- **Fix**: `asyncio.get_running_loop()` o `asyncio.to_thread()`.

## 🟡 1.46 `/health` expone estado interno

- **Archivo**: `app/main.py:140-157`
- **Fix**: `/health` público solo `{"status":"ok"}`; `/health/detailed` con auth para ops.

## 🟡 1.47 `validate_api_keys` solo imprime warnings

- **Archivo**: `app/core/api_keys.py:11-19`
- **Fix**: `logger.warning` + exponer en `/health` flag `missing_keys: bool`.

## 🟡 1.48 `Maintenance mode` no persiste en restart

- **Archivo**: `app/api/v1/admin.py:598-626`, `app/main.py:171`
- **Fix**: Fail-closed: si no se puede leer el estado, asumir `True`.

## 🔵 1.49-1.52 (4 issues bajos) — ver reporte extendido

- Headers allowlist mínimo
- `version` expuesta en `/`
- `Mako` formatter en error messages
- `bcrypt` deprecation warning con rounds explícitos

---

# ⚡ FASE 2 — OPTIMIZACIÓN (34 issues)

> **Objetivo**: mejorar performance, reducir bundle, optimizar queries, cachear inteligentemente.

## 🔴 2.1 Cobertura de tests < 5%

- **Archivo**: `backend/tests/test_api.py` (29 tests, solo auth 401/422)
- **Fix**: Mapear 59 endpoints. Mínimo: register flow, login happy path, buy/sell, exchange rate cache, leaderboard, rate-limit, maintenance, IDOR, mass assignment. Objetivo: 60% cobertura.

## 🔴 2.2 Sin tests frontend (Playwright/Vitest/Jest)

- **Archivo**: `frontend/package.json` (sin deps de testing)
- **Fix**: Agregar `vitest@^2`, `@testing-library/react@^16`, `@playwright/test@^1.48`. Configurar `vitest.config.ts` con `environment: 'jsdom'`.

## 🔴 2.3 `find . -name __pycache__` en repo

- **Archivo**: 12+ directorios
- **Fix**: `find . -type d -name __pycache__ -exec rm -rf {} +` y verificar `.gitignore`.

## 🔴 2.4 Sin `requirements-dev.txt` separado

- **Archivo**: `backend/requirements.txt:34-35`
- **Fix**: Crear `requirements-dev.txt` con `pytest`, `pytest-asyncio`, `pytest-cov`, `httpx`, `freezegun`, `faker`, `ruff`, `mypy`.

## 🟠 2.5 i18n bundle grande (traducciones estáticas)

- **Archivo**: `frontend/src/i18n.ts:5-6, 17-20`
- **Fix**: Migrar a `i18next-http-backend` (ya en deps) con `/locales/{{lng}}.json` lazy-loaded.

## 🟠 2.6 `manualChunks` solo para recharts

- **Archivo**: `frontend/vite.config.ts:21-23`
- **Fix**:
  ```ts
  manualChunks: {
    recharts: ['recharts'],
    i18n: ['i18next', 'react-i18next', 'i18next-browser-languagedetector'],
    router: ['react-router-dom'],
    forms: ['zod', 'react-hook-form'],
  }
  ```

## 🟠 2.7 `Dashboard.tsx:25-53` `Math.random()` en cada render

- **Archivo**: `frontend/src/pages/Dashboard.tsx`
- **Fix**: `useMemo(() => getMockExchangeRates(), [])` + flag `__DEV__` para mostrar warning.

## 🟠 2.8 `Transactions.tsx:43-74` sort no memoizado

- **Archivo**: `frontend/src/pages/transactions/Transactions.tsx`
- **Fix**: `useMemo(() => [...].sort(...), [transactions, sortField, sortDirection])` + virtualización con `react-window`.

## 🟠 2.9 `Portfolio.tsx:93-104` fetchPortfolio sin await en handleSell

- **Archivo**: `frontend/src/pages/portfolio/Portfolio.tsx:55`
- **Fix**: `await fetchPortfolio()` + deshabilitar botón hasta completar.

## 🟠 2.10 Sin `useCallback` en handlers de tablas

- **Archivos**: `Transactions.tsx`, `Portfolio.tsx`, `Admin.tsx`
- **Fix**: Envolver en `useCallback` con deps correctas. Usar `React.memo` en filas.

## 🟠 2.11 Sin virtualización en listas largas

- **Archivos**: `Transactions`, `Portfolio`, `Admin users`
- **Fix**: Instalar `react-window@^1.8` y aplicar en listas con >50 items.

## 🟠 2.12 Sin retry en fallos transitorios de API

- **Archivo**: `frontend/src/services/api.ts:5-10`
- **Fix**: Instalar `axios-retry` con backoff exponencial. Solo para GET idempotentes.

## 🟠 2.13 `Forex.tsx:176-179` `Math.min(...arr)` stack overflow

- **Archivo**: `frontend/src/pages/forex/Forex.tsx`
- **Fix**: `arr.reduce((m, h) => h.rate < m ? h.rate : m, Infinity)`.

## 🟠 2.14 Sin `AbortController` en fetches

- **Archivos**: `Dashboard.tsx`, `Markets.tsx`, `Forex.tsx`, `Stocks.tsx`
- **Fix**: Pasar `signal: abortController.signal` en cada axios call. Cleanup en `useEffect`.

## 🟠 2.15 Service Worker cachea POST/responses sensibles

- **Archivo**: `frontend/public/sw.js:30-48`
- **Fix**: Excluir `/api/` del cache: `if (event.request.url.includes('/api/')) return;`.

## 🟠 2.16 Backend Dockerfile no multi-stage

- **Archivo**: `backend/Dockerfile:1-16`
- **Fix**: Stage builder con `gcc libpq-dev`, stage runtime con solo `libpq5`. Reduce imagen ~300MB.

## 🟠 2.17 nginx sin `proxy_cache` para `/assets/`

- **Archivo**: `nginx/nginx.conf:31-39`
- **Fix**: Definir `proxy_cache static_cache;` con `proxy_cache_valid 200 60m;` (ya está en backup).

## 🟠 2.18 Recálculo de `theorySections` en cada render

- **Archivo**: `frontend/src/pages/learn/LessonDetail.tsx:89`
- **Fix**: `useMemo(() => getTheorySections(t), [t, id])`.

## 🟡 2.19-2.30 (12 issues medios)

- `Dashboard.tsx:421-457` imágenes sin `srcset` ni aspect ratio (CLS).
- `ExchangeRatesChart.tsx:16` no memoizado.
- Sin `font-display: swap` override.
- Sin service worker strategy distinta por tipo de recurso.
- Sin preload de fonts críticas.
- Sin `<link rel="preconnect">` para backend.
- `recharts` carga en Dashboard y Portfolio por separado (memoizar datos).
- `repositories/leaderboard_repository.py:38-86` sin LIMIT → carga todos los users.
- `services/finnhub_service.py` sin circuit breaker.
- `Dockerfile` sin `--require-hashes` ni `pip-compile` lock.
- `docker-compose.yml` sin `deploy.resources.limits`.
- `setup.bat:7-24` instala paquetes obsoletos.

## 🔵 2.31-2.34 (4 issues bajos)

- `tailwind.config.js:84-85` mixto CommonJS/ESM.
- `tsconfig.node.json` no procesa `tailwind.config.js`.
- `package.json` sin `engines` field.
- `alembic.ini:34` URL hardcoded (aunque se sobreescribe).

---

# 🧑‍💻 FASE 3 — USABILIDAD (45 issues)

> **Objetivo**: mejorar experiencia de usuario, accesibilidad, feedback, estados de UI.

## 🔴 3.1 Cero atributos de accesibilidad (ARIA)

- **Archivos**: TODA la app
- **Hallazgo**: Búsqueda `aria-|role=` → 0 resultados. WCAG AA no se cumple.
- **Fix sistemático**:
  - Botones: `aria-label` o texto visible.
  - Inputs: `<label htmlFor>` o `aria-label`, `aria-describedby` para errores.
  - Errores: `role="alert"` en mensajes.
  - Modales: `role="dialog"`, `aria-modal="true"`, `aria-labelledby`, focus trap, cierre con `Escape`.
  - Loading: `role="status"`, `aria-live="polite"`, `aria-busy="true"`.
  - Imágenes: `alt` siempre (decorativas: `alt=""`).

## 🔴 3.2 Doble persistencia de auth (Zustand + localStorage manual)

- **Archivos**: `useStore.ts:25-72`, `AuthProvider.tsx:26-34`, `api.ts:13`
- **Fix**: Centralizar en Zustand `persist` con `partialize: (s) => ({ user: s.user, token: s.token })`. Eliminar todas las llamadas manuales a `localStorage.getItem('user'|'token')`.

## 🔴 3.3 Race condition en hidratación de Zustand

- **Archivos**: `useStore.ts:44-57`, `AuthProvider.tsx:20-23`
- **Fix**: Usar `onRehydrateStorage` callback para controlar el flag `loading`:
  ```ts
  persist(..., {
    onRehydrateStorage: () => (state) => {
      state?.setLoading(false);
    }
  })
  ```

## 🔴 3.4 `401` causa hard reload con `window.location.href`

- **Archivo**: `frontend/src/services/api.ts:23-29`
- **Fix**:
  ```ts
  api.interceptors.response.use(
    (r) => r,
    (err) => {
      if (err.response?.status === 401) {
        window.dispatchEvent(new CustomEvent('auth:expired'));
      }
      return Promise.reject(err);
    }
  );
  // En AuthProvider:
  useEffect(() => {
    const handler = () => navigate('/login', { replace: true });
    window.addEventListener('auth:expired', handler);
    return () => window.removeEventListener('auth:expired', handler);
  }, []);
  ```

## 🔴 3.5 Memory leak en `GuidedTour.tsx:49-53`

- **Archivo**: `frontend/src/components/GuidedTour.tsx`
- **Hallazgo**: `addEventListener('resize', ...)` SIN cleanup en cada render → N listeners acumulados.
- **Fix**:
  ```tsx
  useEffect(() => {
    const handler = () => setIsMobile(window.innerWidth < 640);
    window.addEventListener('resize', handler);
    return () => window.removeEventListener('resize', handler);
  }, []);
  ```

## 🔴 3.6 Lógica de quiz rota con i18n

- **Archivo**: `frontend/src/pages/learn/LessonDetail.tsx:42`
- **Hallazgo**: `selectedOption === t(\`learn.modules.${id}.quiz.a\`)` compara string traducido contra selección. Si traducción cambia ("1" → "uno"), siempre falla.
- **Fix**:
  ```ts
  const correct = selectedOption === '1';  // Comparar índice, traducir al renderizar
  ```

## 🔴 3.7 `Admin.tsx:138-149` usa `fetch` en vez de `api` instance

- **Archivo**: `frontend/src/pages/admin/Admin.tsx`
- **Fix**: Importar `api` de `services/api.ts`. Parsear `res.json()` con try/catch y extraer `detail`.

## 🟠 3.8 `8+` `window.location.href` rompen SPA

- **Archivos**: `Login.tsx:96, 124`, `Register.tsx:319`, `ForgotPassword.tsx:95`, `ResetPassword.tsx:98, 214`, etc.
- **Fix**: Reemplazar por `useNavigate()` o `<Link to>` en todos.

## 🟠 3.9 Sin timeout en axios + sin retry

- **Archivo**: `frontend/src/services/api.ts:5-10`
- **Fix**: `timeout: 10000`, `axios-retry` con backoff.

## 🟠 3.10 Sin `useDebounce` en búsqueda de Stocks

- **Archivo**: `frontend/src/pages/stocks/Stocks.tsx:122-135`
- **Fix**: `useDebounce(searchTerm, 300)` (extraer hook a `src/hooks/useDebounce.ts`).

## 🟠 3.11 Sin manejo de errores centralizado

- **14+ `try/catch` con console.error y toast**
- **Fix**: Interceptor en `api.ts` que mapea errores a mensajes i18n. Hook `useApi<T>()` que retorna `{ data, error, loading, refetch }`.

## 🟠 3.12 Formularios sin validación con zod

- **Archivos**: `Register.tsx:36-43`, `ResetPassword.tsx`, `Login.tsx`
- **Fix**: Schema en `src/utils/validators.ts`:
  ```ts
  export const passwordSchema = z.string()
    .min(12, 'Min 12 chars')
    .regex(/[A-Z]/, 'At least 1 uppercase')
    .regex(/[a-z]/, 'At least 1 lowercase')
    .regex(/[0-9]/, 'At least 1 digit')
    .regex(/[^A-Za-z0-9]/, 'At least 1 symbol');
  ```

## 🟠 3.13 FOUC en dark mode

- **Archivo**: `frontend/src/provider/ThemeProvider.tsx:12-21`
- **Fix**: Script inline en `index.html` ANTES de React:
  ```html
  <script>
    (function() {
      const dark = localStorage.getItem('theme') === 'dark';
      if (dark) document.documentElement.classList.add('dark');
    })();
  </script>
  ```

## 🟠 3.14 `LanguageProvider` no actualiza `document.documentElement.lang`

- **Archivo**: `frontend/src/provider/LanguageProvider.tsx`
- **Fix**: En `changeLanguage`: `document.documentElement.lang = lng;`.

## 🟠 3.15 Sin `aria-current="step"` ni `aria-live` en reset password

- **Archivo**: `frontend/src/pages/ResetPassword.tsx`
- **Fix**: Añadir `aria-live="polite"` al mensaje de éxito.

## 🟠 3.16 21+ strings hardcoded en español (no usan i18n)

- **Archivos**: `Header.tsx`, `Leaderboard.tsx`, `Forex.tsx`, `LessonDetail.tsx`, `Admin.tsx`, `Dashboard.tsx`, `GuidedTour.tsx`, `Stocks.tsx`, `Register.tsx`, `ResetPassword.tsx`, `ErrorBoundary.tsx`
- **Fix**: Mover cada string a `locales/es.json` y `locales/en.json`. Usar `t('namespace.key')` consistentemente.

## 🟠 3.17 Modales admin sin `role="dialog"` ni Escape

- **Archivo**: `frontend/src/pages/admin/Admin.tsx:936, 988, 1019`
- **Fix**: Usar `<dialog>` nativo o componente `<Modal>` reutilizable con roles + Escape.

## 🟠 3.18 Sin loading skeletons diferenciados

- **Archivos**: `Dashboard.tsx`, `Portfolio.tsx`, `Transactions.tsx`
- **Fix**: Skeletons específicos por sección (no spinner global).

## 🟠 3.19 `Profile.tsx:90-95` confunde theme toggle con logout

- **Fix**: Separar visualmente. El div con `onClick={toggleTheme}` debe ser `<button>`.

## 🟠 3.20 `Dashboard.tsx:206, 220, 234, 260` 3 stat-cards engañosas

- **Hallazgo**: "Balance", "Cash Balance", "Total Profit" → todas navegan a `/portfolio`.
- **Fix**: Solo "Portfolio Value" y "Total Profit" navegan; resto muestra tooltip o detalle inline.

## 🟠 3.21 `LessonDetail.tsx` sin check de token mount

- **Archivo**: `frontend/src/pages/learn/LessonDetail.tsx:80-83`
- **Fix**: Cleanup del `setTimeout` en `useEffect`.

## 🟠 3.22 `Login.tsx:38` mensaje genérico para 401 y 500

- **Fix**: Distinguir 401 (credenciales) vs 500/network (servidor).

## 🟠 3.23 Sin feedback visual al pegar código 2FA > 6 dígitos

- **Archivo**: `Register.tsx:284`
- **Fix**: `aria-describedby` con ayuda + `aria-invalid` si longitud > 6.

## 🟠 3.24 `Learning.modules` hardcoded con `id: 'm1'..'m6'`

- **Archivos**: `Learn.tsx:8-15`, `LessonDetail.tsx:25-39`
- **Fix**: Cargar módulos del backend o de un config JSON.

## 🟠 3.25 `getTheorySections` con heurística frágil

- **Archivo**: `LessonDetail.tsx:67-87`
- **Fix**: Usar `react-markdown` o JSON estructurado desde backend.

## 🟠 3.26 `ResetPassword.tsx:9` `searchParams.get('token')` sin `decodeURIComponent`

- **Fix**: `decodeURIComponent(searchParams.get('token') || '')`.

## 🟠 3.27 `JSON.parse(localStorage.getItem('user'))` sin try/catch

- **Archivos**: `Stocks.tsx:93-95`, `Profile.tsx:13`, `LessonDetail.tsx:54-57`
- **Fix**: Migrar a Zustand (3.2) o `try { ... } catch { return null; }`.

## 🟠 3.28 `Admin.tsx:412-431` mobile tabs con scroll horizontal

- **Fix**: Drawer/hamburger o agrupar en dropdowns.

## 🟠 3.29 `Admin.tsx:677` paginación rompe regla de hooks

- **Fix**: `useCallback` con deps correctas.

## 🟠 3.30 `Dashboard.tsx:419` empty state sin acción

- **Fix**: Añadir botón "Recargar" o "Ver más tarde".

## 🟠 3.31 `Transactions.tsx:155-166` empty state sin CTA

- **Fix**: Botón "Ir a comprar".

## 🟠 3.32 `Admin.tsx:880-893` emoji 🟢 sin aria-label

- **Fix**: `<span role="img" aria-label="Sistema activado">🟢</span>`.

## 🟠 3.33 `Header.tsx:71-85, 87-92, 96-100` icon buttons sin aria-label

- **Fix**: `aria-label="Cambiar tema"`, `aria-label="Cambiar idioma a inglés"`, `aria-label="Cerrar sesión"`.

## 🟠 3.34 `OnboardingModal` no se usa (dead code)

- **Archivo**: `frontend/src/components/OnboardingModal.tsx`
- **Fix**: Eliminar o integrar en flujo de primer login.

## 🟠 3.35 `ErrorBoundary` sin recovery action

- **Archivo**: `frontend/src/components/ErrorBoundary.tsx:31-37`
- **Fix**: Botón "Reintentar" que reintenta la última acción sin recargar.

## 🟠 3.36 `Profile.tsx` no permite editar email/username/password

- **Fix**: Añadir formularios de edición con confirmación por email.

## 🟠 3.37 `Leaderboard.tsx:14-17` `catch(() => ...)` silencia errores

- **Fix**: `console.error` + toast.

## 🟠 3.38 `Leaderboard.tsx:113` `user.username.charAt(0)` sin null check

- **Fix**: `user?.username?.charAt(0).toUpperCase() ?? '?'`.

## 🟠 3.39 `Markets.tsx:49-60` race condition al cambiar región rápido

- **Fix**: `AbortController` + cleanup en `useEffect`.

## 🟠 3.40 `Forex.tsx:96` siempre muestra primer par

- **Fix**: Permitir seleccionar otro par de la tabla (chip clickeable).

## 🟠 3.41 `ResetPassword.tsx` no usa i18n (todo hardcoded en español)

- **Fix**: Mover todas las strings a `es.json` y `en.json`.

## 🟠 3.42 `Header.tsx:21` "Ranking" hardcoded

- **Fix**: `t('nav.leaderboard')`.

## 🟠 3.43 `Header.tsx:42` logo como `<div onClick>` no accesible

- **Fix**: `<Link to="/dashboard" aria-label="Ir al inicio">`.

## 🟠 3.44 `Footer.tsx` texto mezclando t() y hardcoded

- **Fix**: Mover todo a i18n.

## 🟠 3.45 `GuidedTour` textos no usan t()

- **Archivo**: `frontend/src/components/GuidedTour.tsx:6-42`
- **Fix**: Mover a `es.json` y `en.json` bajo `tour.step1.title`, etc.

## 🟡 3.46-3.55 (10 issues medios) — ver reporte extendido

- `Registration.tsx:73-78` mapeo inconsistente de errores.
- `Stocks.tsx:172-232` inputs sin aria-label.
- `OnboardingModal.tsx:51-55` resetea `currentStep` al reabrir.
- `Header.tsx:104-118` scroll horizontal en mobile.
- `LessonDetail.tsx:183-186` JSON.parse sin try/catch (duplicado).
- `Markets.tsx:104-122` emojis banderas pueden no renderizar en Windows.
- `Forex.tsx:75-83` cálculo de change puede dar NaN.
- `Transactions.tsx:113` `.toLowerCase()` sobre traducción.
- `Admin.tsx:226-229` useEffect con deps vacías.
- `PrivateRoute.tsx:19` fetch a `/health` no proxiado en dev.

---

# 🎨 FASE 4 — DISEÑO Y RESPONSIVIDAD (29 issues)

> **Objetivo**: layouts adaptativos, contraste, tipografía, jerarquía visual, mobile-first.

## 🔴 4.1 Contraste WCAG AA falla en textos `text-slate-400` sobre `bg-slate-50`

- **Archivo**: múltiples (`Dashboard.tsx`, `Portfolio.tsx`, etc.)
- **Hallazgo**: `text-slate-400` sobre `bg-slate-50` ≈ 3.2:1 (necesita 4.5:1).
- **Fix**: Usar `text-slate-500` mínimo para textos < 18px. `text-slate-400` solo para `text-base` o superior.

## 🔴 4.2 Header mobile con scroll horizontal

- **Archivo**: `frontend/src/components/layout/Header.tsx:104-118`
- **Hallazgo**: 10 botones con `whitespace-nowrap` → scroll horizontal inevitable en iPhone SE (320px).
- **Fix**: Hamburger menu o agrupar: Trading · Learn · Account.

## 🔴 4.3 `theme-color` hardcoded a negro

- **Archivo**: `frontend/index.html:9`
- **Fix**:
  ```html
  <meta name="theme-color" content="#f8fafc" media="(prefers-color-scheme: light)">
  <meta name="theme-color" content="#0f172a" media="(prefers-color-scheme: dark)">
  ```

## 🟠 4.4 Tablas sin colapso en mobile

- **Archivos**: `Admin.tsx:587-668`, `Portfolio.tsx:251-348`, `Transactions.tsx:128-198`, `Indices.tsx:111-176`, `Leaderboard.tsx:79-140`
- **Fix**: Layout de cards en mobile (`<sm:`), tabla en `sm:`+. Cada columna `hidden sm:table-cell` o accordion.

## 🟠 4.5 `Admin.tsx:412-431` mobile tabs con `overflow-x-auto`

- **Fix**: Drawer lateral o bottom sheet.

## 🟠 4.6 `Dashboard.tsx:339-368` pie chart sin leyenda visible

- **Fix**: Leyenda con `data.name` debajo, no solo colores en el chart.

## 🟠 4.7 `Stocks.tsx:172` grid rompe en `320px`

- **Fix**: `grid-cols-1 sm:grid-cols-2 lg:grid-cols-3` (sin `xl:grid-cols-4` para que no se vea estirado en mobile).

## 🟠 4.8 Sin breakpoint `xs` (320-640px)

- **Archivo**: `tailwind.config.js`
- **Fix**:
  ```js
  theme: {
    screens: {
      xs: '320px',
      sm: '640px',
      md: '768px',
      lg: '1024px',
      xl: '1280px',
    }
  }
  ```

## 🟠 4.9 `Dashboard.tsx:205-275` stat-cards apretadas en `xs`

- **Fix**: `p-2 xs:p-3 sm:p-4`, `text-[10px] xs:text-xs sm:text-base`.

## 🟠 4.10 `LessonDetail.tsx:108` contenido con `max-w-4xl` puede ser muy estrecho

- **Fix**: `max-w-prose` (~65ch) para texto, `max-w-4xl` para quizzes.

## 🟠 4.11 `Header.tsx:42` logo no responsive

- **Fix**: Ocultar texto "Stock Market" en `xs:`, mostrar solo logo en mobile.

## 🟠 4.12 `Header.tsx:87-92` botón idioma "ES/EN" confuso

- **Fix**: Mostrar ambos y destacar el activo, o usar 🌐 con aria-label.

## 🟠 4.13 `NotFound.tsx` doble `min-h-screen`

- **Archivo**: `frontend/src/pages/NotFound.tsx:8-9` + `App.tsx:51`
- **Fix**: `min-h-[60vh]` en NotFound.

## 🟠 4.14 `Footer.tsx` sin diseño responsive

- **Fix**: Grid `grid-cols-1 md:grid-cols-3` para columnas.

## 🟠 4.15 `Maintenance.tsx` no permite admin bypass

- **Fix**: Banner "Modo mantenimiento activo" con link admin si aplica.

## 🟠 4.16 `GuidedTour` mobile vs desktop duplica layout

- **Archivo**: `GuidedTour.tsx:106-170, 173-232`
- **Fix**: Extraer contenido, parametrizar posición por `isMobile`.

## 🟠 4.17 Sin loading skeleton específico por página

- **Fix**: Crear `<PageSkeleton variant="dashboard|portfolio|admin" />`.

## 🟠 4.18 `ExchangeRatesChart` altura fija `h-32`

- **Archivo**: `frontend/src/components/ExchangeRatesChart.tsx:61-104`
- **Fix**: `h-40 sm:h-48`.

## 🟠 4.19 Iconos sin tamaño consistente

- **Fix**: Definir tokens de tamaño: `icon-sm: 16px`, `icon-md: 20px`, `icon-lg: 24px`. Usar `lucide-react` con prop `size`.

## 🟠 4.20 `Markets.tsx:104-122` emojis banderas pueden no renderizar

- **Fix**: Usar `flag-icons` (`npm i flag-icons`) o mapping `country → SVG path`.

## 🟠 4.21 Sin dark mode consistente en componentes admin

- **Archivo**: `frontend/src/pages/admin/Admin.tsx`
- **Fix**: Audit visual de todos los `bg-white`, `text-black` hardcoded.

## 🟠 4.22 `OnboardingModal` backdrop con `bg-black/50` sin blur

- **Fix**: `backdrop-blur-sm` para profundidad.

## 🟠 4.23 `Dashboard.tsx:285-319` line chart con 1 punto confunde

- **Fix**: Mensaje "Necesitas al menos 2 puntos para ver la tendencia" o mostrar solo tabla.

## 🟠 4.24 `Transactions.tsx` colores de profit/pérdida no accesibles

- **Fix**: Verde `#16a34a` sobre blanco = 4.6:1 ✓, pero sobre `bg-slate-50` verificar.

## 🟡 4.25-4.29 (5 issues medios) — ver reporte extendido

- `Forex.tsx:127-185` columnas pueden ser muy estrechas en mobile.
- `Leaderboard.tsx:79-140` 4 columnas sin colapso.
- `Header.tsx:38` max-w-7xl pero inner items sin restricciones proporcionales.
- `tailwind.config.js` sin definir `fontFamily` custom.
- Falta definir `theme.extend.colors` para tokens semánticos (success, danger, warning).

---

# 🐛 FASE 5 — BUGS Y DUPLICIDAD (44 issues)

> **Objetivo**: corregir comportamiento roto, eliminar código duplicado, limpiar archivos muertos.

## 🔴 5.1 `nginx_backup.conf` duplica config canónica

- **Archivo**: `nginx/nginx_backup.conf` (107 líneas)
- **Hallazgo**: Contiene rate limiting, proxy cache, deny de archivos ocultos — features que el canónico `nginx.conf` no tiene.
- **Fix**:
  ```bash
  # Fusionar mejores partes en nginx.conf
  # Eliminar backup
  git rm nginx/nginx_backup.conf
  ```

## 🔴 5.2 `frontend/Dockerfile` tiene nginx interno + hay servicio nginx en compose

- **Archivo**: `frontend/Dockerfile:13-48`
- **Fix**: Eliminar nginx interno del frontend. Hacer que el contenedor solo exponga `/dist` como volumen. Dejar que el servicio `nginx` del compose sea el único servidor.

## 🔴 5.3 Migraciones huérfanas en `__pycache__`

- **Archivos**: `backend/alembic/versions/__pycache__/add_missing_tables.cpython-314.pyc`, `add_world_indices_and_international_stocks.cpython-314.pyc`
- **Fix**:
  ```bash
  rm -rf backend/alembic/versions/__pycache__/
  # Verificar con: cd backend && alembic heads
  ```

## 🔴 5.4 `Stocks.tsx:93-95`, `Profile.tsx:13`, `LessonDetail.tsx:54-57` JSON.parse sin try/catch

- **Fix**: Centralizar auth en Zustand (Fase 3.2). Eliminar `JSON.parse` de páginas.

## 🔴 5.5 `App.tsx:168` `<Navigate to="/dashboard" />` sin `replace`

- **Archivo**: `frontend/src/App.tsx`
- **Fix**: `<Navigate to="/dashboard" replace />`.

## 🔴 5.6 `LessonDetail.tsx:42` quiz compara traducción con índice

- **Fix**: Comparar con `'1'` numérico, traducir al renderizar.

## 🔴 5.7 `main.tsx:12-22` SW registrado en dev

- **Archivo**: `frontend/src/main.tsx`
- **Fix**: `if (import.meta.env.PROD && 'serviceWorker' in navigator)`.

## 🟠 5.8 `OnboardingModal` no se usa (dead code)

- **Archivo**: `frontend/src/components/OnboardingModal.tsx`
- **Fix**: Eliminar o integrar en flujo.

## 🟠 5.9 `ThemeProvider.tsx:23-44` `toggleTheme` y `setDarkModeValue` duplican lógica

- **Fix**: Extraer `applyTheme(value: boolean)` privado.

## 🟠 5.10 `useStore.ts:59-67` `saveToStorage` y `clearStorage` no se usan

- **Fix**: Eliminar.

## 🟠 5.11 `Spinners` duplicados en 5+ archivos

- **Archivos**: `App.tsx`, `PrivateRoute.tsx`, `Dashboard.tsx`, `Markets.tsx`, `Transactions.tsx`
- **Fix**: Crear `src/components/ui/Spinner.tsx` reutilizable.

## 🟠 5.12 `formatCurrency` redefinido en 5+ páginas

- **Archivos**: `Dashboard`, `Portfolio`, `Transactions`, `Profile`, `Leaderboard`, `Markets`
- **Fix**: Crear `src/utils/format.ts` con `formatCurrency`, `formatPercentage`, `formatTimeAgo`, `formatDate`.

## 🟠 5.13 `SortIcon` redefinido en 2 archivos

- **Archivos**: `Portfolio.tsx`, `Transactions.tsx`
- **Fix**: Crear `src/components/ui/SortIcon.tsx`.

## 🟠 5.14 `EmptyState` no existe (código inline en cada página)

- **Fix**: Crear `src/components/ui/EmptyState.tsx` con props `{ icon, title, description, action? }`.

## 🟠 5.15 `Modal` no existe (código inline en admin)

- **Fix**: Crear `src/components/ui/Modal.tsx` con focus trap + Escape.

## 🟠 5.16 `ConfirmDialog` no existe

- **Fix**: Crear `src/components/ui/ConfirmDialog.tsx` para acciones destructivas.

## 🟠 5.17 `src/utils/`, `src/context/`, `src/hooks/` VACÍOS

- **Fix**: Poblar con los hooks/utils faltantes (ver 5.11-5.16).

## 🟠 5.18 `vite.config.ts:9-14` proxy solo para `/api`

- **Fix**: Agregar `'/health': 'http://localhost:8000'` o cambiar endpoint a `/api/v1/health`.

## 🟠 5.19 `main.tsx:18` SW handler solo `console.log`

- **Fix**: `toast.error('Error al registrar service worker')`.

## 🟠 5.20 `GuidedTour.tsx:88, 88` `currentStep <= 0` redundante

- **Fix**: `currentStep === 0`.

## 🟠 5.21 `Admin.tsx:412-431` mobile tabs vs desktop sidebar duplican items

- **Fix**: Extraer `navItems` y parametrizar render.

## 🟠 5.22 `Admin.tsx:226-229` `useEffect` con deps vacías

- **Fix**: Mover `loadKpis`, `loadUsers` a `useCallback` con `[token]` y agregarlos a deps.

## 🟠 5.23 `.codex/` y `Semestre/Finanzas Inter/Simulador/` carpetas huérfanas

- **Fix**: Eliminar o documentar propósito. Si son notas del curso, mover a `docs/`.

## 🟠 5.24 `backend/run.sh:1-2` y `setup.bat:1-47` desactualizados

- **Archivo**: `backend/setup.bat:7-24` instala paquetes que NO están en `requirements.txt` actual.
- **Fix**: Eliminar o reescribir.

## 🟠 5.25 `backend/.env.production` y `.env.example` raíz duplican config

- **Fix**: Documentar cuál usar y cuándo en `DOKPLOY_DEPLOYMENT.md`.

## 🟠 5.26 `setup.bat:27-28` crea estructura incorrecta

- **Fix**: Refactorizar o eliminar.

## 🟠 5.27 `tsconfig.json:14-17` strict + ESLint permite `any`

- **Fix**: Cambiar ESLint rule a `'error'`.

## 🟠 5.28 `frontend/.eslintrc.cjs:13-18` reglas permisivas

- **Fix**: Activar `react-refresh/only-export-components`, `react-hooks/exhaustive-deps: 'error'`, `no-console: 'warn'`, `@typescript-eslint/consistent-type-imports: 'error'`.

## 🟠 5.29 `.github/workflows/ci.yml` (submódulos) — versiones desalineadas

- **Archivos**: `backend/.github/workflows/ci.yml:31-42` usa `postgres:15-alpine` vs `postgres:16-alpine` en compose.
- **Fix**: Alinear versiones.

## 🟠 5.30 `package.json:32-44` versiones desactualizadas

- `eslint@^8.55.0` → 9.x con flat config.
- `tailwindcss@^3.4.1` → 4.x estable.
- `lucide-react@^0.292.0` → 0.460+.
- `axios@^1.6.0` → 1.7+.
- `zod@^4.4.3` → verificar breaking changes.

## 🟠 5.31 `pyproject.toml` pytest config incompleta

- **Fix**:
  ```toml
  [tool.pytest.ini_options]
  asyncio_mode = "auto"
  testpaths = ["tests"]
  addopts = "-v --tb=short --strict-markers"
  markers = ["integration", "slow", "security"]

  [tool.coverage.run]
  source = ["app"]
  omit = ["app/__init__.py", "app/tests/*"]
  ```

## 🟠 5.32 `conftest.py:1-12` sin fixture DB aislada

- **Fix**: `pytest-asyncio` con `engine.begin()` + `Base.metadata.drop_all/create_all` por test, o `pytest-postgresql` con scope `function`.

## 🟠 5.33 `conftest.py:1-12` fixture no mockea Redis/Finnhub

- **Fix**: Override de `get_redis`, mock `finnhub_service`, deshabilitar `ENABLE_STARTUP_PRELOAD` en tests.

## 🟡 5.34-5.44 (11 issues medios) — ver reporte extendido

- `nginx/includes/security.conf:9` CSP hardcoded a `finsimup.app` (no reutilizable).
- `DOKPLOY_DEPLOYMENT.md:1-54` no documenta backup, rollback, rotación de secrets.
- `docs/*.md` enlaces relativos pueden romperse.
- `frontend/public/manifest.json:11-25` iconos en `/src/assets/` (no disponibles en prod).
- `frontend/public/robots.txt:3` apunta a sitemap inexistente.
- `frontend/index.html:5-7` favicon triple (3 líneas casi idénticas).
- `frontend/index.html:19, 21` description duplicada.
- `frontend/src/components/SEOHead.tsx:62-65` no cambia por página.
- `frontend/src/components/ErrorBoundary.tsx:31-37` mensajes en inglés hardcoded.
- `frontend/src/components/GuidedTour.tsx:88-103` handleNext/handlePrev asimétricos.
- `frontend/src/pages/Register.tsx:330` "← Volver al registro" hardcoded.

---

# 📋 Plan de remediación priorizado

## 🔴 URGENTE (esta semana)

1. **Rotar TODOS los secretos** en `/.env` y `backend/.env` (Fase 1.1)
2. `git rm --cached` de `.env` + purgar del historial (Fase 1.1)
3. Añadir `.env.production` a `.gitignore` (Fase 1.2)
4. Eliminar `nginx/nginx_backup.conf` (Fase 5.1)
5. Corregir memory leak en `GuidedTour.tsx:49-53` (Fase 3.5)
6. Agregar `is_active` check en `portfolio.buy/sell` (Fase 1.5)
7. Corregir `LessonDetail.tsx:42` quiz bug (Fase 3.6)

## 🟠 Sprint 1 (1-2 semanas)

8. Auth a `/send-verification-code` y `/verify-code` (Fase 1.3)
9. Rate limit con `request.client.host` (Fase 1.4)
10. Race condition fix en buy/sell (Fase 1.6)
11. Re-leer `rol` de DB en admin (Fase 1.7)
12. `SECRET_KEY` min_length=64 + validación startup (Fase 1.8)
13. Migrar a `lifespan` (Fase 1.9)
14. JWT con `iat`, `aud`, `iss`, `jti`, `password_version` (Fase 1.11)
15. Username lowercase enforced (Fase 1.12)
16. EmailStr para email (Fase 1.13)
17. `vitest` + `playwright` setup (Fase 2.1-2.2)
18. Centralizar auth en Zustand (Fase 3.2)
19. Reemplazar 8+ `window.location.href` (Fase 3.8)
20. Eliminar `OnboardingModal` dead code (Fase 5.8)

## 🟡 Sprint 2-3 (2-4 semanas)

21. Tests funcionales backend (60% cobertura) (Fase 2.1)
22. Dockerfile multi-stage + non-root (Fase 1.21, 2.16)
23. CSP sin `'unsafe-inline'` (Fase 1.23)
24. nginx.conf con rate limit + cache (Fase 1.24, 2.17)
25. CI workflow raíz con gitleaks (Fase 1.1)
26. Eliminar nginx duplicado en frontend Dockerfile (Fase 5.2)
27. AbortController en todos los fetches (Fase 2.14)
28. `useDebounce` en búsqueda (Fase 3.10)
29. Crear `src/components/ui/` con Spinner, Modal, EmptyState (Fase 5.11-5.16)
30. Formularios con zod (Fase 3.12)
31. Mover 21+ strings hardcoded a i18n (Fase 3.16)
32. Tablas responsive con cards en mobile (Fase 4.4)

## 🟢 Sprint 4+ (mejoras continuas)

33. WCAG 2.2 AA compliance (Fase 3.1)
34. Virtualización de listas (Fase 2.11)
35. Lazy loading de i18n (Fase 2.5)
36. `manualChunks` mejorado (Fase 2.6)
37. Sourcemaps `hidden` en prod (Fase 1.27)
38. Documentar backup/rollback (Fase 5.34)
39. Sentry/Datadog integration (Fase 1.26)
40. Tests E2E con Playwright (Fase 2.2)

---

# ✅ Confirmaciones positivas

A pesar de los hallazgos, el proyecto tiene:

- ✅ **Bcrypt** con salt automático y rounds ≥ 12.
- ✅ **JWT** decodifica con `algorithms` whitelist (no `none`).
- ✅ **No hay SQL injection** — todo es ORM parametrizado.
- ✅ **No hay IDOR** — endpoints legacy verifican `ensure_own_resource`.
- ✅ **No hay mass assignment** explotable crítico.
- ✅ **Transacciones atómicas** con `with_for_update()` en buy/sell.
- ✅ **Tokens de password reset** hasheados con SHA-256.
- ✅ **Mensaje genérico** en `/forgot-password` (no enumeration).
- ✅ **2FA** con cap de intentos (MAX_ATTEMPTS=3) y TTL 10min.
- ✅ **HTTPS** delegado a nginx (puerto 443 en compose).
- ✅ **Postgres password** required en compose.
- ✅ **Health check** en `/health` para readiness.
- ✅ **Docker layer caching** correcto.
- ✅ **Multi-stage build** en frontend Dockerfile.
- ✅ **CSP, HSTS, COOP, CORP, X-Frame-Options** en nginx.
- ✅ **TypeScript strict** + `noUnusedLocals/Parameters`.
- ✅ **Code-splitting** via `lazy()` en todas las rutas.
- ✅ **dark mode** con CSS variables.
- ✅ **`recharts`** aislado en chunk separado.
- ✅ **`.dockerignore`** presente y completo.
- ✅ **CI workflows** en submodules (lint + build + test).
- ✅ **Healthchecks** en `db` y `redis`.
- ✅ **`secrets.compare_digest`** en API key validation (timing-safe).
- ✅ **Previene auto-ban/role-change** en admin.

---

# 📚 Referencias y herramientas

- **OWASP Top 10** — https://owasp.org/Top10/
- **WCAG 2.2** — https://www.w3.org/WAI/WCAG22/quickref/
- **FastAPI security** — https://fastapi.tiangolo.com/tutorial/security/
- **React Testing Library** — https://testing-library.com/docs/react-testing-library/intro/
- **Playwright** — https://playwright.dev/
- **VitePWA** — https://vite-pwa-org.netlify.app/
- **axios-retry** — https://github.com/softonic/axios-retry
- **git-filter-repo** — https://github.com/newren/git-filter-repo
- **gitleaks** — https://github.com/gitleaks/gitleaks
- **Vitest** — https://vitest.dev/
- **zod** — https://zod.dev/

---

**Generado**: 2026-06-06
**Modo de auditoría**: Read-only (sin modificaciones)
**Próximo paso**: Comenzar remediación con Fase 1 (Seguridad) y Fase 5 (Bugs/Duplicidad) en paralelo.
**Total de issues documentados**: 204
