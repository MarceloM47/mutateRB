---

description: "Task list template for feature implementation"
---

# Tasks: Fix Minitest Baseline Truncated by an Early Test Failure

**Input**: Design documents from `/specs/006-fix-minitest-chain-halt/`

**Prerequisites**: plan.md, spec.md, research.md, quickstart.md (todos presentes; no aplica
`data-model.md` ni `contracts/` — ver plan.md)

**Tests**: se agrega un test de regresión junto al fix, siguiendo la misma convención que el
resto del proyecto.

**Organization**: una sola User Story (P1); no hay Setup ni Foundational porque el fix es
autocontenido en un solo archivo, igual que la feature 003.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

No aplica.

## Phase 2: Foundational

No aplica — sin prerrequisitos bloqueantes.

## Phase 3: User Story 1 - Reliable results on a Minitest project with any failing test (Priority: P1)

**Goal**: que un archivo de test con un fallo no le impida correr a los archivos siguientes en
la misma corrida (baseline o por mutante).

**Independent Test**: proyecto Minitest con 2 archivos, el primero con un test que falla;
confirmar que el segundo igual corre y que un mutante mapeado a él se clasifica con su propio
test relacionado (Escenario 1 de quickstart.md).

### Implementation for User Story 1

- [X] T001 [US1] Cambiar el separador entre archivos de `&&` a `;` en
      `MinitestAdapter.command_for` (`lib/mutaterb/test_adapters/minitest_adapter.rb:20-23`),
      con un comentario explicando por qué (`ruby`/`bin/rails test` sale con status distinto de
      cero ante cualquier test fallido, y nada en el código lee ese exit status) (FR-001,
      FR-002, research.md #1/#2)
- [X] T002 [US1] Actualizar el test existente de `spec/mutaterb/test_adapters/
      minitest_adapter_spec.rb` que esperaba `" && "` para que ahora espere `" ; "`, y agregar
      un test de regresión que arma el comando real, fuerza que el primer archivo falle
      (reemplazándolo por `false`), y confirma que el marcador del segundo archivo igual
      aparece en el output — depende de T001
- [X] T003 [US1] Correr `bundle exec rake spec` + `bundle exec rubocop` completos y confirmar
      cero regresiones (FR-003, SC-003) — depende de T001, T002
- [X] T004 [US1] Validar manualmente el Escenario 1 de quickstart.md: proyecto de 2 archivos
      (uno con test roto, otro con un mutante propio) — confirmar que el baseline reporta el
      test roto como pre-broken (prueba que el primer archivo corrió) y que el mutante del
      segundo archivo se clasifica con su propio test relacionado, no con una lista de
      fallback (SC-001, SC-002) — depende de T001

**Checkpoint**: el fix está probado (test de regresión + validación manual) y no rompe nada
existente.

## Phase 4: Polish & Cross-Cutting Concerns

- [X] T005 [P] Bump de `lib/mutaterb/version.rb` a la próxima versión PATCH (bugfix, no rompe
      compatibilidad)
- [X] T006 Commit, push a `main`, y tag `vX.Y.Z` correspondiente

---

## Dependencies & Execution Order

- T001 → T002 → T003 → T004 (secuencial: cada uno depende de que el anterior esté hecho)
- T005 y T006 dependen de que T001–T004 estén completos.
- Sin oportunidades de paralelismo reales — es un cambio de una línea con su verificación.

## Implementation Strategy

Al ser un fix de una sola línea (T001) más su test de regresión y verificación, no hay "MVP
parcial" que discutir: T001–T006 se completan en una sola pasada.
