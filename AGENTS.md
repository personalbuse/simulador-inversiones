# AGENTS.md — Simulador de Inversiones FIUP

> Instrucciones operativas para agentes IA (opencode, Claude, GPT, etc.) que trabajen en este proyecto.
> **Objetivo**: reducir el consumo de tokens, acelerar el contexto y mantener consistencia entre sesiones.

---

## 1. Proyecto en 30 segundos

| Aspecto | Detalle |
|---|---|
| **Dominio** | Simulador bursátil educativo · Universidad de Pamplona (UP), Colombia |
| **Stack Backend** | Python 3.12 · FastAPI 0.135 · SQLAlchemy 2.0 async · PostgreSQL 16 · Redis 7 · APScheduler |
| **Stack Frontend** | Node 20 · React 18 · TypeScript 5.3 · Vite 5 · TailwindCSS 3.4 · Zustand 4 · react-i18next 14 · recharts 2.15 · axios 1.6 |
| **Deploy** | Docker Compose + Nginx + Dokploy / AWS EC2 |
| **Auth** | JWT (HS256) + bcrypt · 2FA email con Resend |
| **Datos externos** | Finnhub (acciones/índices), ExchangeRate-API (divisas), Resend (email) |
| **Idiomas** | `es` (default) · `en` (parcial) |
| **Tema** | Dark / Light (CSS vars + `dark:` Tailwind) |

---

## 2. Estructura del repositorio

```
.
├── backend/                 # API FastAPI (submódulo)
│   ├── app/
│   │   ├── api/v1/         # Routers: auth, world, stocks, portfolio, learning, admin, news, leaderboard
│   │   ├── core/           # config, security, rate_limiter, redis_client, api_keys, exceptions
│   │   ├── models/base.py  # 11 modelos SQLAlchemy (User, Portfolio, Transaction, etc.)
│   │   ├── repositories/   # portfolio, leaderboard, user
│   │   ├── schemas/        # Pydantic v2 (portfolio, stock, user)
│   │   ├── services/       # auth, cache, email, exchange_rate, finnhub, news, pdf_report, redis_2fa
│   │   ├── db/             # session, init
│   │   └── main.py         # FastAPI app + middleware maintenance + APScheduler
│   ├── alembic/            # 5 migraciones
│   ├── tests/              # test_api.py (29 tests ~5% cobertura) + conftest.py
│   ├── requirements.txt    # ⚠️ incluye pytest (debería ir a requirements-dev.txt)
│   └── Dockerfile          # ⚠️ root, no multi-stage
│
├── frontend/                # SPA React (submódulo)
│   ├── src/
│   │   ├── pages/          # Dashboard, Login, Register, Stocks, Portfolio, Transactions, Learn, Admin, etc.
│   │   ├── components/     # layout/ (Header, Footer), ui/ (LoadingSpinner), GuidedTour, OnboardingModal, SEOHead
│   │   ├── context/        # ⚠️ VACÍO
│   │   ├── provider/       # AuthProvider, ThemeProvider, LanguageProvider
│   │   ├── services/       # api.ts (axios con interceptor 401)
│   │   ├── store/          # useStore (Zustand persist), tourStore
│   │   ├── utils/          # ⚠️ VACÍO — código duplicado en páginas
│   │   ├── locales/        # es.json, en.json (438 líneas c/u)
│   │   └── App.tsx         # Rutas + lazy loading
│   ├── public/             # manifest.json, sw.js, robots.txt
│   ├── tailwind.config.js
│   └── vite.config.ts
│
├── nginx/                   # Reverse proxy
│   ├── nginx.conf           # ⚠️ incompleto (sin rate limit) — CANÓNICO
│   ├── nginx_backup.conf    # ⚠️ ELIMINAR — duplicado peligroso con rate limit
│   ├── includes/security.conf  # Headers de seguridad + CSP
│   └── Dockerfile
│
├── docker-compose.yml       # db, redis, backend, frontend, nginx
├── .env / .env.example      # ⚠️ secretos reales en /.env (ROTAR URGENTE)
├── docs/                    # technical.md, user-manual.md, development-guide.md
├── DOKPLOY_DEPLOYMENT.md
├── .agents/skills/          # accessibility, frontend-design, seo (skills locales)
└── FIF.md                   # Issues + plan de remediación en 5 fases
```

