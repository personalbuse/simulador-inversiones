#!/usr/bin/env bash
# scripts/test.sh - Run all tests with coverage

set -euo pipefail

echo "🧪 Running tests..."

# Backend tests
echo "📦 Backend tests..."
cd backend
source venv/bin/activate
pytest -v --cov=app --cov-report=term-missing --cov-report=html --cov-fail-under=70 "$@"
echo "✅ Backend tests passed"

# Frontend tests
echo "📦 Frontend tests..."
cd ../frontend
pnpm test --run --coverage "$@"
echo "✅ Frontend tests passed"

echo ""
echo "🎉 All tests passed!"
echo "📊 Coverage reports available at:"
echo "  backend/htmlcov/index.html"
echo "  frontend/coverage/index.html"