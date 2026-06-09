#!/usr/bin/env bash
# scripts/format.sh - Format all code

set -euo pipefail

echo "🎨 Formatting code..."

# Backend format
echo "📦 Backend format..."
cd backend
source venv/bin/activate
ruff format .
ruff check --fix .
echo "✅ Backend formatted"

# Frontend format
echo "📦 Frontend format..."
cd ../frontend
pnpm format
echo "✅ Frontend formatted"

echo ""
echo "🎉 All code formatted!"