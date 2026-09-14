---

description: "Task list template for feature implementation"
---

# Tasks: Fix Flaky CI Tests in TestRunner's Fixture Setup

**Input**: Design documents from `/specs/003-fix-flaky-ci-tests/`

**Prerequisites**: plan.md, spec.md, research.md, quickstart.md (todos presentes; no aplica
`data-model.md` ni `contracts/` — ver plan.md)

**Tests**: no se agregan tests nuevos — el fix es que los tests *ya existentes* dejen de fallar
por un problema de aislamiento de entorno, no una feature que necesite cobertura nueva.

**Organization**: una sola User Story (P1); no hay Setup ni Foundational porque el fix no
necesita infraestructura nueva, solo tocar una línea de un archivo ya existente.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

No aplica — no hay inicialización de proyecto que hacer para este fix.

## Phase 2: Foundational

No aplica — no hay prerrequisitos bloqueantes; el fix es autocontenido en un solo archivo.

## Phase 3: User Story 1 - CI pasa de forma confiable en toda la matriz de Ruby (Priority: P1)

**Goal**: que `spec/mutaterb/test_runner_spec.rb` pase igual en local y en CI, sin importar el
entorno de Bundler del proceso que corre la suite.

**Independent Test**: `bundle exec rake spec` en verde (35/35), localmente y en la próxima
corrida de CI en las 4 versiones de la matriz (Escenario 2 y 3 de quickstart.md).

### Implementation for User Story 1

- [X] T001 [US1] Envolver el `bundle install` del fixture en
      `spec/mutaterb/test_runner_spec.rb#before(:all)` con `Bundler.with_unbundled_env`
      (agregar `require "bundler"` si hace falta), replicando el mismo aislamiento que ya usa
      `lib/mutaterb/test_runner.rb#spawn_rspec` (FR-001, research.md #1)
- [X] T002 [US1] Correr `bundle exec rake spec` localmente y confirmar 35/35 en verde,
      incluyendo los dos ejemplos que fallaban en CI (FR-002, Escenario 2 de quickstart.md) —
      depende de T001
- [ ] T003 [US1] Pushear el fix y confirmar que el job `test` (matriz `3.0`–`3.3`) y el job
      `lint` de `ci.yml` terminan en verde, sin haber tocado `ci.yml` (FR-003, SC-001,
      Escenario 3 de quickstart.md) — depende de T002

**Checkpoint**: CI en verde en las 4 versiones de la matriz + lint, sin cambios en `ci.yml` ni
en `lib/mutaterb/test_runner.rb`.

## Phase 4: Polish & Cross-Cutting Concerns

No aplica — el checkpoint de la única user story ya es el criterio de aceptación completo de
la iteración (ver "Criterio de aceptación" en quickstart.md).

---

## Dependencies & Execution Order

- T001 → T002 → T003 (secuencial: cada uno depende de que el anterior haya pasado)
- Sin oportunidades de paralelismo — es una cadena de un solo cambio + dos verificaciones.

## Implementation Strategy

Al ser una sola tarea de código (T001) más dos pasos de verificación, no hay "MVP parcial"
que discutir: T001–T003 se completan en una sola pasada.
