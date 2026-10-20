# 📋 Hoja de Ruta: Rediseño Integral ASIC Guanipa / CDI Pedro Urbina

Este documento es la bitácora oficial del rediseño del sistema. Detalla el diagnóstico de la auditoría UI/UX (presentación de 29 páginas), la correspondencia con la base de datos PostgreSQL existente, el enfoque centrado en el usuario operativo (**"Capa 8"**: enfermeros, vacunadores y personal asistencial en campo/CDI) y el estado de avance fase por fase.

---

## 🎯 Principio Rector: Cero Campos Fantasma y Respeto a la Base de Datos
1. **Ningún campo se pide en la interfaz si no se almacena en la base de datos.**
2. **Ningún campo obligatorio en la base de datos se omite en la interfaz** (los datos del sistema como `id_usuario_registra`, `fecha` o `edad_atencion` se autocompletan para no sobrecargar al operador).
3. **Las migraciones son 100% aditivas y no destructivas** (`addColumn`), garantizando que la data histórica permanezca intacta.

---

## 📊 Resumen General de Fases

| Fase | Título | Ámbito | Estado |
|---|---|---|---|
| **Fase 1** | **Landing Pública Limpia & Login Ágil Multimodal** | Backend & Frontend | ✅ Completado |
| **Fase 2** | **Dashboard Despejado & Apertura de Guardia / Despliegue** | Frontend & Backend | ✅ Completado |
| **Fase 3** | **Flujo de Inmunización Rápida & Modal Paciente al Vuelo** | Frontend & Backend | ✅ Completado |
| **Fase 4** | **Registro Nominal (Data Grid), Carnet Digital, Constancia de Atención (QR) & Récipe Digital** | Frontend & Backend | ✅ Completado |
| **Fase 5** | **Almacén Epidemiológico, Cadena de Frío & Entidades Distribuidoras** | Frontend & Backend | ⏳ Pendiente |
| **Fase 6** | **Generador Dinámico de Reportes e Indicadores SISPAI / EPI** | Frontend & Backend | ⏳ Pendiente |

---

## 📝 Detalle de Cada Fase

### 🔹 FASE 1: Landing Pública Limpia & Login Ágil Multimodal
* **Páginas del PDF:** 1, 2, 3 y 4.
* **Problema diagnosticado:**
  * La landing actual actúa como catálogo comercial ("Todo lo que necesitas en un solo lugar") con tarjetas gigantescas de módulos privados.
  * El login está disperso en la pantalla (espacio vacío excesivo) y exige obligatoriamente un correo electrónico largo, lo que genera lentitud y errores de tipeo al personal de guardia.
* **Situación real / "Capa 8":**
  * El enfermero enciende la laptop de la guardia y necesita autenticarse en 5 segundos usando su Cédula o usuario corto (ej. `eyaguez` o `18942103`), no un correo de 30 caracteres.
* **Acciones realizadas:**
  - [x] **Backend:** Modificar validador y controlador de login para aceptar `username`, `email` o `login` indiferentemente (`WHERE email = :id OR username = :id`).
  - [x] **Backend:** Actualizar documentación Swagger del endpoint `/api/auth/login`.
  - [x] **Backend:** Tests automatizados añadidos y pasando 100% (9 de 9).
  - [x] **Frontend:** Rediseñar la Landing pública:
    * Encabezado institucional sobrio: *"Plataforma oficial para la gestión integral de insumos, jornadas sanitarias y registro nominal de pacientes."*
    * Botón directo: `Ingresar al Sistema` con candado y subtítulo de seguridad.
    * Eliminación total de la rejilla de tarjetas "Todo lo que necesitas en un solo lugar".
    * Barra horizontal de 3 métricas clave: Disponibilidad (En línea 24/7), Seguridad (AES-256 / JWT), Versión (v1.0.0).
    * Bloque simétrico de descarga de aplicaciones nativas (Android APK, Windows EXE).
  - [x] **Frontend:** Rediseñar pantalla de Login:
    * Layout centrado y simétrico (ancho contenedor 1060px, sin elementos pegados a los bordes).
    * Etiqueta de campo cambiada a: `Usuario` (placeholder: `Ej. eyaguez o 12345678`), con texto explicativo: *"Puedes usar tu nombre de usuario o correo institucional"*.
    * Integración con servicio API enviando el identificador multimodal.
* **Correspondencia con BD:**
  * Modelo `users` ya posee `username` y `email`. Compatible al 100%.

---

