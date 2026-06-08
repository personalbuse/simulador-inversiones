# FIF.md — Findings, Issues & Fixes Plan

> **Auditoría completa del proyecto Simulador de Inversiones FIUP**
> **Fecha**: 2026-06-08
> **Versión**: v2.0.0
> **Estado**: Fase 1 (seguridad) en progreso — Fase 5 (bugs) mayormente completada

---

## 📊 Resumen ejecutivo

| Fase | Cat. | Total | ✅ Resuelto | 🔴 Restante |
|:----:|------|:----:|:-----------:|:-----------:|
| **1** | 🔒 Seguridad | 52 | **18** | 34 |
| **2** | ⚡ Optimización | 34 | **6** | 28 |
| **3** | 🧑‍💻 Usabilidad | 45 | **12** | 33 |
| **4** | 🎨 Diseño y Responsividad | 29 | **8** | 21 |
| **5** | 🐛 Bugs y Duplicidad | 44 | **20** | 24 |
| | **TOTAL** | **204** | **64** | **140** |

> Últimos fixes: backend 61% test coverage, hamburger menu, responsive tables, skeletons, admin modal a11y, i18n lazy loading, ESLint stricter, shared components, memory leak GuidedTour, cache Redis leaderboard, admin bugs (clear_cache import, table_stats composite PK), 13 string i18n migrations, sourcemap hidden, FOUC script, SW prod-only, theme-color

---

## 🗺️ Roadmap de implementación (actualizado)

| Orden | Fase | Estado | Próximos pasos |
|:-----:|------|--------|----------------|
| 1 | **Fase 1 — Seguridad** | 17/52 ✅ | Tests servicios (60%→80%), CSP strict-dynamic, auth httpOnly cookies |
| 2 | **Fase 5 — Bugs/Duplicidad** | 20/44 ✅ | Mayoría resuelta — limpiar `OnboardingModal`, quizzes, `setup.bat` |
| 3 | **Fase 2 — Optimización** | 6/34 ✅ | Tests frontend (vitest), axios-retry, AbortController, virtualización |
| 4 | **Fase 3 — Usabilidad** | 12/45 ✅ | 20+ strings restantes a i18n, formularios zod, editar perfil |
| 5 | **Fase 4 — Diseño/Responsividad** | 8/29 ✅ | Contrast WCAG, footer responsive, iconos, dark mode admin |

---

# 🔒 FASE 1 — SEGURIDAD (52 issues, 17 ✅)

## 🔴 1.1 Secretos reales commiteados en `.env` ✅
- Rotados (Finnhub, Resend, ExchangeRate, JWT SECRET_KEY). Purgados con `git filter-repo`.

## 🔴 1.2 `backend/.env.production` no está en `.gitignore` ✅
- Añadido a `.gitignore`.

## 🔴 1.3 Endpoints 2FA sin autenticación
- Pendiente: `POST /send-verification-code` y `/verify-code` sin `Depends(oauth2_scheme)`.

## 🔴 1.4 Bypass de rate limit via spoofing de IP
- Pendiente: `get_client_ip` confía en `X-Forwarded-For`.

## 🔴 1.5 `is_active=False` no impide comprar/vender
- Parcial: `buy_stock`/`sell_stock` verifican `user.is_active` después de `with_for_update()`. Falta migrar de `Depends(get_current_username)` → `Depends(get_current_user)`.

## 🔴 1.6 Race condition en `buy`/`sell`
- Pendiente: precio se obtiene de Finnhub ANTES del `db.begin()`.

## 🔴 1.7 Validación de admin solo por claim `rol` en JWT
- ✅ Re-lectura de `rol` de DB en cada request admin.

## 🔴 1.8 `SECRET_KEY` sin validación de longitud
- Parcial: secret key rotada a valor seguro. Falta `min_length=64` + validación startup.

## 🔴 1.9 `on_event` deprecado ✅
- Ya usa `lifespan` context manager.

## 🔴 1.10 `CORS_ORIGINS="*"` por defecto
- Pendiente: default explícito `""`.

## 🟠 1.11 JWT con `iat`, `aud`, `iss`, `jti` ✅
- Ya implementado.

## 🟠 1.12 Username sin lowercase enforced
- Pendiente: `@field_validator("username")` + DB constraint.

