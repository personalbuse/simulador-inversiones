# 📘 Manual de Aprendizaje y Arquitectura del Proyecto

Este documento está diseñado de forma educativa para explicar a detalle toda la arquitectura del **Simulador de Inversiones FIUP**, las mejores prácticas de ingeniería de software implementadas, las vulnerabilidades corregidas y las tecnologías utilizadas. Te servirá de guía completa para tus futuros proyectos de desarrollo de software.

---

## 🗺️ Índice
1. [🏗️ Arquitectura General (Full Stack)](#1-arquitectura-general-full-stack)
2. [🔒 Seguridad en el Mundo Real](#2-seguridad-en-el-mundo-real)
3. [⚡ Optimización y Rendimiento](#3-optimización-y-rendimiento)
4. [🧪 Pruebas y Cobertura de Código](#4-pruebas-y-cobertura-de-código)
5. [🧑‍💻 Validación con Zod en el Frontend](#5-validación-con-zod-en-el-frontend)
6. [🛠️ Herramientas de Desarrollo y Productividad (LSP, MCP, CI/CD)](#6-herramientas-de-desarrollo-y-productividad-lsp-mcp-cicd)

---

## 1. 🏗️ Arquitectura General (Full Stack)

El proyecto está diseñado bajo una arquitectura desacoplada moderna:

```
                  ┌─────────────────────────┐
                  │      Cliente Web        │
                  │   Vite + React + TS     │
                  └────────────┬────────────┘
                               │
                HTTPS / Cookies / JSON API
                               │
                               ▼
                  ┌─────────────────────────┐
                  │    Nginx Reverse Proxy  │
                  └────────────┬────────────┘
                               │
                               ▼
                  ┌─────────────────────────┐
                  │      API Backend        │
                  │         FastAPI         │
                  └──────┬────────────┬─────┘
                         │            │
             Async Query │            │ Cache
                         ▼            ▼
                  ┌──────────┐  ┌───────────┐
                  │PostgreSQL│  │   Redis   │
                  │ Database │  │ In-Memory │
                  └──────────┘  └───────────┘
```

### El Backend (FastAPI + SQLAlchemy Async)
1. **Asincronía Pura (`async/await`)**: Python tradicional es síncrono y bloqueante. FastAPI aprovecha la biblioteca `asyncio`. Al usar `async def`, el servidor puede manejar miles de conexiones simultáneas en un solo hilo al suspender las tareas que esperan E/S (como consultas a base de datos o llamadas HTTP externas) y dar paso a otras.
2. **SQLAlchemy 2.0 Async**: Utilizamos `AsyncSession` de SQLAlchemy. Esto evita que la base de datos bloquee el bucle de eventos del backend.
3. **Pydantic V2**: Validación de esquemas en tiempo de ejecución. Pydantic analiza el cuerpo JSON de entrada, valida los tipos de datos y los convierte en objetos Python tipados de forma ultrarrápida (escrito en Rust).

### El Frontend (React + TypeScript + Vite + Zustand)
1. **Zustand**: Gestor de estado ligero. A diferencia de Redux (pesado y verboso) o Context (que provoca renderizados innecesarios), Zustand utiliza selectores para que los componentes solo se actualicen cuando el estado específico que escuchan cambia.
2. **TypeScript Estricto**: Convierte JavaScript en un lenguaje tipado estéticamente. Evita errores comunes en producción (como `Cannot read property 'undefined'`) mediante análisis estático.

---

## 2. 🔒 Seguridad en el Mundo Real

### 🛡️ Migración de LocalStorage JWT a Cookies `httpOnly`
**¿Cuál era el problema?**
Anteriormente, el frontend almacenaba los tokens JWT en `localStorage`. Si un atacante lograba inyectar un script de JavaScript malicioso en el sitio (ataque **XSS - Cross-Site Scripting**), podía leer el `localStorage` mediante `localStorage.getItem('token')` y robar la sesión completa del usuario.

**¿Cómo lo corregimos?**
1. **Cookies `httpOnly`**: Los tokens se envían desde el backend en una cabecera `Set-Cookie` con la directiva `HttpOnly`. Esto le prohíbe explícitamente a JavaScript acceder a la cookie. Ningún script puede leerla.
2. **Cookies `Secure` e `SameSite=Lax`**: La directiva `Secure` asegura que la cookie solo viaje en conexiones HTTPS cifradas. `SameSite=Lax` mitiga los ataques **CSRF (Cross-Site Request Forgery)** al restringir el envío de la cookie en peticiones cruzadas originadas desde sitios externos.
3. **Peticiones Axios con `withCredentials: true`**: Permite al cliente React incluir y recibir cookies automáticamente en cada petición HTTP sin necesidad de configurar cabeceras `Authorization` manuales.

### 📜 Content Security Policy (CSP) sin `'unsafe-inline'`
**¿Qué es CSP?**
Es una capa de seguridad en la cabecera HTTP enviada por Nginx que le dice al navegador qué recursos (scripts, imágenes, fuentes, estilos) tiene permitido cargar y desde dónde.

**¿Cómo quitamos `'unsafe-inline'`?**
Tener `'unsafe-inline'` en los scripts de CSP permite que cualquiera inyecte código inline como `<script>alert('hack')</script>`. Lo corregimos calculando el hash criptográfico SHA-256 de nuestro único script inline (el script FOUC de tema oscuro/claro de `index.html`) y colocándolo en la cabecera de Nginx:
```nginx
script-src 'self' 'sha256-dMpLw8s/XDXicc7PLdbnOnB7c+TUtkrFj6kCqbZKJ/k=' https://static.cloudflareinsights.com;
```
Cualquier otro script inline inyectado por un atacante será bloqueado de inmediato porque su hash no coincidirá.

---

## 3. ⚡ Optimización y Rendimiento

### 🛑 AbortController y Prevención de fugas de memoria (Memory Leaks)
**¿Qué es el problema del componente desmontado?**
Si un usuario entra a una página (ej. Dashboard) y se inicia una petición de red lenta, y luego el usuario cambia rápidamente de página (desmontando el Dashboard), cuando la petición HTTP lenta finalmente termine, React intentará actualizar el estado de un componente que ya no existe en pantalla. Esto genera advertencias de consola y fugas de memoria.

**¿Cómo lo corregimos?**
Usamos la API nativa de JavaScript `AbortController` vinculada a Axios:
```typescript
useEffect(() => {
  const source = createCancelSource(); // Crea un AbortController

  const fetchData = async () => {
    try {
      const res = await api.get('/portfolio/values', { signal: source.signal });
      setPortfolio(res.data);
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') return; // Ignora abortos intencionales
      // manejar errores reales
    }
  };

  fetchData();
  return () => source.cancel(); // Aborta la petición inmediatamente si el usuario se va de la página
}, []);
```

---

## 4. 🧪 Pruebas y Cobertura de Código

Subimos la cobertura de pruebas de backend de un alarmante **5%** a un robusto **75%** (con 195 pruebas totales pasadas).

### Técnicas de Testing Avanzado
1. **Mocking de E/S**: Probar llamadas reales de red (ej. consultar tasas de cambio a ExchangeRate-API o datos de acciones a Finnhub) es costoso, lento e inestable. Usamos `unittest.mock.patch` y `AsyncMock` para emular respuestas exitosas y de fallo sin realizar tráfico de red real.
2. **Aislamiento de Base de Datos**: Creamos sesiones ficticias asíncronas (`MockAsyncSession`) que interceptan las llamadas SQL y devuelven estructuras de datos predecibles, evitando tocar una base de datos real en pruebas unitarias.

---

## 5. 🧑‍💻 Validación con Zod en el Frontend

**¿Por qué validar en el cliente con Zod si el backend ya valida?**
1. **Mejor UX (Experiencia de Usuario)**: Da feedback inmediato sin necesidad de esperar a que la petición viaje al servidor y retorne un error.
2. **Seguridad en capas**: Validación defensiva. El cliente valida para guiar al usuario; el servidor valida estrictamente para proteger la base de datos de datos corruptos.

**Ejemplo de Esquema de Contraseña Robusta:**
```typescript
export const passwordSchema = z
  .string()
  .min(12, 'validation.passwordMin') // Mínimo 12 caracteres
  .max(128)
  .regex(/[A-Z]/, 'validation.passwordUpper') // Requiere mayúscula
  .regex(/[a-z]/, 'validation.passwordLower') // Requiere minúscula
  .regex(/[0-9]/, 'validation.passwordNumber') // Requiere número
  .regex(/[^A-Za-z0-9]/, 'validation.passwordSpecial'); // Requiere carácter especial
```

---

## 6. 🛠️ Herramientas de Desarrollo y Productividad

Para facilitar y automatizar el flujo de trabajo del equipo, estructuramos herramientas de nivel profesional:

### 🚀 LSP (Language Server Protocol) & ESLint / Ruff
- **Ruff**: Es un linter y formateador de Python extremadamente rápido escrito en Rust (reemplaza a Black, Flake8 e isort). Integrado en VS Code mediante `.vscode/settings.json`, auto-organiza importaciones y formatea el código al guardar de forma instantánea.
- **ESLint**: Linter de TypeScript que analiza el código del frontend en tiempo de ejecución, configurado con reglas estrictas como la prohibición de tipos `any` implícitos.

### 🌐 MCP (Model Context Protocol)
- Define cómo los modelos de IA (como Claude o GPT) interactúan de forma estandarizada y segura con herramientas de tu sistema de archivos, terminales, bases de datos (PostgreSQL), caché (Redis) y repositorios de Git.

### 🔀 CI/CD con GitHub Actions
Creamos un flujo de trabajo continuo en `.github/workflows/ci.yml`:
1. **Linting**: Valida la calidad y estilo del código en Python y TypeScript.
2. **Testing**: Levanta contenedores reales de **PostgreSQL 16** y **Redis 7** en la nube de GitHub, aplica migraciones de Alembic y corre las 195 pruebas.
3. **Docker Build**: Compila imágenes multi-stage y las verifica antes de proceder a producción.

---

Este manual representa las bases fundamentales de ingeniería requeridas para diseñar sistemas estables, escalables y seguros en cualquier entorno moderno. ¡Úsalo como referencia en tus futuros proyectos!