### 🔹 FASE 2: Dashboard Despejado & Apertura de Guardia / Despliegue
* **Páginas del PDF:** 5, 7, 15, 16, 17 y 18.
* **Problema diagnosticado:**
  * Banner azul gigante que ocupa media pantalla con datos obvios, obligando a hacer scroll para ver los módulos.
  * Se le pide al operador en cada paciente que seleccione el centro de salud, modalidad y jornada.
* **Situación real / "Capa 8":**
  * La planificación logística ocurre **antes** de atender al primer paciente. Al iniciar el turno se define si la guardia es **Intramural (en CDI)** o **Extramural (salida de campo)**.
* **Acciones realizadas:**
  - [x] **Frontend:** Bienvenida y estado de conexión movidos al header del dashboard (avatar, saludo, fecha). El dashboard es completamente visible sin scroll.
  - [x] **Frontend:** Modal de **Apertura de Guardia / Jornada** implementado (`apertura_guardia_dialog.dart`):
    * **Modo Intramural:** CDI precargado, turno auto-sugerido por hora del día, supervisor autocompletado con el usuario actual.
    * **Modo Extramural:** Sector/comunidad de destino, termo asignado, temperatura inicial del termo, líder de despliegue.
  - [x] **Frontend:** `GuardiaProvider` implementado con persistencia en `FlutterSecureStorage`. El contexto de guardia sobrevive recargas accidentales.
  - [x] **Frontend:** Status bar de guardia activa en dashboard (muestra modalidad, turno, centro/sector y botón de cierre con confirmación).
  - [x] **Frontend:** Métricas del dashboard usan el contador de `pacientesAtendidos` de la guardia activa en tiempo real.
* **Pendiente (integrar en Fase 3):** `jornada_diaria_screen.dart` aún pregunta centro/operativo por cada atención en lugar de leerlos del `GuardiaProvider`.

---

### 🔹 FASE 3: Flujo de Inmunización Rápida & Modal Paciente al Vuelo
* **Páginas del PDF:** 8, 9, 10, 11, 12, 13, 14, 17 y 18.
* **Problema diagnosticado:**
  * Grave confusión de roles: se trata una vacunación como si fuera una consulta médica general (pide tratamiento indicado, signos vitales completos, tensión arterial, y el biológico está al final como "opcional").
  * Un registro toma de 3 a 5 minutos cuando en jornada debería tomar entre 30 y 45 segundos.
  * El botón "Registrar Nuevo Paciente" está al final del scroll y navega fuera del contexto.
* **Situación real / "Capa 8":**
  * Un enfermero vacuna 80 personas en una mañana. Solo necesita seleccionar el lote activo del termo, marcar la dosis (1ra, 2da, Refuerzo), sitio de aplicación (Brazo/Muslo/Oral) y verificar temperatura rápida para descartar fiebre.
  * Si llega una madre con un recién nacido sin cédula, no se le puede negar la atención: se le genera un código asociado a la madre (`V-18942103-N1`) en una ventana modal emergente rápida sin recargar la página.
* **Acciones a realizar:**
  - [ ] **Frontend:** Modal de **Nuevo Paciente Rápido** (Titular vs Menor/Recién Nacido dependiente del tutor, indicador de esquema previo de otro centro).
  - [ ] **Frontend:** Pantalla de **Vacunación Rápida**:
    * Selección directa de Biológico / Lote disponible.
    * Dosis / Esquema (Primera, Segunda, Tercera, Refuerzo 1, Refuerzo 2, Única).
    * Vía y Sitio anatómico.
    * Signos vitales mínimos: SOLO Temperatura (°C). Peso/Talla SOLO si es menor de 5 años.
    * Trazabilidad legal: Código del personal vacunador.
    * **Salida Documental Inmediata (1-Clic):** Tras confirmar la atención, accesos directos para imprimir **Constancia de Atención con QR** o emitir **Récipe Digital** antes de retornar automáticamente al buscador de pacientes.
  - [ ] **Backend / BD (Migración aditiva):** Agregar campos en `atenciones_diarias` / `registro_vacunacion`:
    * `dosis_esquema` (VARCHAR)
    * `via_administracion` (VARCHAR)
    * `sitio_administracion` (VARCHAR)
    * `temperatura` (DECIMAL)
    * `peso` (DECIMAL, nullable)
    * `talla` (DECIMAL, nullable)
    * `modalidad` (VARCHAR: 'intramural', 'extramural')

---