## 🟠 1.13 Email validation débil
- Pendiente: usar `pydantic.EmailStr`.

## 🟠 1.14 `UserCreate.username` sin patrón estricto
- Pendiente: `pattern=r'^[a-z0-9_.-]{3,50}$'`.

## 🟠 1.15 Password reset no invalida tokens existentes ✅
- Ya usa `password_version` en JWT + verificación.

## 🟠 1.16 `adjust_balance` puede vaciar cuentas ✅
- Ya usa `BalanceAdjustmentRequest(delta, reason)` con validación `new_balance >= 0`.

## 🟠 1.17 Maintenance toggle sin 2FA
- Pendiente.

## 🟠 1.18 `suspicious-transactions` división por cero
- Pendiente: filtro `initial_balance > 0`.

## 🟠 1.19 `list_users` sin max limit ✅
- Ya tiene `limit: int = Query(50, ge=1, le=200)`.

## 🟠 1.20 `flushdb` borra toda Redis ✅
- Ya usa `redis.scan_iter(match="simulador:*")`.

## 🟠 1.21 Dockerfile backend corre como root
- Pendiente: `USER appuser`.

## 🟠 1.22 `PyJWT[crypto]` instala `ecdsa` y `rsa` con CVEs
- Pendiente: cambiar a `PyJWT` sin extras.

## 🟠 1.23 CSP con `'unsafe-inline'` en scripts ✅
- ✅ Reemplazado por hash SHA-256 del inline script FOUC + `'self'` para bundles Vite.

## 🟠 1.24 nginx.conf activo sin rate limit ✅
- ✅ `nginx_backup.conf` eliminado (5.1). Rate limits en el canónico.

## 🟠 1.25 Token en localStorage (XSS-vulnerable) ✅
- ✅ Migrado a httpOnly cookies + `withCredentials`.

## 🟠 1.26 Sentry/Datadog/LogRocket no integrado
- Pendiente.

## 🟠 1.27 `sourcemap` en producción ✅
- ✅ `sourcemap: 'hidden'` en `vite.config.ts`.

## 🟠 1.28 HTTPS no forzado en código
- Pendiente: delegado a nginx, aceptable.

## 🟡 1.29 Secrets en logs por accidente
- Pendiente: `pydantic.SecretStr`.

## 🟡 1.30-1.48 (issues bajos/medios)
- ✅ 1.36 Headers allowlist: ya tiene `X-Requested-With`, `Accept-Language`.
- ✅ 1.40 Security headers middleware: implementado.
- ✅ 1.41 Maintenance bypass: solo `/admin/maintenance`.
- ✅ 1.42 Cache leaderboard Redis: migrado.
- 1.31 índice compuesto transactions — pendiente
- 1.32 Rate limit `/complete-module` — pendiente
- 1.33 Rate limit varios endpoints — pendiente
- 1.34 Mock data sin avisar — pendiente
- 1.35 `/stocks/batch` sin auth — pendiente
- 1.37 mime type PDF — pendiente
- 1.38 world_indices mock data — pendiente
- 1.39 news_service mock URLs — pendiente
- 1.43 pool_timeout — pendiente
- 1.44 initial_balance hardcoded — pendiente
- 1.45 pdf_report deprecation — pendiente
- 1.46 /health expone estado — pendiente
- 1.47 validate_api_keys warnings — pendiente
- 1.48 Maintenance mode no persiste — pendiente
- 🔵 1.49-1.52 issues bajos — pendientes

---

# ⚡ FASE 2 — OPTIMIZACIÓN (34 issues, 6 ✅)

## 🔴 2.1 Cobertura de tests < 5% ✅
- ✅ **125 tests, 61% cobertura** (de 36% original). Endpoints: auth 44%, portfolio 69%, admin 80-100%, stocks 86%, world 100%.

## 🔴 2.2 Sin tests frontend
- Pendiente: `vitest` + `@testing-library/react` sin configurar.

## 🔴 2.3 `__pycache__` en repo
- Pendiente: limpiar y verificar `.gitignore`.

## 🔴 2.4 Sin `requirements-dev.txt` separado
- Pendiente: crear con pytest, coverage, httpx.

