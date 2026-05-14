# 📖 Manual de Usuario - Simulador de Inversiones

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Registro e Inicio de Sesión](#registro-e-inicio-de-sesión)
3. [Dashboard Principal](#dashboard-principal)
4. [Mercados Globales](#mercados-globales)
5. [Divisas](#divisas)
6. [Compra y Venta de Acciones](#compra-y-venta-de-acciones)
7. [Mi Portafolio](#mi-portafolio)
8. [Ranking de Inversores](#ranking-de-inversores)
9. [Reporte PDF](#reporte-pdf)
10. [Noticias](#noticias)
11. [FAQ](#faq)

---

## 1. Introducción

El **Simulador de Inversiones** es una herramienta educativa que te permite practicar inversiones en bolsa sin riesgo real. Comenzarás con un saldo虚拟 de **$100,000 USD** para invertir en acciones, índices y divisas reales.

### Características principales
- 📈 35+ acciones de empresas tecnológicas líderes
- 🌍 24 índices bursátiles de todo el mundo
- 💱 10 pares de divisas (incluyendo COP)
- 👥 Compite con otros estudiantes en el ranking

---

## 2. Registro e Inicio de Sesión

### Registro
1. Ve a la página de registro
2. Ingresa un **nombre de usuario** (único)
3. Ingresa tu **correo electrónico**
4. Crea una **contraseña** segura
5. Click en "Registrarse"

### Inicio de Sesión
1. Ve a la página de login
2. Ingresa tu usuario y contraseña
3. Click en "Iniciar Sesión"
4. ¡Listo! Accederás al Dashboard

---

## 3. Dashboard Principal

El Dashboard es tu centro de control. Muestra:

### Resumen de Cuenta
- **Saldo disponible**: Fondos sin invertir
- **Valor del portafolio**: Valor actual de tus inversiones
- **Ganancia/Perdida**: Rentabilidad total

### Acciones Rápidas
- Mercado de acciones
- Índices mundialess
- Divisas

### Últimas Noticias
- 3 noticias financieras recientes
- Click para ver más detalles

---

## 4. Mercados Globales

### Índices Mundiales
Accede a `/indices` para ver:
- **S&P 500** (Estados Unidos)
- **Dow Jones** (Estados Unidos)
- **IPC México** (México)
- **IBOVESPA** (Brasil)
- **COLCAP** (Colombia)
- **FTSE 100** (Reino Unido)
- **DAX** (Alemania)
- **Nikkei 225** (Japón)
- Y muchos más...

Cada índice muestra:
- Precio actual
- Cambio diario (%)
-/high/low del día

### Acciones Internacionales
Accede a `/markets` para invertir en:
| Región | Países | Ejemplos |
|--------|--------|----------|
| Norteamérica | USA, México | Apple, Tesla, Walmart |
| Sud América | Brasil, Colombia, Chile | Petrobras, ECOPETROL |
| Europa | Alemania, Francia, UK | Siemens, LVMH, BP |
| Asia | Japón, China, India | Toyota, Samsung, Reliance |

---

## 5. Divisas

Accede a `/forex` para ver tasas de cambio:

| Par | Descripción |
|-----|-------------|
| USD/COP | Dólar vs Peso Colombiano |
| EUR/COP | Euro vs Peso Colombiano |
| USD/MXN | Dólar vs Peso Mexicano |
| USD/BRL | Dólar vs Real Brasileño |
| EUR/USD | Euro vs Dólar |
| GBP/USD | Libra vs Dólar |
| USD/JPY | Dólar vs Yen Japonés |

**Nota**: Las tasas se actualizan automáticamente y se caching durante 1 hora.

---

## 6. Compra y Venta de Acciones

### Comprar
1. Ve a **Mercados** o busca una acción
2. Haz click en la acción deseada
3. Ingresa la **cantidad** de acciones
4. Click en **"Comprar"**
5. Confirma la operación

**Ejemplo**: Comprar 10 acciones de AAPL a $150 = $1,500 USD

### Vender
1. Ve a **Mi Portafolio**
2. Selecciona las acciones a vender
3. Ingresa la **cantidad**
4. Click en **"Vender"**
5. Confirma la operación

**Nota**: Solo puedes vender acciones que posees. No puedes vender más de las que tienes.

---

## 7. Mi Portafolio

Accede a `/portfolio` para ver:

### Resumen
- **Total invertido**: Suma de costos
- **Valor actual**: Valor de mercado
- **Ganancia/Perdida**: Rentabilidad

### Tabla de Posiciones
| Columna | Descripción |
|---------|-------------|
| Símbolo | Código de la acción |
| Cantidad | Acciones poseídas |
| Costo Prom. | Precio promedio de compra |
| Precio Actual | Cotización actual |
| Valor | Cantidad × Precio Actual |
| Ganancia | Diferencia vs costo |

### Ordenar
Click en los encabezados para ordenar por:
- Símbolo
- Cantidad
- Costo Promedio
- Precio Actual
- Valor
- Ganancia

---

## 8. Ranking de Inversores

Accede a `/leaderboard` para ver el **Top 10** de inversores:

| Posición | Usuario | Rentabilidad |
|----------|---------|--------------|
| 🥇 1 | usuario1 | +25.5% |
| 🥈 2 | usuario2 | +18.2% |
| 🥉 3 | usuario3 | +15.0% |

### Tu Posición
Si estás logueado, también verás:
- Tu posición en el ranking
- Tu rentabilidad total
- Número total de inversores

---

## 9. Reporte PDF

Genera un reporte de tu portafolio:

1. Ve a **Mi Portafolio**
2. Click en **"Descargar PDF"**
3. Se generará y descargará un archivo PDF

### El PDF incluye:
- Nombre de usuario y fecha
- Saldo disponible
- Valor total del portafolio
- Ganancia/Perdida total
- Detalle de cada posición:
  - Símbolo
  - Cantidad
  - Costo promedio
  - Precio actual
  - Ganancia/Perdida por acción

---

## 10. Noticias

Accede a `/news` o visita la sección de noticias en el Dashboard:

- **Noticias generales**: Mercado y economía
- **Noticias por símbolo**: Noticias específicas de una empresa

Las noticias se actualizan cada 30 minutos.

---

## 11. FAQ

### ¿Cuánto dinero tengo al inicio?
$100,000 USD virtuales.

### ¿Las operaciones son reales?
No. Es un simulador educativo. No se usa dinero real.

### ¿Qué pasa si pierdo todo?
Puedes reiniciar en cualquier momento (consulta con tu profesor).

### ¿Puedo operar en horarios específicos?
El mercado simulado está disponible 24/7.

### ¿Cómo se calculan las ganancias?
`(Precio Actual - Costo Promedio) × Cantidad`

### ¿Hay límite de operaciones?
Sí, aplica rate limiting para evitar abusos.

### ¿Las tasas de cambio son reales?
Sí, se obtienen de APIs de tasas de cambio en tiempo real.

---

*Manual de usuario - Finanzas Internacionales - Universidad de Pamplona (UP)*