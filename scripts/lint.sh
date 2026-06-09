#!/usr/bin/env bash
# scripts/lint.sh - Run all linters and formatters

set -euo pipefail

echo "🔍 Running linters..."

# Backend lint
echo "📦 Backend lint..."
cd backend
source venv/bin/activate
ruff check .
mypy app/
echo "✅ Backend lint passed"

# Frontend lint
echo "📦 Frontend lint..."
cd ../frontend
pnpm lint
echo "✅ Frontend lint passed"

echo ""
echo "🎉 All linters passed!"