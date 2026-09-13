<!--
Sync Impact Report
Version change: [NONE] → 1.0.0 (initial ratification)
Modified principles: n/a (initial adoption, all placeholders filled)
Added sections:
  - Core Principles I-V (Naturaleza y Propósito, Stack Tecnológico, Reglas de Dominio,
    Estructura y Estilo de Código, Manejo de Errores y Validaciones)
  - Comportamiento del Agente de IA (Reglas SDD)
  - Governance
Removed sections:
  - Generic "[SECTION_3_NAME]" template slot dropped (no third cross-cutting section was
    supplied by the project; only one additional section — AI agent behavior — applies)
Follow-up TODOs: none
-->

# MutateRB Constitution

## Core Principles

### I. Naturaleza y Propósito del Proyecto
MutateRB es una herramienta de mutation testing para proyectos Ruby: modifica tests ya
existentes para intentar romperlos. Si un test mutado no falla, ese test queda identificado
como débil. Toda decisión de diseño DEBE subordinarse a este propósito único; funcionalidad
que no sirva a detectar tests débiles vía mutación queda fuera de alcance.

**Razón**: este es el motivo de existencia de la herramienta; fijarlo como principio evita
que el proyecto derive hacia un framework de testing genérico o un linter.

### II. Stack Tecnológico
La herramienta se implementa exclusivamente en **Ruby 3**. No se introducen otros lenguajes
de ejecución (scripts auxiliares, binarios externos) salvo que el propio Ruby 3 no pueda
resolver el requerimiento.

**Razón**: MutateRB manipula código y tests Ruby; usar Ruby nativamente garantiza
compatibilidad directa con el AST, RSpec/Minitest y las convenciones del ecosistema que
analiza.

### III. Reglas de Dominio (NO NEGOCIABLES)
Las siguientes reglas de negocio son inmutables y DEBEN respetarse estrictamente:
- **Core**: la herramienta DEBE detectar automáticamente los tests del proyecto objetivo,
  sea un proyecto Ruby puro o un proyecto Ruby on Rails, sin requerir que el usuario indique
  manualmente cada archivo.
- **Archivo de configuración**: DEBE existir soporte para un archivo de configuración que
  permita fijar la carpeta objetivo y configuraciones generales de ejecución.
- **Flags**: la CLI DEBE exponer flags para nivel de estricticidad, carpetas a incluir/excluir,
  y tipos de mutación a aplicar.

**Razón**: son las capacidades mínimas sin las cuales la herramienta no cumple su propósito
(Principio I) en un flujo de trabajo real de Ruby/Rails.

### IV. Estructura y Estilo de Código
- **Estructura plana**: se evita la sobreingeniería. No se implementa Clean Architecture ni
  patrones de diseño complejos. La gema mantiene una estructura simple y convencional.
- **Estilo**: se prioriza programación orientada a objetos y el principio DRY.
- **Nomenclatura**: Rubocop es obligatorio para mantener consistencia de estilo en todo el
  código.

**Razón**: mantener el código legible y de bajo costo de mantenimiento, coherente con ser
"una gema simple" y no una plataforma.

### V. Manejo de Errores y Validaciones
- **Manejo de errores**: todo posible error DEBE capturarse mediante `begin/rescue`
  (excepciones); no se permite dejar rutas de fallo sin controlar.
- **Manejo de validaciones**: se DEBE validar el tipo de dato de entradas y el valor de
  retorno de las funciones antes de operar sobre ellos.

**Razón**: la herramienta escribe/modifica tests de terceros; un fallo no controlado puede
corromper el código del usuario o dar resultados de mutación falsos.

## Comportamiento del Agente de IA (Reglas SDD)

- **Cero código sombra**: el agente de IA construye estrictamente lo documentado en
  `spec.md`. No se agregan características "por si acaso" ni funcionalidad no especificada.
- **Fuente de la verdad**: si una instrucción del usuario contradice esta constitución, o el
  agente detecta una falla lógica, el agente DEBE detenerse, advertir el problema al usuario
  y solicitar que se actualice `spec.md` antes de tocar código fuente.

## Governance

Esta constitución prevalece sobre cualquier otra práctica, plantilla o convención del
proyecto. Ante conflicto, esta constitución gana.

- **Enmiendas**: cualquier cambio a este documento se realiza editando
  `.specify/memory/constitution.md`, actualizando la versión según la política de
  versionado semántico de abajo, y dejando constancia del cambio en un Sync Impact Report.
- **Versionado semántico**:
  - MAJOR: eliminación o redefinición incompatible de un principio o regla de dominio.
  - MINOR: adición de un principio o sección, o expansión material de una guía existente.
  - PATCH: aclaraciones, correcciones de redacción o ajustes no semánticos.
- **Revisión de cumplimiento**: todo `spec.md` y `plan.md` generado para una feature DEBE
  validarse contra estos principios antes de pasar a `/speckit-implement`. Cualquier
  desviación debe justificarse explícitamente en el propio `spec.md` o corregirse.

**Version**: 1.0.0 | **Ratified**: 2026-09-13 | **Last Amended**: 2026-09-13