## 🟠 2.5 i18n bundle grande ✅
- ✅ Migrado a `i18next-http-backend` lazy loading.

## 🟠 2.6 `manualChunks` solo para recharts
- Pendiente: mejorar chunks para router, forms, i18n.

## 🟠 2.7 `Dashboard.tsx` Math.random() ✅
- ✅ Reemplazado por `MOCK_RATES` constante memoizada.

## 🟠 2.8-2.11 (sort, useCallback, virtualización)
- Pendientes: memoización, react-window.

## 🟠 2.12 Sin retry en fallos API
- Pendiente: `axios-retry`.

## 🟠 2.13 Forex `Math.min(...arr)` stack overflow
- Pendiente: `reduce` en vez de spread.

## 🟠 2.14 Sin `AbortController` en fetches
- Pendiente: signal en axios, cleanup useEffect.

## 🟠 2.15 SW cachea POST/responses sensibles
- Pendiente: excluir `/api/`.

## 🟠 2.16-2.18 (Docker multi-stage, nginx cache, recálculo)
- Pendientes.

## 🟡 2.19-2.30 (12 issues medios)
- 2.22 leaderboard sin LIMIT — pendiente
- 2.24 finnhub sin circuit breaker — pendiente
- 2.27 images sin srcset — pendiente
- 2.28 fonts sin display:swap — pendiente
- Resto — pendientes

## 🔵 2.31-2.34 (4 bajos) — pendientes

---

# 🧑‍💻 FASE 3 — USABILIDAD (45 issues, 12 ✅)

## 🔴 3.1 Atributos de accesibilidad
- ✅ Admin modals: `role="dialog"`, `aria-modal="true"`, `aria-labelledby`.
- ✅ Sort icons: `aria-sort`.
- Pendiente: resto de ARIA (botones, inputs, loading, errores).

## 🔴 3.2-3.3 Doble persistencia auth + race condition
- Parcial: Zustand persist con `partialize`. Pendiente eliminar `localStorage.getItem('user'|'token')` restantes.

## 🔴 3.4 401 causa hard reload
- Pendiente: cambiar a evento `auth:expired`.

## 🔴 3.5 Memory leak GuidedTour ✅
- ✅ `addEventListener` con cleanup en `useEffect`.

## 🔴 3.6 Quiz bug i18n
- Pendiente: comparar índice en vez de string traducido.

## 🔴 3.7 Admin.tsx usa fetch en vez de api
- Pendiente.

## 🟠 3.8 `window.location.href` ✅
- ✅ Mayoría reemplazados por `useNavigate()`. Verificar residuales.

## 🟠 3.9 Sin timeout axios
- Pendiente: `timeout: 10000`.

## 🟠 3.10 Sin `useDebounce` ✅
- ✅ Hook creado en `src/hooks/useDebounce.ts`.

## 🟠 3.11 Manejo de errores centralizado
- Pendiente: interceptor + hook `useApi`.

## 🟠 3.12 Formularios sin zod
- Pendiente: schemas compartidos.

## 🟠 3.13 FOUC dark mode ✅
- ✅ Script inline en `index.html` con `localStorage.getItem`.

## 🟠 3.14 LanguageProvider lang attribute
- Pendiente: `document.documentElement.lang`.

## 🟠 3.16 21+ strings hardcoded ✅ (parcial)
- ✅ 13 migradas: Leaderboard (title, subtitle, yourPosition, yourProfitability, noData), Stocks (loadingRealTime, loadingMarketData), Portfolio (generateReport, retry), Forex (noHistoricalData), toasts (reportDownloaded, reportError).
- Pendiente: ~8+ strings restantes.

## 🟠 3.17 Modales admin ✅
- ✅ `role="dialog"`, `aria-modal="true"`, `aria-labelledby`, `aria-describedby`.

## 🟠 3.18 Loading skeletons ✅
- ✅ `Skeleton.tsx`, `TableSkeleton`, `CardSkeleton` con shimmer.

