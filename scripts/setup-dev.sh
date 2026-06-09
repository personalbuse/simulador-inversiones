#!/usr/bin/env bash
# scripts/setup-dev.sh - Quick development environment setup

set -euo pipefail

echo "🔧 Setting up development environment..."

# Check for required tools
command -v python3 >/dev/null 2>&1 || { echo "❌ python3 not found"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ node not found"; exit 1; }
command -v pnpm >/dev/null 2>&1 || { echo "Installing pnpm..."; npm install -g pnpm; }
command -v docker >/dev/null 2>&1 || { echo "❌ docker not found"; exit 1; }

echo "✅ All required tools found"

# Backend setup
echo "📦 Setting up backend..."
cd backend
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
echo "✅ Backend ready"

# Frontend setup
echo "📦 Setting up frontend..."
cd ../frontend
pnpm install
echo "✅ Frontend ready"

# Database setup
echo "🗄️  Setting up database..."
cd ../backend
source venv/bin/activate
alembic upgrade head
echo "✅ Database migrated"

echo ""
echo "🎉 Development environment ready!"
echo ""
echo "To start developing:"
echo "  make dev          # Start all services with Docker"
echo "  make frontend-dev # Frontend only (port 5173)"
echo "  make test         # Run all tests"
echo "  make lint         # Run linters"