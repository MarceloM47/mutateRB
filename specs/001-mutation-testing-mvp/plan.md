# Implementation Plan: MutateRB — Mutation Testing para Ruby/Rails (MVP)

**Branch**: `001-mutation-testing-mvp` | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-mutation-testing-mvp/spec.md`

## Summary

MutateRB es una gem/CLI en Ruby 3 que detecta automáticamente los tests RSpec de un proyecto
Ruby o Ruby on Rails, aplica mutaciones puntuales al código fuente cubierto por esos tests, y
reporta qué mutaciones fueron "killed" (detectadas) vs "survived" (test débil). El enfoque
técnico: parsear cada archivo con `RubyVM::AbstractSyntaxTree` (stdlib) para localizar nodos
mutables por posición, aplicar la mutación como un reemplazo quirúrgico de texto (sin
reserializar el AST completo), ejecutar el test relevante vía `bundle exec rspec` del propio
proyecto objetivo (subprocess con timeout basado en el tiempo base del test), restaurar el
archivo original, y repetir para cada mutante generado. Config y flags se combinan en un único
objeto `Config` (flags ganan sobre YAML), y el resultado se imprime en consola y,
opcionalmente, se exporta a JSON.

## Technical Context

**Language/Version**: Ruby 3.x (mínimo 3.0, sin dependencia de features de una minor específica)

**Primary Dependencies**: Solo stdlib de Ruby para el motor de mutación y ejecución
(`RubyVM::AbstractSyntaxTree`, `OptionParser`, `YAML`/`Psych`, `JSON`, `Open3`, `Timeout`,
`FileUtils`). No se agrega el gem `parser`/`unparser` en el MVP (ver research.md). RSpec no es
una dependencia de runtime de la gem: se invoca el RSpec ya instalado en el proyecto objetivo
vía `bundle exec`. RSpec y Rubocop sí son dependencias de desarrollo (`development` en el
gemspec) para testear y lintear MutateRB en sí mismo.

**Storage**: N/A — no hay persistencia entre corridas (ver Non-Goals del spec: sin historial).

**Testing**: RSpec (para el propio código de MutateRB) + Rubocop (estilo, Principio IV de la
constitución).

**Target Platform**: CLI multiplataforma sobre cualquier entorno con Ruby 3 (Linux/macOS
primero; sin dependencias nativas que rompan Windows, pero no se testea explícitamente en el
MVP).

**Project Type**: Single project — gem Ruby con ejecutable CLI (Option 1 del layout estándar).

**Performance Goals**: Sin objetivo formal de throughput; la corrida es secuencial por diseño
(ver Non-Goals: sin paralelización/distribución en esta iteración). El único límite de tiempo
explícito es por-mutante: timeout = 2× duración base del test, piso 5s (FR-014).

**Constraints**: (1) El código fuente del proyecto objetivo DEBE quedar bit-a-bit idéntico al
original al finalizar cualquier corrida, incluso ante `Ctrl+C` o crash (FR-005, SC-004) →
requiere manejo de señales (`Signal.trap("INT")`) y limpieza garantizada (`ensure`). (2) Ningún
fallo puntual (mutación inválida, test colgado) puede abortar la corrida completa (FR-010,
SC-005) → cada mutante se ejecuta en su propio `begin/rescue` aislado.

**Scale/Scope**: Sin límite explícito de cantidad de mutaciones por corrida definido en el spec
(quedó como "Deferred" en `/speckit-clarify`); el MVP no impone un tope artificial, pero tampoco
garantiza tiempos de corrida acotados en proyectos grandes — se revisita si aparece como
bloqueante real durante la implementación.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Chequeo | Resultado |
|---|---|---|
| I. Naturaleza y Propósito | ¿Todo lo planeado sirve exclusivamente a detectar tests débiles vía mutación? | PASS — no se planea ninguna capacidad fuera de detectar/mutar/reportar. |
| II. Stack Tecnológico | ¿Se usa solo Ruby 3, sin otros runtimes? | PASS — motor 100% stdlib Ruby; RSpec/Rubocop son gems Ruby de desarrollo, no otro lenguaje. |
| III. Reglas de Dominio (NO NEGOCIABLES) | ¿Auto-detección Ruby/Rails, archivo de config y flags CLI están cubiertos? | PASS — `ProjectDetector`, `Config` (YAML) y `CLI` (OptionParser) los implementan (ver data-model.md y contracts/). |
| IV. Estructura y Estilo | ¿Estructura plana de gema, sin Clean Architecture? ¿POO + DRY? ¿Rubocop? | PASS — ver "Project Structure" abajo: una sola carpeta `lib/mutaterb/` con clases planas, sin capas. Rubocop incluido como dependencia de desarrollo. |
| V. Manejo de Errores y Validaciones | ¿Cada componente contempla `begin/rescue` y validación de tipos/retornos? | PASS (a nivel de diseño) — cada entidad en data-model.md declara sus validaciones (FR-011); se exige en `/speckit-implement` que cada método público valide entradas y capture excepciones, no delegable a nivel de plan. |
| Comportamiento del Agente de IA | ¿Este plan se limita a lo documentado en spec.md? | PASS — ninguna funcionalidad planeada excede las User Stories, FRs o Non-Goals del spec. |

Sin violaciones detectadas. No aplica la sección "Complexity Tracking".

**Re-chequeo post-Phase 1**: revisados `data-model.md` y `contracts/` — ninguna entidad ni
contrato introduce una capa, patrón o dependencia fuera de lo aprobado arriba (siguen siendo
clases planas en `lib/mutaterb/`, stdlib + RSpec/Rubocop como únicas dependencias). Gate sigue
en PASS sin cambios.

## Project Structure

### Documentation (this feature)

```text
specs/001-mutation-testing-mvp/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── cli.md
│   ├── config-schema.md
│   └── json-report-schema.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
mutaterb.gemspec
Gemfile
.rubocop.yml