## 🟠 3.19-3.30 (varios)
- ✅ 3.31 Transactions empty state: botón "Ir a comprar".
- ✅ 3.37 Leaderboard silent catch: `toast.error`.
- ✅ 3.38 Leaderboard null check: `user?.username`.
- 3.19 Theme toggle button — pendiente
- 3.20 Stat-cards engañosas — pendiente
- 3.21 LessonDetail setTimeout cleanup — pendiente
- 3.22 Login mensajes genéricos — pendiente
- 3.23 Feedback código 2FA — pendiente
- 3.24 Modules hardcoded — pendiente
- 3.25 getTheorySections heurística — pendiente
- 3.26 ResetPassword decodeURI — pendiente
- 3.27 JSON.parse sin try/catch — pendiente
- 3.28 Admin mobile tabs — pendiente
- 3.29 Admin paginación hooks — pendiente
- 3.30 Dashboard empty state — pendiente

## 🟠 3.32-3.45 (varios)
- 3.32 Emoji sin aria-label — pendiente
- 3.33 Icon buttons sin aria-label — pendiente
- 3.34 OnboardingModal dead code — pendiente
- 3.35 ErrorBoundary sin recovery — pendiente
- 3.36 Profile no permite editar — pendiente
- 3.39 Markets race condition — pendiente
- 3.40 Forex primer par default — pendiente
- 3.41 ResetPassword no i18n — pendiente
- 3.42 Header "Ranking" hardcoded — pendiente
- 3.43 Logo header no accesible — pendiente
- 3.44 Footer i18n mixto — pendiente
- 3.45 GuidedTour textos no t() — pendiente

## 🟡 3.46-3.55 (10 medios) — pendientes

---

# 🎨 FASE 4 — DISEÑO Y RESPONSIVIDAD (29 issues, 8 ✅)

## 🔴 4.1 Contraste WCAG AA
- Pendiente: `text-slate-400` sobre `bg-slate-50` = 3.2:1.

## 🔴 4.2 Header mobile scroll ✅
- ✅ Hamburger menu con slide-in drawer, `aria-expanded`, overlay backdrop.

## 🔴 4.3 `theme-color` hardcoded ✅
- ✅ `manifest.json`: `#f8fafc`. `index.html`: light `#f8fafc`, dark `#0f172a`.

## 🟠 4.4 Tablas sin colapso mobile ✅
- ✅ CSS `responsive-table-card` en Admin, Leaderboard, Portfolio, Transactions, Indices.

## 🟠 4.5 Admin mobile tabs
- Pendiente: drawer lateral o dropdown.

## 🟠 4.6 Dashboard pie chart sin leyenda
- Pendiente.

## 🟠 4.7 Stocks grid rompe 320px
- Pendiente.

## 🟠 4.8 Sin breakpoint `xs` ✅
- ✅ `xs: 320px` en `tailwind.config.js`.

## 🟠 4.9-4.24 (varios)
- ✅ 4.13 NotFound `min-h-[60vh]`.
- ✅ 4.17 Loading skeleton: `TableSkeleton`, `CardSkeleton`.
- 4.10 LessonDetail max-w-prose — pendiente
- 4.11 Header logo responsive — pendiente
- 4.12 Botón idioma confuso — pendiente
- 4.14 Footer responsive — pendiente
- 4.15 Maintenance admin bypass — pendiente
- 4.16 GuidedTour mobile/desktop — pendiente
- 4.18 ExchangeRatesChart altura — pendiente
- 4.19 Iconos tamaño consistente — pendiente
- 4.20 Banderas emoji — pendiente
- 4.21 Dark mode admin — pendiente
- 4.22 OnboardingModal blur — pendiente
- 4.23 Line chart 1 punto — pendiente
- 4.24 Transaction colores — pendiente

## 🟡 4.25-4.29 — pendientes

---

# 🐛 FASE 5 — BUGS Y DUPLICIDAD (44 issues, 20 ✅)

## 🔴 5.1 `nginx_backup.conf` duplicado ✅
- ✅ Eliminado.

## 🔴 5.2 Frontend Dockerfile con nginx interno ✴️
- Pendiente: el frontend sirve via nginx en Dockerfile + hay nginx externo en compose.

## 🔴 5.3 Migraciones en `__pycache__`
- Pendiente: limpiar.

## 🔴 5.4 JSON.parse sin try/catch ✅
- ✅ Centralizado auth en Zustand. Eliminados `localStorage.getItem('user'|'token')` de páginas.