### 🔹 FASE 4: Registro Nominal (Data Grid), Carnet Digital (QR), Constancia de Atención Verificable & Récipe Digital
* **Páginas del PDF:** 19, 20, 21, 22 y 23.
* **Problema diagnosticado:**
  * Lista de pacientes en tarjetas gigantes de 120px donde solo caben 3 o 4 por pantalla.
  * Falta de visualización del Esquema Nacional y ausencia de un carnet oficial digital cuando el paciente extravía el cartón físico.
  * Ausencia de documentos médico-legales oficiales con validez jurídica inmediata (constancias selladas con QR y récipes médicos digitales) que la comunidad requiere para trámites escolares, laborales o retiro de medicamentos en farmacia comunitaria/CDI.
* **Situación real / "Capa 8":**
  * El personal necesita buscar entre miles de personas, filtrar rápidamente quiénes tienen esquema incompleto o lactantes sin vacuna, y poder emitir en 1 clic documentos oficiales protegidos contra falsificación:
    1. **Carnet de Inmunización Oficial:** Para control del esquema de vacunación del paciente.
    2. **Constancia de Atención Médica / Inmunización con QR:** Requerida por escuelas, maternales, empresas e instituciones públicas. Cualquier directivo o funcionario puede escanear el QR con su teléfono y validar en tiempo real que la atención fue legítima en el CDI.
    3. **Récipe Digital Oficial:** Para la prescripción clara de medicamentos, dosificación pediátrica/adulto e indicaciones, eliminando la letra ilegible y habilitando la verificación y dispensación segura en la farmacia del CDI.
* **Acciones realizadas:**
  - [x] **Frontend:** Data Grid adaptativo y compacto:
    * Modo Escritorio: tabla profesional de 6 columnas con identificador, paciente, sector, contacto, datos clínicos y acciones.
    * Modo Móvil Android (<750px): tarjetas táctiles compactas con datos agrupados, avatares y botones adaptados al pulgar.
    * Filtros avanzados multinivel (sector, edad, sexo) y búsqueda reactiva debounced.
    * Exportación a CSV / Excel con codificación UTF-8 BOM.
  - [x] **Frontend / Backend:** Vista unificada de historial del paciente (`PatientHistoryScreen`) con historial de dosis.
  - [x] **Frontend / Backend:** Generador de **Carnet de Vacunación Oficial Imprimible** (`carnet_vacunacion_dialog.dart`) con formato del MPPS / ASIC Guanipa, formato CR-80 (tarjeta) y hoja completa, desglose de dosis y código QR.
  - [x] **Frontend / Backend:** Generador de **Constancia Oficial de Atención con QR Verificable** (`constancia_atencion_dialog.dart`):
    * Membrete institucional: *República Bolivariana de Venezuela · MPPS · ASIC San José de Guanipa · CDI Dr. Pedro Urbina*.
    * Identificación del paciente, acto asistencial, observaciones clínicas, código de emisión y firma.
    * Código QR dinámico para verificación pública de legitimidad.
    * Impresión directa en formato Carta con estilos CSS de alta fidelidad.
  - [x] **Frontend / Backend:** Módulo de **Récipe Digital Oficial** (`recipe_digital_dialog.dart`) con prescripción estructurada, posología y QR para dispensación en farmacia.

---

### 🔹 FASE 5: Almacén Epidemiológico, Cadena de Frío & Entidades Distribuidoras
* **Páginas del PDF:** 24, 25, 26, 27 y 28.
* **Problema diagnosticado:**
  * Se mezclan vacunas (biológicos) con guantes y gasas en la misma lista sin control de cadena de frío.
  * Se tratan entidades oficiales del Estado (MPPS, SEFAR) como si fueran "proveedores comerciales".
  * Tarjetas infladas para lotes sin semáforos de alerta rápida.
* **Situación real / "Capa 8":**
  * En epidemiología, un lote de vacunas requiere seguimiento estricto de temperatura, dosis por frasco y vencimiento.
* **Acciones a realizar:**
  - [ ] **Frontend:** Separación del inventario en 3 pestañas operativas:
    1. **Biológicos (Vacunas):** Control por lote, dosis disponibles, vencimiento y temperatura.
    2. **Insumos y Material Consumible:** Jeringas, torundas, cajas de descarte.
    3. **Activos Fijos:** Termos de refrigeración y data loggers con asignación a jornadas y retorno.
  - [ ] **Frontend:** Data Grid de Lotes con semáforo de estado (Óptimo, Stock Bajo, Por Vencer, Agotado) y botones directos de reposición.
  - [ ] **Backend / BD:** Registrar Entidades Distribuidoras oficiales (MPPS, SEFAR, Almacén Regional Anzoátegui) con Acta de Recepción y Temperatura de Entrada.

---

