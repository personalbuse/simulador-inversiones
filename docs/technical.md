# 📚 Manual Técnico - Simulador de Inversiones

## Tabla de Contenidos

1. [Arquitectura](#arquitectura)
2. [Stack Tecnológico](#stack-tecnológico)
3. [Estructura del Repositorio](#estructura-del-repositorio)
4. [Modelo de Datos](#modelo-de-datos)
5. [API Endpoints](#api-endpoints)
6. [Servicios](#servicios)
7. [Estrategia de Caché](#estrategia-de-caché)
8. [Seguridad](#seguridad)
9. [Despliegue](#despliegue)

---

## 1. Arquitectura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              CLIENTE                                     │
│  Navegador Web (React SPA)                                               │
└────────────────────────────┬────────────────────────────────────────────┘
                             │ HTTPS :443
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           NGINX (Puerto 80/443)                         │
│  • SSL/TLS Termination                                                   │
│  • Reverse Proxy (/api → backend, / → frontend)                        │
│  • Rate Limiting                                                         │
│  • Compression (gzip/brotli)                                            │
│  • Security Headers                                                      │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │         Docker Network       │
              ▼                               ▼
┌─────────────────────────┐   ┌─────────────────────────────────────────┐
│      FRONTEND           │   │              BACKEND                    │
│   Puerto 3000 (exp)      │   │         Puerto 8000 (exp)               │
│                         │   │                                         │
│   - React 18            │   │   - FastAPI                              │
│   - Static files       │   │   - SQLAlchemy async                    │
│   - SPA routing        │   │   - Uvicorn                              │
└─────────────────────────┘   └────────────────────┬──────────────────────┘
                                                  │
                         ┌─────────────────────────┼─────────────────────────┐
                         ▼                         ▼                         ▼
               ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
               │  PostgreSQL      │     │      Redis       │     │   Finnhub API   │
               │  Puerto 5432     │     │   Puerto 6379    │     │   (External)     │
               │                 │     │                  │     │                  │
               │  - Users        │     │  - Cache         │     │  - Stocks        │
               │  - Portfolio    │     │  - Sessions      │     │  - News          │
               │  - Transactions │     │                  │     │                  │
               │  - Rates        │     │                  │     │                  │
               └──────────────────┘     └──────────────────┘     └──────────────────┘
```

## 2. Stack Tecnológico

| Componente | Tecnología | Versión |
|------------|------------|---------|
| Backend Framework | FastAPI | 0.135.x |
| ORM | SQLAlchemy | 2.0.x (async) |
| Base de Datos | PostgreSQL | 16-alpine |
| Caché | Redis | 7-alpine |
| Frontend | React | 18.2.x |
| Build Tool | Vite | 5.x |
| UI Framework | TailwindCSS | 3.4.x |
| Servidor Web | Nginx | alpine |
| Contenedores | Docker Compose | 2.x |
|Scheduler | APScheduler | 3.10.x |

## 3. Estructura del Repositorio

```
simulador-inversiones/
├── backend/
│   ├── app/
│   │   ├── api/v1/           # Endpoints REST
│   │   │   ├── auth.py       # Autenticación
│   │   │   ├── portfolio.py  # Portafolio usuario
│   │   │   ├── stocks.py     # Acciones
│   │   │   ├── world.py      # Índices/divisas
│   │   │   ├── news.py       # Noticias
│   │   │   └── leaderboard.py
│   │   ├── core/
│   │   │   ├── config.py     # Configuración
│   │   │   ├── security.py   # JWT, auth
│   │   │   ├── rate_limiter.py
│   │   │   └── exceptions.py
│   │   ├── models/           # SQLAlchemy models
│   │   ├── repositories/    # Acceso a datos
│   │   ├── schemas/         # Pydantic schemas
│   │   └── services/        # Lógica de negocio
│   ├── alembic/             # Migraciones DB
│   ├── Dockerfile
│   └── requirements.txt
│
├── frontend/
│   ├── src/
│   │   ├── pages/           # Páginas React
│   │   ├── components/      # Componentes
│   │   ├── services/        # API calls
│   │   ├── store/           # Zustand state
│   │   └── i18n/            # Internacionalización
│   ├── Dockerfile
│   └── package.json
│
├── nginx/
│   ├── nginx.conf           # Config principal
│   ├── includes/
│   │   └── security.conf
│   └── Dockerfile
│
├── docker-compose.yml
├── .env
└── README.md
```

## 4. Modelo de Datos

### User
```python
class User(Base):
    id: int (PK)
    username: str (unique)
    email: str (unique)
    hashed_password: str
    initial_balance: float (default: 100000.0)
    current_balance: float
    rol: str (default: "inversor")
    is_active: bool (default: True)
    created_at: datetime
    updated_at: datetime
```

### Portfolio
```python
class Portfolio(Base):
    id: int (PK)
    user_id: int (FK -> User)
    symbol: str
    quantity: float
    average_cost: float
    created_at: datetime
    updated_at: datetime
```

### Transaction
```python
class Transaction(Base):
    id: int (PK)
    user_id: int (FK -> User)
    symbol: str
    transaction_type: str (compra/venta)
    quantity: float
    price_per_unit: float
    total_amount: float
    currency: str (default: USD)
    created_at: datetime
```

### ExchangeRateHistory
```python
class ExchangeRateHistory(Base):
    id: int (PK)
    from_currency: str
    to_currency: str
    rate: float
    date: date
    created_at: datetime
```

### CacheData
```python
class CacheData(Base):
    id: int (PK)
    key: str (unique)
    value: text
    expires_at: datetime
    created_at: datetime
```

## 5. API Endpoints

### Autenticación
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/api/v1/auth/register` | Registrar usuario |
| POST | `/api/v1/auth/login` | Iniciar sesión |
| GET | `/api/v1/auth/me` | Obtener usuario actual |

### Portfolio
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/v1/portfolio` | Obtener portafolio |
| GET | `/api/v1/portfolio/values` | Valor del portafolio |
| POST | `/api/v1/portfolio/buy` | Comprar acción |
| POST | `/api/v1/portfolio/sell` | Vender acción |
| GET | `/api/v1/portfolio/transactions` | Historial transacciones |
| GET | `/api/v1/portfolio/report` | Generar PDF |

### Acciones
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/api/v1/stocks/batch` | Múltiples acciones |
| GET | `/api/v1/stocks/{symbol}` | Una acción |
| GET | `/api/v1/stocks/{symbol}/history` | Histórico precio |

### Divisas
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/v1/exchange-rate` | Una tasa |
| GET | `/api/v1/exchange-rates/multi` | Múltiples tasas |
| GET | `/api/v1/exchange-rate/convert` | Conversor |

### Índices Mundiales
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/v1/indices` | Todos los índices |
| GET | `/api/v1/indices/{symbol}` | Un índice |
| GET | `/api/v1/indices?region=Europe` | Por región |

### Acciones Internacionales
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/v1/stocks/international` | Todas |
| GET | `/api/v1/stocks/international/{country}` | Por país |

### Noticias
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/v1/news` | Noticias generales |
| GET | `/api/v1/news/symbol/{symbol}` | Por símbolo |

### Leaderboard
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/v1/leaderboard` | Top 10 usuarios |
| GET | `/api/v1/leaderboard/me` | Mi posición |

## 6. Servicios

### FinnhubService
- **Responsabilidad**: Obtener cotizaciones de acciones y noticias
- **APIs externas**: Finnhub.io
- **Estrategia**:
  - Cache en Redis (24h)
  - Fallback a datos mock
  - Retry con backoff exponencial

### ExchangeRateService
- **Responsabilidad**: Tasas de cambio entre monedas
- **APIs externas**: ExchangeRate-API
- **Pares soportados**: USD, EUR, GBP, COP, MXN, BRL, CLP, PEN, ARS, JPY

### CacheService
- **Responsabilidad**: Caché genérico
- **Backend**: Redis (primario), PostgreSQL (fallback)
- **TTL**: Configurable por endpoint

### WorldIndicesService
- **Responsabilidad**: Índices bursátiles globales
- **Fuentes**: Finnhub (3 índices USA), fallback mock (resto)

### InternationalStocksService
- **Responsabilidad**: Acciones de mercados internacionales
- **Regiones**: NA, SA, Europa, Asia
- **Datos**: Mock con variación aleatoria

### PDFReportService
- **Responsabilidad**: Generar reportes PDF
- **Librería**: FPDF
- **Contenido**: Resumen cuenta + detalle portafolio

## 7. Estrategia de Caché

### Capas de caché

1. **Redis** (primario)
   - TTL configurable (default: 300s)
   - Keys con prefijo: `stock:`, `exchange:`, `news:`, `world_indices:`

2. **PostgreSQL** (fallback)
   - Tabla `cache_data`
   - Cuando Redis no disponible

### Endpoints con caché

| Endpoint | TTL | Key |
|----------|-----|-----|
| `/stocks/batch` | 24h | `stock:{symbol}` |
| `/exchange-rate` | 24h | `exchange:{from}:{to}` |
| `/exchange-rates/multi` | 1h | `exchange:multi:all` |
| `/indices` | 1h | `world_indices:all` |
| `/news` | 30m | `news:{category}:{limit}` |
| `/leaderboard` | 5min | `leaderboard:all` (in-memory) |

## 8. Seguridad

### Autenticación
- JWT con HMAC-SHA256
- Token en header `Authorization: Bearer {token}`
- Expiración: 30 minutos

### Rate Limiting
- SlowAPI con limitaciones por endpoint
- Stocks: 10/min, General: 60/min, Batch: 30/min
- Logueado: Límites más altos

### Headers de Seguridad (Nginx)
```
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
Strict-Transport-Security: max-age=31536000
```

### CORS
- Configurable por variable `CORS_ORIGINS`
- Producción: Solo dominio registrado

## 9. Despliegue

### Requisitos
- Ubuntu 22.04 LTS en EC2
- Docker 24+ y Docker Compose 2.20+
- 2 vCPU, 4GB RAM mínimo
- Puerto 80/443 abiertos en Security Group

### Pasos

1. **Preparar instancia**
```bash
sudo apt update && sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER
```

2. **Subir proyecto**
```bash
scp -r ./simulador-inversiones ubuntu@IP-EC2:/home/ubuntu/
```

3. **Configurar entorno**
```bash
cd /home/ubuntu/simulador-inversiones
cp .env.example .env
nano .env  # Configurar API keys, passwords
```

4. **Desplegar**
```bash
docker compose up -d --build
```

5. **Verificar**
```bash
docker compose ps
docker compose logs -f
curl http://localhost/health
```

### DNS (Cloudflare)
1. Crear cuenta Cloudflare
2. Añadir dominio
3. Crear registro A → IP EC2
4. Habilitar proxy (icono naranja)
5. SSL/TLS: Full Strict
6. Always HTTPS: ON

### Healthchecks

```yaml
# docker-compose.yml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

---

*Documento creado para el proyecto de Finanzas Internacionales - Universidad de Pamplona (UP)*