exe/
└── mutaterb                     # entry point ejecutable de la gem

lib/
├── mutaterb.rb                  # require de toda la librería
└── mutaterb/
    ├── cli.rb                   # parseo de flags (OptionParser) y punto de entrada del comando
    ├── config.rb                # carga/mergea YAML + flags, valida (FR-007, FR-008, FR-009, FR-011)
    ├── project_detector.rb      # detecta Ruby puro vs Rails y ubica specs (FR-001, FR-002)
    ├── test_case.rb             # entidad TestCase
    ├── test_suite.rb            # entidad TestSuite (specs detectados + duraciones base)
    ├── test_runner.rb           # ejecuta RSpec del proyecto objetivo vía Open3, con timeout (FR-003, FR-014)
    ├── mutator.rb                # localiza nodos mutables vía RubyVM::AbstractSyntaxTree y aplica/revierte el patch de texto
    ├── mutation_operators/
    │   ├── base_operator.rb
    │   ├── conditional_boundary_operator.rb
    │   ├── boolean_literal_operator.rb
    │   ├── nil_literal_operator.rb
    │   └── arithmetic_comparison_operator.rb
    ├── mutant.rb                 # entidad Mutant (estado, ubicación, operador)
    ├── mutation_run.rb           # orquesta una corrida completa (entidad MutationRun)
    └── reporter.rb                # salida por consola + export JSON (FR-006, FR-015)

spec/
├── spec_helper.rb
└── mutaterb/
    ├── cli_spec.rb
    ├── config_spec.rb
    ├── project_detector_spec.rb
    ├── test_runner_spec.rb
    ├── mutator_spec.rb
    ├── mutation_operators/
    │   └── ...
    ├── mutation_run_spec.rb
    └── reporter_spec.rb
```

**Structure Decision**: Opción 1 (single project) — gema Ruby plana. Sin `backend/`/`frontend`
ni capas tipo Clean Architecture: cada archivo en `lib/mutaterb/` es una clase con una
responsabilidad concreta, según el Principio IV de la constitución.

## Complexity Tracking

> No aplica — la Constitution Check no encontró violaciones que requieran justificación.