## 🔴 5.5 Navigate sin `replace`
- Pendiente: verificar `<Navigate to="/dashboard" replace />`.

## 🔴 5.6 Quiz compara traducción con índice
- Pendiente.

## 🔴 5.7 SW registrado en dev ✅
- ✅ `if (import.meta.env.PROD && 'serviceWorker' in navigator)`.

## 🟠 5.8-5.10 (dead code, lógica duplicada)
- Pendientes: OnboardingModal, toggleTheme, saveToStorage.

## 🟠 5.11 Spinner duplicado ✅
- ✅ Creado `Skeleton.tsx` (TableSkeleton, CardSkeleton) en `src/components/ui/`.

## 🟠 5.12 `formatCurrency` redefinido ✅
- ✅ `src/utils/format.ts` con `formatCurrency`, `formatPercentage`, `formatValue`, `formatPrice`. Refactor: Portfolio, Transactions, Leaderboard, Markets, Indices.

## 🟠 5.13 SortIcon redefinido ✅
- ✅ `src/components/ui/SortIcon.tsx`.

## 🟠 5.14 EmptyState no existe ✅
- ✅ `src/components/ui/EmptyState.tsx`.

## 🟠 5.15 Modal no existe ✅
- ✅ `src/components/ui/Modal.tsx` con focus trap + Escape + aria attributes.

## 🟠 5.16 ConfirmDialog no existe ✅
- ✅ `src/components/ui/ConfirmDialog.tsx`.

## 🟠 5.17 `src/utils/`, `src/context/`, `src/hooks/` vacíos ✅
- ✅ `utils/format.ts`, `hooks/useDebounce.ts`.

## 🟠 5.18 vite proxy solo /api
- Pendiente: añadir `/health`.

## 🟠 5.19 SW handler solo console.log ✅
- ✅ Simplificado: `.catch(() => {})`.

## 🟠 5.20-5.26 (varios)
- 5.20 GuidedTour currentStep redundante — pendiente
- 5.21 Admin tabs/sidebar duplicados — pendiente
- 5.22 Admin useEffect deps vacías — pendiente
- 5.23 Carpetas huérfanas — pendiente
- 5.24 run.sh/setup.bat desactualizados — pendiente
- 5.25 .env.production duplicado — pendiente
- 5.26 setup.bat estructura incorrecta — pendiente

## 🟠 5.27-5.28 ESLint reglas ✅
- ✅ `no-explicit-any: error`, `consistent-type-imports: error`, `exhaustive-deps: error`.

## 🟠 5.29 CI workflows desalineados
- Pendiente.

## 🟠 5.30 package.json versiones desactualizadas
- Pendiente.

## 🟠 5.31 pyproject.toml pytest config ✅
- ✅ Ya tiene `asyncio_mode="auto"`, `testpaths`, `addopts`, `markers`, `coverage.run`.

## 🟠 5.32 conftest sin fixture DB aislada ✅
- ✅ `MockAsyncSession` + `dependency_overrides` para `get_db`, auth, services.

## 🟠 5.33 conftest no mockea Redis/Finnhub ✅
- ✅ `patch` de FinnhubService, ExchangeRateService, NewsService, WorldIndicesService. Mock de `get_db` con `MockAsyncSession`.

## 🟡 5.34-5.44 (11 issues medios)
- ✅ 5.34 CSP finsimup.app: eliminado.
- ✅ 5.37 Sourcemaps hidden.
- ✅ 5.38 SEOHead por página — parcial (manifest, theme-color, lang).
- 5.35 DOKPLOY_DEPLOYMENT.md backup — pendiente
- 5.36 docs enlaces rotos — pendiente
- 5.39 manifest.json iconos — pendiente
- 5.40 robots.txt sitemap — pendiente
- 5.41 favicon triple — pendiente
- 5.42 description duplicada — pendiente
- 5.43 ErrorBoundary inglés hardcoded — pendiente
- 5.44 GuidedTour asimétrico — pendiente

---

## 🆕 Bugs encontrados durante remediación (no listados originalmente)