---

## 3. Convenciones obligatorias

### Idioma y estilo
- **Código**: identificadores, comentarios, mensajes de error → **inglés**.
- **UI visible al usuario**: **español** (usar `t('clave.i18n')`, nunca strings hardcoded).
- **Commits**: Conventional Commits (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`).
- **Branches**: `feature/xxx`, `fix/xxx`, `refactor/xxx`, `hotfix/xxx`.

### Backend
- **Async siempre**: `async def`, `await`, `AsyncSession`. Nunca código bloqueante en endpoints.
- **Auth**: `Depends(get_current_user)` para validar, `Depends(get_current_username)` SOLO si no se necesita `is_active`.
- **Pydantic v2**: usar `Field(..., min_length, max_length, pattern)`, `EmailStr`, `SecretStr` para secretos.
- **Transacciones**: `with_for_update()` al modificar `User.balance` o `Portfolio`. Validar `is_active` en cada operación sensible.
- **Errores**: `HTTPException(status_code, detail)` con mensaje en inglés. Logs estructurados en `logger.warning/error`.
- **Rate limit**: `@limiter.limit("X/minute")` en TODO endpoint público o sensible.
- **No hardcodear**: URLs, secretos, valores de config. Usar `settings.X` de `app/core/config.py`.

### Frontend
- **Tipado estricto**: NUNCA `any`. ESLint lo permite (`'off'`) pero es deuda. Tipar con `interface`.
- **Persistencia auth**: SOLO Zustand `persist` con `partialize`. Eliminar `localStorage.getItem('user'|'token')` en páginas.
- **Navegación**: `useNavigate()` o `<Link to>`. **PROHIBIDO** `window.location.href` (rompe SPA).
- **Accesibilidad**: TODO elemento interactivo necesita `aria-label` o texto visible. Modales con `role="dialog"`, `aria-modal="true"`, `aria-labelledby`, focus trap, cierre con `Escape`.
- **i18n**: `t('namespace.key')` para todo texto visible. Añadir clave en `es.json` y `en.json`. **NO** usar `.toLowerCase()` sobre traducciones.
- **Loading/Error states**: cada `fetch` debe manejar `loading`, `error`, `empty`. Usar `<EmptyState />`, `<ErrorState />` reutilizables (crear en `src/components/ui/`).
- **Cleanup**: `useEffect` con cleanup. `AbortController.signal` en `axios.get/post`. `URL.revokeObjectURL` tras crear object URLs.
- **Formularios**: validación con `zod` (ya está en deps). Schema compartido entre Register y ResetPassword.
- **Componentes compartidos**: `src/components/ui/` debe tener `Spinner`, `Modal`, `EmptyState`, `ErrorBoundary`, `ConfirmDialog`, `Toast`. Eliminar duplicación.

### Docker
- **No root**: `USER appuser` en todos los Dockerfiles.
- **Multi-stage**: build deps separados de runtime.
- **`.dockerignore`**: presente. Verificar antes de cada build.
- **No expandir secrets en env**: usar `env_file` con `chmod 600`, o Docker `secrets:`.

---

## 4. Comandos esenciales

```bash
# Backend
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload --port 8000
pytest -v                              # tests
pytest --cov=app --cov-fail-under=60   # con cobertura

# Frontend
cd frontend
npm install
npm run dev                            # http://localhost:5173
npm run build
npm run lint

# Docker (raíz)
docker compose up -d --build
docker compose logs -f backend
docker compose exec backend alembic upgrade head
curl http://localhost/health
```

---

## 5. Workflow de cambios (CI/CD + sync)

### Flujo normal (automático)

```bash
git add -A && git commit -m "feat: ..." && git push origin main
# → GitHub Actions corre lint → test → build → deploy a EC2 automáticamente
```

### Si editas backend o frontend (son submódulos separados)

```bash
# 1. Commitear cada submódulo por separado
git -C backend add -A && git -C backend commit -m "fix: ..." && git -C backend push
git -C frontend add -A && git -C frontend commit -m "fix: ..." && git -C frontend push

# 2. Actualizar referencias en el repo principal
git add backend frontend
git commit -m "feat: implementar X"
git push origin main
# → CI/CD deploya todo
```

### Emergencia (si CI falla o deploy manual urgente)

```bash
./scripts/deploy.sh
# Requiere: PEM_FILE en ~/Documentos/Estudios/UP/.../simulador-finances.pem
```

### Reglas de oro

| Regla | Razón |
|---|---|
| **Siempre push a `main`** | El CI/CD solo deploya `main` |
| **Nunca editar directo en EC2** | Se pierde en el próximo deploy |
| **Hard refresh (Ctrl+F5)** tras deploy | Browser cache puede mostrar versión vieja |
| **Revisar Actions tab** si algo falla | https://github.com/personalbuse/simulador-inversiones/actions |
| **Submodules requieren 2 commits** | Uno dentro del submodule, otro en el main repo |
| **Verificar `.env` no está staged** | `git status` antes de cada commit |

### Pre-commit checklist

```bash
cd backend && ruff check .
cd frontend && npm run lint
git status  # confirmar que NO hay .env, test-results/ ni archivos sensibles
```

---

## 6. Reglas de seguridad innegociables

1. **NUNCA** commitear `.env` ni archivos con secretos. Verificar con `git status` antes de cada commit.
2. **NUNCA** loguear tokens, passwords, API keys. Usar `logger.info` sin payload sensible.
3. **NUNCA** confiar en `X-Forwarded-For` sin proxy verificado. Usar `request.client.host` por defecto.
4. **NUNCA** incluir `rol` o `is_active` en JWT payload. Re-leer de DB en cada request crítico.
5. **NUEVO endpoint sensible** → requiere: rate limit, validación Pydantic, auth check, log de auditoría.
6. **NUEVO endpoint admin** → requiere: `require_admin` con re-lectura de DB, rate limit, log en `admin_logs`.
7. **Secretos en tránsito** → solo HTTPS (forzado por nginx) o localhost.
8. **Passwords** → bcrypt rounds ≥ 12, min_length=12 + complejidad. Verificar con `validate_password_strength`.

---

## 7. Áreas que necesitan atención prioritaria

> Ver `FIF.md` para el detalle completo de las 5 fases de remediación.

| Fase | Categoría | Issues | Estado |
|---|---|---|---|
| **1** | Seguridad | 8 críticos + 14 altos | 🔴 URGENTE |
| **2** | Optimización | 12 issues | 🟠 Importante |
| **3** | Usabilidad | 22 issues | 🟡 Mejora |
| **4** | Diseño y Responsividad | 18 issues | 🟡 Mejora |
| **5** | Bugs y Duplicidad | 26 issues | 🟠 Importante |

**Bloqueantes inmediatos** (de `FIF.md`):
- Rotar secretos en `/.env` y `backend/.env` (Finnhub, Resend, ExchangeRate, NeonDB, JWT SECRET_KEY).
- `git rm --cached` de `.env` + purgar del historial con `git filter-repo`.
- Eliminar `nginx/nginx_backup.conf` (duplicación con config canónica).
- Agregar `is_active` check en `portfolio.buy/sell` (CRÍTICO).
- Corregir memory leak en `GuidedTour.tsx:49-53`.

---

## 8. LSP & MCP configuration

### LSP (Language Server Protocol) — `.vscode/settings.json`

| LSP | Archivo | Propósito |
|---|---|---|
| Ruff | `charliermarsh.ruff` | Linting + formatting Python (native server) |
| TypeScript | Bundled in `frontend/node_modules` | Type checking, refactors, imports |
| ESLint | `dbaeumer.vscode-eslint` | JS/TS linting on save |
| TailwindCSS | `bradlc.vscode-tailwindcss` | Class completion, CSS preview |
| Pylance | `ms-python.vscode-pylance` | Python intellisense, type checking (basic) |
| YAML | `redhat.vscode-yaml` | Docker compose, GitHub Actions schemas |

**Comportamiento**: formatOnSave para Python (Ruff) y frontend (Prettier). Organize imports automático. Ruff native server para respuesta rápida.

### MCP (Model Context Protocol) — `.opencode.jsonc`

| MCP Server | Rol | Enabled |
|---|---|---|
| `filesystem` | Acceso RW al workspace | ✅ |
| `github` | Git status, diff, log, commit, push, PRs | ✅ |
| `web-search` | Búsqueda externa para referencias | ✅ (max 5) |

### Agents configurados en `.opencode.jsonc`

| Agent | Especialidad |
|---|---|
| `backend-dev` | Python/FastAPI async, DB, security |
| `frontend-dev` | React/TypeScript, Zustand, Tailwind |
| `code-review` | PR review — seguridad, tipado, i18n |
| `security-review` | Auditoría de seguridad |
| `docs-writer` | Documentación técnica |

### Permisos

| Recurso | Allow | Deny |
|---|---|---|
| Files | `workspace/**` | `.env`, `node_modules`, `__pycache__` |
| Commands | `npm *`, `pytest`, `ruff`, `git`, `docker compose` | `sudo`, `rm -rf`, `git push --force` |

---

## 9. Skills locales disponibles

Skills en `.agents/skills/` (usar `skill` para cargarlas):

| Skill | Uso |
|---|---|
| **`python-backend`** | FastAPI, SQLAlchemy, Pydantic v2, async patterns |
| **`react-frontend`** | React 18, TypeScript, Zustand, Tailwind, i18n |
| **`docker-infra`** | Docker Compose, nginx, CI/CD |
| **`token-efficiency`** | Patrones de ahorro de tokens para prompts AI |
| **`accessibility`** | Auditorías WCAG 2.2 |
| **`frontend-design`** | UI distintiva, evita estética IA genérica |
| **`seo`** | Meta tags, structured data, sitemap |
| **`caveman`** | Comunicación comprimida (-75% tokens) |
| **`caveman-commit`** | Commits concisos Conventional Commits |

---

## 10. Anti-patrones prohibidos

| ❌ No hacer | ✅ Hacer en su lugar |
|---|---|
| `window.location.href = '/login'` | `navigate('/login', { replace: true })` |
| `localStorage.getItem('user')` en páginas | Zustand `useStore(state => state.user)` |
| `JSON.parse(localStorage.getItem('user') \|\| '{}')` | `try/catch` + Zustand + tipos |
| `useState<any>` | `useState<User \| null>` con interface |
| `fetch('/api/v1/...')` inline | `api.get/post(...)` de `services/api.ts` |
| `// eslint-disable-next-line` masivo | Refactor con `useCallback` + deps correctas |
| `<div onClick={handler}>` | `<button onClick={handler}>` o `<Link to>` |
| `setTimeout(() => navigate(...), 3000)` sin cleanup | `useRef + useEffect` con cleanup |
| Strings hardcoded en español | `t('namespace.key')` + clave en `es.json` y `en.json` |
| `alert('mensaje')` | `toast.error('mensaje')` con `react-toastify` |
| `@limiter.limit` solo en auth | Aplicar a TODO endpoint público/admin |
| `<input>` sin label | `<label htmlFor>` o `aria-label` |
| `Math.random()` en componentes | `useMemo` con datos del backend o flag `MOCK` visible |

---

## 11. Token efficiency patterns

### Estructura de prompts
```
Contexto: <1-2 lines linking to skill/doc>
Task: <1 line what>
Files: <paths to touch>
Constraints: <1 line rules from AGENTS.md>
Verify: <command to run>
```

### Caveman mode
- Eliminar artículos, sujetos, verbos auxiliares.
- Referencias: `file:line` en vez de copiar código.
- Skills reutilizables > repetir reglas en cada mensaje.

### Pre-commit

```bash
# Backend
cd backend && ruff check . && mypy app/ && pytest -v

# Frontend
cd frontend && npm run lint && npm run build

# Seguridad
gitleaks detect --no-banner
git status  # verificar .env no está staged
```

---

## 12. Glosario del dominio

- **Portafolio**: conjunto de acciones poseídas por un usuario + balance en USD.
- **Índice bursátil**: indicador de un mercado (S&P 500, IBOVESPA, IPC).
- **Stock/Acción**: título de una empresa transable (AAPL, TSLA, MSFT).
- **Forex/Divisa**: par de monedas (USD/COP, EUR/USD).
- **Leaderboard**: ranking de rentabilidad entre usuarios.
- **Onboarding**: flujo inicial que da $10,000 USD virtuales al registrarse.
- **Módulo de aprendizaje**: lección (`m1`–`m6`) que otorga +$1,000 USD al completarse.
- **Maintenance mode**: estado admin-only donde usuarios no-admin reciben 503.

---

**Última actualización**: 2026-06-14 · **Versión**: 1.1 · **Auditoría**: `FIF.md`
