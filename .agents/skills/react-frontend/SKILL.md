---
name: react-frontend
description: React 18 + TypeScript 5.3 + Zustand + TailwindCSS 3.4 development. Use for frontend components, pages, state management, styling.
license: MIT
metadata:
  author: fiup
  version: "1.0"
---

# React Frontend — TypeScript + Zustand + TailwindCSS

## Stack
- React 18, TypeScript 5.3, Vite 5, TailwindCSS 3.4
- State: Zustand 4 with persist
- Routing: react-router-dom 6
- i18n: react-i18next 14 + i18next-browser-languagedetector
- Charts: recharts 2.15
- HTTP: axios 1.6

## Conventions
- **Tipado estricto**: NUNCA `any`. Usar `interface` exportables.
- **Auth**: Solo Zustand persist con `partialize`. NO `localStorage.getItem('user'|'token')`.
- **Navegación**: `useNavigate()` o `<Link to>`. PROHIBIDO `window.location.href`.
- **i18n**: `t('namespace.key')` para TODO texto visible. NO strings hardcodeados.
- **Cleanup**: `useEffect` con cleanup, `AbortController.signal` en axios.
- **Loading/Error**: cada fetch maneja `loading`, `error`, `empty`.
- **Accesibilidad**: `aria-label` en interactivos, `role="dialog"` en modales.
- **Formularios**: validación con `zod`, schemas compartidos.

## Componentes UI compartidos
Usar `src/components/ui/`:
- `Spinner` — loading indicator
- `Modal` — dialog con focus trap + Escape
- `EmptyState` — sin datos
- `ErrorState` — error con retry
- `ConfirmDialog` — confirmación destructiva

## Anti-patterns prohibidos
| ❌ No | ✅ Sí |
|---|---|
| `window.location.href` | `navigate('/path', { replace: true })` |
| `localStorage.getItem('user')` | `useAuthStore(s => s.user)` |
| `useState<any>` | `useState<User \| null>` |
| `fetch(...)` inline | `api.get/post(...)` de `services/api.ts` |
| `<div onClick={...}>` | `<button onClick={...}>` |
| Strings hardcodeados | `t('namespace.key')` |
| `alert(...)` | `toast.error(...)` |
| `setTimeout` sin cleanup | `useRef + useEffect` cleanup |

## Comandos
```bash
cd frontend
npm run dev          # http://localhost:5173
npm run build
npm run lint
npm run test         # vitest
```