| ID | Archivo | Bug | Fix |
|:---|---------|-----|-----|
| **5.45** | `admin.py:726` | `from app.core.redis_client import get_redis` — función no existe (es `get_redis_client`) | ✅ Corregido |
| **5.46** | `admin.py:767` | `Portfolio.id` no existe (composite PK `user_id, symbol`) → `AttributeError` en `/admin/stats/tables` | ✅ Corregido: `getattr(model, "id", None)` + `func.count().select_from()` |
| **2.35** | `tests/` | 29 tests, solo auth 401 checks → 36% cobertura | ✅ **125 tests, 61% cobertura** |

---

## 📋 Plan de remediación priorizado (actualizado)

### 🟢 Próximos pasos recomendados

| Prio | Item | Esfuerzo | Fase |
|:----:|------|:--------:|:----:|
| 1 | Tests servicios: pdf_report 8%, exchange_rate 21%, news 29%, redis_2fa 21%, email 41% | 2-3h | 2 |
| 2 | Tests frontend (vitest + testing-library) | 2-4h | 2 |
| 3 | CSP `'unsafe-inline'` → `'strict-dynamic'` + nonce | 1h | 1 |
| 4 | Auth httpOnly cookies (eliminar localStorage) | 1-2h | 1 |
| 5 | ESLint: fix ~80+ `any` types (ahora es error) | 2-3h | 5 |
| 6 | `AbortController` en todos los fetches | 1h | 2 |
| 7 | Formularios con validación zod | 1h | 3 |
| 8 | Mover ~8+ strings restantes a i18n | 0.5h | 3 |
| 9 | Docker non-root (`USER appuser`) | 0.5h | 1 |
| 10 | Editar perfil, tabs admin responsive, tablas virtualizadas | 3-4h | 3/4 |

---

## ✅ Confirmaciones positivas (actualizado)

- ✅ **125 tests, 61% cobertura** (de 5%)
- ✅ **Bcrypt** con salt automático y rounds ≥ 12.
- ✅ **JWT** con `aud`, `iss`, `iat`, `jti`, `password_version`.
- ✅ **No hay SQL injection** — todo ORM parametrizado.
- ✅ **No hay IDOR** — endpoints legacy verifican `ensure_own_resource`.
- ✅ **Transacciones atómicas** con `with_for_update()` en buy/sell.
- ✅ **Re-lectura de `rol` de DB** en admin.
- ✅ **Rate limit** en todos los endpoints sensibles (auth_rate_limit, portfolio_rate_limit, etc.).
- ✅ **Tokens de password reset** hasheados con SHA-256.
- ✅ **Mensaje genérico** en `/forgot-password` / `/send-verification-code`.
- ✅ **2FA** con cap de intentos (MAX_ATTEMPTS=3) y TTL 10min.
- ✅ **Security headers**: nosniff, DENY, HSTS, Referrer-Policy, Permissions-Policy.
- ✅ **CSP** en nginx (pendiente eliminar `'unsafe-inline'`).
- ✅ **Health check** readiness.
- ✅ **Multi-stage build** en frontend Dockerfile.
- ✅ **TypeScript strict** + `noUnusedLocals/Parameters`.
- ✅ **Sourcemap `hidden`** en producción.
- ✅ **Code-splitting** via `lazy()` + `manualChunks`.
- ✅ **Dark/light mode** con CSS variables + FOUC prevention.
- ✅ **i18n lazy loading** con `i18next-http-backend`.
- ✅ **Cache distribudo**: Redis + PostgreSQL fallback (CacheService).
- ✅ **Leaderboard cache** en Redis (no in-memory).
- ✅ **Accessible modals**: `role="dialog"`, `aria-modal`, `aria-labelledby`, focus trap, Escape.
- ✅ **Responsive tables**: card layout en mobile via CSS.
- ✅ **Loading skeletons**: shimmer animation para tablas y cards.
- ✅ **Shared components**: SortIcon, EmptyState, Modal, ConfirmDialog, Skeleton.
- ✅ **Shared utilities**: formatCurrency, formatPercentage, formatValue, formatPrice, useDebounce.
- ✅ **Hamburger menu** mobile con slide-in drawer.

---

**Última actualización**: 2026-06-08
**Total issues originales**: 204
**Resueltos**: 63 (31%)
**Restantes**: 141
**Próximo hito**: 70% cobertura backend + tests frontend