### 🔹 FASE 6: Generador Dinámico de Reportes e Indicadores SISPAI / EPI
* **Páginas del PDF:** 5 y 6.
* **Problema diagnosticado:**
  * Reportes limitados a una búsqueda simple por fecha y sector, inútil para la toma de decisiones sanitarias y la entrega de cuentas al Ministerio.
* **Situación real / "Capa 8":**
  * Para los informes SISPAI y epidemiológicos se requieren cruces multidimensionales (ej. "¿Cuántas dosis de Pentavalente se aplicaron a menores de 1 año en jornadas extramurales durante la Semana Epidemiológica 20?").
* **Acciones a realizar:**
  - [ ] **Backend:** Endpoint analítico multidimensional con agregaciones SQL (`GROUP BY`).
  - [ ] **Frontend:** Generador de reportes dinámicos con filtros cruzados:
    * Biológico y dosis
    * Grupo etario (<1 año, 1 año, 2-4 años, 5-9 años, adultos, embarazadas)
    * Sexo (F / M)
    * Modalidad (Intramural vs Extramural)
    * Sector / Comunidad
    * Semana Epidemiológica (EPI 1 a 52)
  - [ ] Exportación a formato tabular oficial.

---

## 📌 Estado de la Sesión Actual

### ✅ Estructura del Proyecto — CONSOLIDADA
* El proyecto estaba dividido en dos carpetas: la raíz (`Proyecto-Uptjaa-CDI/`) incompleta, y `asic-guanipa-frontend/` con el proyecto completo (frontend Flutter + backend completo).
* **Acción realizada:** Se migró todo a la raíz. El directorio `asic-guanipa-frontend/` fue **eliminado**. El proyecto ahora es un único directorio limpio.

### ✅ Fase 1 — Backend: Login Multimodal
* Modificado: `src/controllers/authController.js` → función `login`.
* El endpoint `POST /api/auth/login` ahora acepta el campo `login`, `username` o `email` con 3 estrategias de búsqueda:
  1. **Si contiene `@`** → busca por correo en tabla `correos`.
  2. **Si son solo dígitos** → busca por `cedula_identidad` en tabla `personas` y como fallback por `nombre_usuario`.
  3. **En cualquier otro caso** → busca directamente por `nombre_usuario`.
* Compatible 100% con la BD existente (sin migraciones requeridas).

### ✅ Fase 2 — Dashboard + Apertura de Guardia: COMPLETADA
* Modal de apertura implementado con persistencia en `FlutterSecureStorage`.
* Dashboard compacto sin scroll, con status bar de guardia activa.

### ✅ Fase 3 — Flujo de Inmunización Rápida: COMPLETADA
* Conectado `jornada_diaria_screen.dart` al `GuardiaProvider` (banner de guardia activa, contador en vivo e inyección automática de contexto).
* Formulario rediseñado en flujo ultrarrápido de 2 pasos (< 45 segundos): búsqueda reactiva -> registro de dosis (lote persistente, dosis, vía, sitio, temperatura de screening, peso/talla pediátrico opcional) -> confirmación y retorno automático al buscador.
* Eliminados formularios repetitivos de centro, operativo y signos vitales exhaustivos para maximizar la velocidad en campo y consultorio.
* `CreatePatientDialog` con soporte nativo para recién nacidos / pacientes sin cédula asociados a su representante legal.
* Migración aditiva y modelo actualizados en BD (vía, sitio, temperatura, peso, talla, modalidad).

### ✅ Fase 4 — Registro Nominal, Constancia con QR, Récipe Digital & Carnet Imprimible: COMPLETADA
* **Data Grid adaptativo:** Tabla compacta de 6 columnas para escritorio y tarjetas táctiles para Android (<750px).
* **Constancia Oficial de Atención con QR Verificable:** Diálogo institucional (`constancia_atencion_dialog.dart`) con membrete MPPS / CDI Pedro Urbina, datos de atención, código de verificación e impresión optimizada Carta / Media Carta.
* **Módulo de Récipe Digital Oficial:** Prescripción médica estructurada con posología clara, QR de trazabilidad y sello digital.
* **Carnet de Vacunación Oficial:** Formato credencial CR-80 y hoja completa con código QR de verificación de autenticidad.

### ⏳ Siguiente paso — Fase 5: Almacén Epidemiológico, Cadena de Frío & Entidades Distribuidoras
* Separación del inventario en 3 pestañas: Biológicos (Vacunas), Insumos/Consumibles y Activos Fijos (Termos/Data Loggers).
* Control de Cadena de Frío (temperaturas de entrada, semáforos de stock/vencimiento).
* Registro de Entidades Distribuidoras oficiales (MPPS, SEFAR, Almacén Regional Anzoátegui).


