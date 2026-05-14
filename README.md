# 📈 Simulador de Inversiones - Finanzas Internacionales

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Stack](https://img.shields.io/badge/Stack-FastAPI%20%7C%20React%20%7C%20PostgreSQL%20%7C%20Redis-green.svg)](https://github.com/simulador-inversiones)
[![Platform](https://img.shields.io/badge/Platform-Docker%20Compose%20%7C%20AWS%20EC2-blue.svg)](#)

> Simulador bursátil educativo para el curso de **Finanzas Internacionales** de la **Universidad de Pamplona (UP), Colombia**.

## 🎯 ¿Qué es?

Simulador de inversión en mercados financieros que permite a estudiantes practicar con operaciones de compra y venta de acciones, divisas e índices mundiales, sin riesgo real. Diseñado para enseñar conceptos de inversión, análisis de portafolio y evaluación de rendimiento.

## 🚀 Características

- **35+ Acciones** de tecnológicas (Apple, Google, Tesla, Meta, etc.)
- **24 Índices Globales** (S&P 500, Dow Jones, Nasdaq, IPC México, IBOVESPA, etc.)
- **10 Pares de Divisas** (USD/COP, EUR/COP, USD/MXN, etc.)
- **Portfolio Personal** con compra/venta de acciones
- **Leaderboard** Ranking de rentabilidad por usuario
- **Reportes PDF** Descargables con resumen del portafolio
- **Noticias Financieras** Integradas con Finnhub
- **Autenticación JWT** segura

## 🛠️ Stack Tecnológico

| Capa | Tecnología |
|------|------------|
| **Backend** | FastAPI + SQLAlchemy (async) + Uvicorn |
| **Base de Datos** | PostgreSQL 16 + Redis 7 |
| **Frontend** | React 18 + TypeScript + Vite + TailwindCSS |
| **Despliegue** | Docker Compose + Nginx + AWS EC2 |
| **APIs** | Finnhub (stocks), ExchangeRate-API (divisas) |

## 📋 Requisitos

- Docker Engine 24+
- Docker Compose 2.20+
- 2GB RAM mínimo
- Puerto 80 y 443 disponibles

## 🏃‍♂️ Inicio Rápido

### 1. Clonar y configurar

```bash
git clone https://github.com/tu-usuario/simulador-inversiones.git
cd simulador-inversiones
cp .env.example .env
nano .env  # Configura tus API keys
```

### 2. Iniciar servicios

```bash
# Desarrollo (sin SSL)
docker compose up -d

# Producción (con SSL)
docker compose -f docker-compose.yml up -d --build
```

### 3. Verificar

```bash
docker compose ps          # Ver estado de servicios
docker compose logs -f     # Ver logs en tiempo real
curl http://localhost/health  # Health check
```

## 🌐 Estructura del Proyecto

```
simulador-inversiones/
├── backend/               # API FastAPI
│   ├── app/
│   │   ├── api/v1/       # Endpoints
│   │   ├── models/       # Modelos SQLAlchemy
│   │   ├── services/     # Lógica de negocio
│   │   └── core/         # Config, seguridad
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/              # SPA React
│   ├── src/
│   │   ├── pages/       # Componentes de página
│   │   ├── services/    # API calls
│   │   └── store/       # Estado global (Zustand)
│   └── Dockerfile
├── nginx/                # Reverse proxy
│   ├── nginx.conf        # Configuración principal
│   ├── includes/         # Headers de seguridad
│   └── Dockerfile
├── docker-compose.yml    # Orquestación
├── .env                  # Variables de entorno
└── README.md
```

## 📖 Documentación

| Documento | Descripción |
|-----------|-------------|
| [Manual Técnico](docs/technical.md) | Arquitectura, API, modelo de datos |
| [Manual de Usuario](docs/user-manual.md) | Cómo usar la aplicación |
| [Guía de Desarrollo](docs/development-guide.md) | Setup local, contribución |

## ☁️ Despliegue en AWS

Consulta la [guía de despliegue](./docs/technical.md#despliegue-en-aws) para desplegar en una instancia EC2 con Docker Compose.

### Configuración rápida

```bash
# En tu instancia EC2 con Ubuntu:
sudo apt update && sudo apt install -y docker.io docker-compose

# Subir archivos:
scp -r ./simulador-inversiones user@tu-ip-ec2:/home/ubuntu/

# Ejecutar:
cd /home/ubuntu/simulador-inversiones
docker compose up -d --build
```

## 📝 Licencia

MIT License - Universidad de Pamplona (UP), Colombia.

---

**⚠️ Disclaimer**: Esta aplicación es con fines educativos para el curso de Finanzas Internacionales. Las cotizaciones son en tiempo real pero las operaciones no representan inversiones reales.