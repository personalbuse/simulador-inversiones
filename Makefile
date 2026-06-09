.PHONY: help install dev test lint format clean build up down logs

# Default target
help:
	@echo "Simulador FIUP - Development Commands"
	@echo ""
	@echo "  make install     - Install all dependencies (backend + frontend)"
	@echo "  make dev         - Start development environment (docker-compose)"
	@echo "  make test        - Run all tests"
	@echo "  make test-backend  - Run backend tests only"
	@echo "  make test-frontend - Run frontend tests only"
	@echo "  make lint        - Run all linters"
	@echo "  make format      - Format all code"
	@echo "  make clean       - Clean build artifacts and caches"
	@echo "  make build       - Build production images"
	@echo "  make up          - Start docker-compose services"
	@echo "  make down        - Stop docker-compose services"
	@echo "  make logs        - View docker-compose logs"

# Install dependencies
install:
	cd backend && python -m venv venv && source venv/bin/activate && pip install -r requirements.txt
	cd frontend && pnpm install

# Development
dev:
	docker-compose -f docker-compose.yml -f docker-compose.override.yml up --build

up:
	docker-compose -f docker-compose.yml -f docker-compose.override.yml up -d

down:
	docker-compose -f docker-compose.yml -f docker-compose.override.yml down

logs:
	docker-compose -f docker-compose.yml -f docker-compose.override.yml logs -f

# Testing
test: test-backend test-frontend

test-backend:
	cd backend && source venv/bin/activate && pytest -v --cov=app --cov-report=term-missing --cov-fail-under=70

test-frontend:
	cd frontend && pnpm test --run

# Linting
lint: lint-backend lint-frontend

lint-backend:
	cd backend && source venv/bin/activate && ruff check . && mypy app/

lint-frontend:
	cd frontend && pnpm lint

# Formatting
format: format-backend format-frontend

format-backend:
	cd backend && source venv/bin/activate && ruff format . && ruff check --fix .

format-frontend:
	cd frontend && pnpm format

# Build
build:
	docker-compose -f docker-compose.yml -f docker-compose.override.yml build

# Clean
clean:
	docker-compose -f docker-compose.yml -f docker-compose.override.yml down -v
	rm -rf backend/venv backend/__pycache__ backend/.pytest_cache
	rm -rf frontend/node_modules frontend/dist frontend/.vite
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true

# Database
db-migrate:
	cd backend && source venv/bin/activate && alembic upgrade head

db-migration:
	cd backend && source venv/bin/activate && alembic revision --autogenerate -m "$(MSG)"

db-seed:
	cd backend && source venv/bin/activate && python -m app.db.seed

# Frontend specific
frontend-dev:
	cd frontend && pnpm dev

frontend-build:
	cd frontend && pnpm build

frontend-preview:
	cd frontend && pnpm preview