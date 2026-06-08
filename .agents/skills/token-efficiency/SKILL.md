---
name: token-efficiency
description: Token optimization patterns for AI-assisted development. Use when optimizing AI context usage, reducing token consumption, or structuring prompts for efficiency.
license: MIT
metadata:
  author: fiup
  version: "1.0"
---

# Token Efficiency — Patrones de ahorro de tokens

## Principios
1. **Contexto mínimo viable**: Solo incluir código/fragmentos relevantes al task.
2. **Archivos planos > archivos largos**: Preferir muchos archivos pequeños sobre pocos gigantes.
3. **Duplicación zero**: Cada concepto existe una sola vez (DRY extremo para contexto AI).
4. **Navegación estructurada**: Usar `file:line` para referencias, no copiar bloques enteros.
5. **Skills locales**: Domain logic en skills reutilizables para evitar repetir contexto.

## Técnicas de compresión

### Caveman Mode (recomendado)
Usar lenguaje comprimido que elimina artículos, sujetos, y verbos auxiliares sin perder precisión técnica.

| Normal | Caveman |
|---|---|
| "We need to add a new endpoint that will return the user's profile data" | `feat(api): add GET /users/:id/profile` |
| "The issue is that the localStorage key doesn't match the one used in ThemeProvider" | `localStorage key mismatch: ThemeProvider uses 'darkMode', inline script uses 'simulador-theme'` |
| "Could you please check if there are any remaining window.location.href usages in the auth pages?" | `grep window.location.href src/pages/auth/` |

### Structura de prompts
```
Contexto: <1-2 lines linking to skill/project doc>
Task: <1 line what>
Files: <paths to touch>
Constraints: <1 line rules from AGENTS.md>
Verify: <command to run>
```

### Uso de skills
- Cargar skills con `skill` en vez de copiar reglas al prompt.
- Skills = contexto comprimido reutilizable vs repetir en cada mensaje.

## Referencias
- AGENTS.md: secciones 3-5, 8
- `.opencode.jsonc`: tokenEfficiency config
- Skills: `caveman`, `caveman-commit`
