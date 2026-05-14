# 🔧 Guía de Desarrollo - Simulador de Inversiones

## Tabla de Contenidos

1. [¿Qué es esta aplicación?](#qué-es-esta-aplicación)
2. [Propósito Educativo](#propósito-educativo)
3. [Requisitos Previos](#requisitos-previos)
4. [Setup Local](#setup-local)
5. [Estructura del Código](#estructura-del-código)
6. [Migraciones de Base de Datos](#migraciones-de-base-de-datos)
7. [Convenciones de Código](#convenciones-de-código)
8. [Cómo Contribuir](#cómo-contribuir)
9. [Troubleshooting](#troubleshooting)

---

## 1. ¿Qué es esta aplicación?

El **Simulador de Inversiones** es una aplicación web que permite a estudiantes de finanzas practicar con operaciones bursátiles sin riesgo real. Es un entorno de aprendizaje donde los usuarios pueden:

- 📊 **Analizar mercados**: Ver cotizaciones de acciones, índices y divisas reales
- 💰 **Invertir virtualmente**: Comprar y vender con $100,000 USD virtuales
- 📈 **Evaluar estrategias**: Comparar su rendimiento con otros inversores
- 📄 **Generar reportes**: Descargar resúmenes en PDF de su portafolio

### Para quién está diseñada
- Estudiantes de la materia **Finanzas Internacionales** de la Universidad de Pamplona (UP)
- Cualquier persona interesada en aprender sobre mercados financieros

---

## 2. Propósito Educativo

### Objetivos de aprendizaje
1. **Comprensión de mercados**: Entender cómo funcionan las bolsas de valores
2. **Gestión de riesgo**: Aprender a diversificar inversiones
3. **Análisis de rendimiento**: Medir éxito de estrategias de inversión
4. **Toma de decisiones**: Practicar análisis fundamental y técnico

### Conceptos aplicados
- 📈 **Portafolio**: Conjunto de inversiones
- 📊 **Diversificación**: No poner todos los huevos en una canasta
- 📉 **Ganancia/Perdida**: Diferencia entre precio de compra y venta
- 💱 **Divisas**: Conversión entre monedas

---

## 3. Requisitos Previos

### Software necesario
| Componente | Versión mínima |
|------------|----------------|
| Python | 3.12 |
| Node.js | 20.x |
| PostgreSQL | 16.x |
| Redis | 7.x |
| Git | 2.x |

### Herramientas recomendadas
- **Editor**: VS Code con extensiones Python, ESLint, Prettier
- **Terminal**: iTerm2 (Mac) / Windows Terminal (Windows)
- **Docker**: Para desarrollo sin instalar dependencias

---

## 4. Setup Local

### Opción A: Con Docker (Recomendado)

```bash
# 1. Clonar el repositorio
git clone https://github.com/tu-usuario/simulador-inversiones.git
cd simulador-inversiones

# 2. Copiar configuración
cp .env.example .env
# Edita .env con tus API keys

# 3. Iniciar servicios
docker compose up -d

# 4. Verificar
curl http://localhost/api/v1/health
```

### Opción B: Sin Docker

#### Backend
```bash
cd backend

# Crear entorno virtual
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows

# Instalar dependencias
pip install -r requirements.txt

# Configurar base de datos
# Asegúrate de tener PostgreSQL y Redis corriendo

# Ejecutar migraciones
alembic upgrade head

# Iniciar servidor
uvicorn app.main:app --reload --port 8000
```

#### Frontend
```bash
cd frontend

# Instalar dependencias
npm install

# Iniciar desarrollo
npm run dev
```

### Variables de entorno requeridas
```env
DATABASE_URL=postgresql://user:pass@localhost:5432/simulador
REDIS_URL=redis://localhost:6379/0
FINNHUB_API_KEY=tu_api_key
EXCHANGE_RATE_API_KEY=tu_api_key
SECRET_KEY=tu_clave_secreta
```

---

## 5. Estructura del Código

### Backend (`backend/app/`)

```
backend/app/
├── api/v1/              # Endpoints REST
│   ├── auth.py          # Autenticación
│   ├── portfolio.py     # Portafolio
│   ├── stocks.py        # Acciones
│   ├── world.py         # Índices/Divisas
│   ├── news.py          # Noticias
│   └── leaderboard.py  # Ranking
│
├── core/               # Configuración central
│   ├── config.py       # Variables de entorno
│   ├── security.py     # JWT
│   ├── rate_limiter.py # Rate limiting
│   └── exceptions.py   # Errores personalizados
│
├── models/             # Modelos SQLAlchemy
│   └── base.py         # User, Portfolio, etc.
│
├── repositories/       # Acceso a datos
│   ├── portfolio_repository.py
│   └── leaderboard_repository.py
│
├── schemas/            # Pydantic models
│   └── *.py
│
├── services/           # Lógica de negocio
│   ├── finnhub_service.py    # Stocks API
│   ├── exchange_rate_service.py
│   ├── cache_service.py
│   └── pdf_report_service.py
│
└── db/
    ├── session.py      # Conexión DB
    └── __init__.py
```

### Frontend (`frontend/src/`)

```
frontend/src/
├── pages/              # Componentes de página
│   ├── Dashboard.tsx
│   ├── Portfolio.tsx
│   ├── Markets.tsx
│   ├── Indices.tsx
│   ├── Forex.tsx
│   ├── Leaderboard.tsx
│   └── Login.tsx
│
├── components/         # Componentes reutilizables
│   ├── layout/
│   │   ├── Header.tsx
│   │   └── Footer.tsx
│   └── ui/
│       ├── Button.tsx
│       └── Card.tsx
│
├── services/           # Llamadas API
│   └── api.ts         # Axios + interceptors
│
├── store/             # Estado global
│   └── useStore.ts    # Zustand
│
└── i18n/              # Internacionalización
    └── index.ts       # Config i18next
```

---

## 6. Migraciones de Base de Datos

### Crear nueva migración
```bash
cd backend
alembic revision -m "descripcion_de_cambio"
```

### Editar migración
Editar el archivo generado en `alembic/versions/`

### Aplicar migraciones
```bash
# Desarrollo
alembic upgrade head

# Produccion
alembic upgrade head

# Rollback (cuidado en producción)
alembic downgrade -1
```

---

## 7. Convenciones de Código

### Python (Backend)
- **PEP 8**: Style guide
- **Type hints**: Usar siempre que sea posible
- **Async/Await**: Preferir async sobre sync
- **Nombres**: `snake_case` para funciones/variables, `PascalCase` para clases
- **Imports**: Primero stdlib, luego第三方, luego locales

```python
# ✅ Correcto
async def get_portfolio(user_id: int) -> List[Portfolio]:
    """Obtiene el portafolio de un usuario."""
    ...

# ❌ Incorrecto
async def getPortfolio(id):
    ...
```

### TypeScript/React (Frontend)
- **ESLint + Prettier**: Configuración automática
- **Hooks**: Usar functional components con hooks
- **Naming**: `camelCase` para variables, `PascalCase` para componentes

```tsx
// ✅ Correcto
const PortfolioPage: React.FC = () => {
  const { portfolio } = usePortfolio();
  return <div>{portfolio.length} posiciones</div>;
}
```

---

## 8. Cómo Contribuir

### Flujo de trabajo
1. **Fork** del repositorio
2. Crear **rama** para tu feature: `git checkout -b feature/nueva-funcionalidad`
3. **Desarrollar** con tests
4. **Commits** con mensajes claros: `git commit -m "feat: nueva funcionalidad"`
5. **Push** a tu fork: `git push origin feature/nueva-funcionalidad`
6. Crear **Pull Request**

### Commits convencionales
```
feat:     Nueva funcionalidad
fix:      Corrección de bug
docs:     Documentación
refactor: Refactorización
test:     Tests
chore:    Mantenimiento
```

### testing
```bash
# Backend
pytest

# Frontend
npm run lint
npm run build
```

---

## 9. Troubleshooting

### Error: "Cannot connect to database"
```bash
# Verificar PostgreSQL
pg_isready -h localhost -p 5432

# Verificar string de conexión
echo $DATABASE_URL
```

### Error: "Redis connection refused"
```bash
# Verificar Redis
redis-cli ping

# Iniciar si no corre
redis-server
```

### Error: "API key inválida"
```bash
# Verificar que las keys estén en .env
# Regenerar keys en los portales de cada servicio
```

### Error: "Port already in use"
```bash
# Encontrar proceso usando el puerto
lsof -i :8000
# O cambiar el puerto en .env
```

### Ver logs
```bash
# Docker
docker compose logs -f backend

# Local (backend)
uvicorn app.main:app --log-level debug
```

---

## Contacto

**Profesor**: Finanzas Internacionales - Universidad de Pamplona
**Email**: finanzas@up.edu.co

---

*Guía de desarrollo - Simulador de Inversiones - UP*