#!/usr/bin/env bash
# scripts/pre-commit.sh - Run pre-commit checks

set -euo pipefail

echo "🔒 Running pre-commit checks..."

# Format
./scripts/format.sh

# Lint
./scripts/lint.sh

# Test (quick)
echo "📦 Quick tests..."
cd backend && source venv/bin/activate && pytest -x -q
cd ../frontend && pnpm test --run --reporter=dot

echo ""
echo "✅ All pre-commit checks passed!"