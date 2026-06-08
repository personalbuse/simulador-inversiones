---
name: docker-infra
description: Docker Compose, Nginx, and deployment configuration for the FIUP simulator project. Use for Dockerfiles, compose, nginx, CI/CD.
license: MIT
metadata:
  author: fiup
  version: "1.0"
---

# Docker & Infra — Docker Compose + Nginx + Dokploy

## Stack
- Docker Compose: db (PostgreSQL 16), redis (7), backend, frontend (nginx), nginx
- Reverse proxy: nginx con rate limiting + SSL + proxy cache
- Deploy: Dokploy / AWS EC2

## Dockerfile rules
- **No root**: `USER appuser` siempre
- **Multi-stage**: build deps separados de runtime
- **HEALTHCHECK**: presente en servicios críticos
- **`.dockerignore`**: excluir node_modules, __pycache__, .venv, .env

## Nginx rules
- Rate limiting en `/api/` (30 req/min por IP)
- Proxy cache para assets estáticos (1h)
- Security headers: HSTS, X-Frame-Options, X-Content-Type-Options, CSP
- Deny acceso a archivos ocultos (`.env`, `.git`, etc.)
- SSL solo en producción

## Comandos
```bash
docker compose up -d --build
docker compose logs -f backend
docker compose exec backend alembic upgrade head
curl http://localhost/health
```
