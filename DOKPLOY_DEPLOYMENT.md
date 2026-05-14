# Dokploy deployment

Este proyecto debe desplegarse como servicios separados: frontend, backend, Redis y PostgreSQL.

## Backend

Variables obligatorias:

```env
DATABASE_URL=postgresql+asyncpg://USER:PASSWORD@HOST:5432/DB
REDIS_URL=redis://HOST:6379/0
SECRET_KEY=valor-largo-aleatorio
FINNHUB_API_KEY=...
EXCHANGE_RATE_API_KEY=...
ENVIRONMENT=production
FRONTEND_URL=https://tu-dominio.com
CORS_ORIGINS=https://tu-dominio.com,https://www.tu-dominio.com
RESEND_API_KEY=...
EMAIL_FROM=Simulador Inversiones <noreply@tu-dominio.com>
```

Variables opcionales:

```env
ADMIN_API_KEY=valor-largo-aleatorio
ENABLE_STARTUP_PRELOAD=true
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

Los endpoints administrativos de stocks responden 404 si `ADMIN_API_KEY` no está configurada. Si se usa, enviar `X-Admin-Token` con ese valor.

## Frontend

Si el frontend consume el backend mediante el mismo dominio y proxy `/api/v1`, no es obligatorio configurar `VITE_API_URL`.
En ese caso, configura `BACKEND_UPSTREAM` en el servicio frontend si el servicio backend no se llama `backend` dentro de la red de Dokploy:

```env
BACKEND_UPSTREAM=http://backend:8000
```

Si se usa dominio/subdominio separado:

```env
VITE_API_URL=https://api.tu-dominio.com/api/v1
```

Recuerda que las variables `VITE_*` se aplican en tiempo de build, así que requieren reconstruir el frontend.

## Infraestructura

- No exponer Redis ni PostgreSQL públicamente.
- Abrir al exterior solo 80/443 y SSH restringido.
- Activar backups del volumen de PostgreSQL.
- Rotar `SECRET_KEY` y `ADMIN_API_KEY` si alguna vez se compartieron.
