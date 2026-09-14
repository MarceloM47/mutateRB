# Implementation Plan: Fix Flaky CI Tests in TestRunner's Fixture Setup

**Branch**: `003-fix-flaky-ci-tests` | **Date**: 2026-09-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-fix-flaky-ci-tests/spec.md`

## Summary

`spec/mutaterb/test_runner_spec.rb#before(:all)` arma un proyecto de fixture temporal y le
corre `bundle install --quiet` vía `system(...)` sin aislar el entorno de Bundler heredado del
proceso que corre la propia suite de MutateRB. En CI (`bundler-cache: true` deja un contexto
de Bundler más estricto que en una máquina local) ese `bundle install` anidado queda afectado
por el `BUNDLE_GEMFILE`/`BUNDLE_PATH`/`RUBYOPT` externo y el fixture nunca termina de
bundlearse — los dos tests que dependen de correr RSpec real dentro de ese fixture
(`kills the hung process...`, `runs the baseline...`) fallan como consecuencia. El fix aplica
el mismo mecanismo que ya protege el código de producción (`Bundler.with_unbundled_env`,
tarea T041 de la feature 001) a esta llamada de setup de test.

## Technical Context

**Language/Version**: Ruby 3.x (mismo stack que la feature 001, sin cambios)

**Primary Dependencies**: `bundler` (stdlib/default gem, ya usado por T041), RSpec

**Storage**: N/A

**Testing**: RSpec — este fix es exclusivamente sobre la fiabilidad de la propia suite de
tests

**Target Platform**: GitHub Actions (Ubuntu, matriz Ruby 3.0–3.3) + cualquier máquina local

**Project Type**: Single project — gem Ruby existente (sin cambios de estructura)

**Performance Goals**: N/A

**Constraints**: El fix no debe cambiar el comportamiento observable de los tests (mismos
asserts, mismo fixture) — solo aislar el entorno en el que corre el `bundle install` del
setup.

**Scale/Scope**: Un solo archivo (`spec/mutaterb/test_runner_spec.rb`), una sola llamada
(`before(:all)`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Chequeo | Resultado |
|---|---|---|
| I. Naturaleza y Propósito | ¿Este fix sirve al propósito de la herramienta o es scope creep? | PASS — arregla la confiabilidad de la propia suite de MutateRB, no agrega funcionalidad nueva. |
| II. Stack Tecnológico | ¿Se mantiene 100% Ruby, sin nuevas dependencias? | PASS — reutiliza `bundler` (ya requerido en T041), ninguna gem nueva. |
| IV. Estructura y Estilo | ¿El fix es mínimo y no introduce complejidad? | PASS — un `Bundler.with_unbundled_env { ... }` envolviendo la línea existente, mismo patrón ya usado en `lib/mutaterb/test_runner.rb`. |
| V. Manejo de Errores y Validaciones | ¿Aplica? | N/A para este fix — no cambia manejo de errores de producción, solo aislamiento de un setup de test. |
| Comportamiento del Agente de IA | ¿El plan se limita a lo documentado en spec.md? | PASS — alcance limitado a FR-001/FR-002/FR-003 del spec, sin tocar `lib/`. |

Sin violaciones detectadas. No aplica "Complexity Tracking".

**Re-chequeo post-Phase 1**: `research.md` y `quickstart.md` no introducen nada fuera de lo
aprobado arriba. Gate sigue en PASS.

## Project Structure

### Documentation (this feature)

```text
specs/003-fix-flaky-ci-tests/
├── plan.md              # This file
├── research.md          # Phase 0 output
└── quickstart.md        # Phase 1 output
```

No aplica `data-model.md` (no hay entidades de dominio involucradas) ni `contracts/` (no hay
interfaz externa nueva ni modificada) — se omiten per las reglas de la Phase 1 ("skip if
project is purely internal").

### Source Code (repository root)

```text
spec/
└── mutaterb/
    └── test_runner_spec.rb   # único archivo tocado: aislar el bundle install del fixture
```

**Structure Decision**: Ningún cambio de estructura — es un fix puntual de una sola línea de
setup dentro de un archivo de spec ya existente.

## Complexity Tracking

> No aplica — la Constitution Check no encontró violaciones que requieran justificación.
