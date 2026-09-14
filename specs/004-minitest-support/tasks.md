---

description: "Task list template for feature implementation"
---

# Tasks: Minitest Support

**Input**: Design documents from `/specs/004-minitest-support/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md
(todos presentes)

**Tests**: el spec no pide TDD explícito, pero sigue la misma convención ya establecida en la
feature 001 (`plan.md` de esta feature dedica un archivo de spec por componente nuevo/tocado)
— se incluyen tareas de test junto a su implementación.

**Organization**: 2 user stories (P1: correr Minitest; P2: ambos frameworks presentes /
override explícito). Foundational cubre lo que ambas necesitan: el campo de config, la
detección de framework, la generalización de `TestSuite`, y la extracción de `RspecAdapter`
(refactor sin cambio de comportamiento, necesario antes de poder agregar `MinitestAdapter`
sin duplicar la lógica de spawn/timeout/kill).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

No aplica — no hay inicialización de proyecto nueva; se extiende la gema ya existente.

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: lo mínimo que ambas user stories necesitan antes de poder construirse.

**⚠️ CRITICAL**: ninguna user story puede empezar hasta terminar esta fase.

- [X] T001 Agregar el campo `test_framework` (`:auto`/`:rspec`/`:minitest`, default
      `:auto`) a `lib/mutaterb/config.rb`, con validación: "Debe ser uno de `:auto`, `:rspec`,
      `:minitest`" (data-model.md, FR-003)
- [X] T002 Extender `ProjectDetector::Detection` (Struct) con un campo `test_framework` y
      agregar la lógica de detección en `lib/mutaterb/project_detector.rb`: si
      `config.test_framework` no es `:auto`, usarlo directo; si es `:auto`, candidato RSpec si
      hay `spec/**/*_spec.rb`, candidato Minitest si hay `test/**/*_test.rb`, y si solo uno
      tiene archivos, usar ese (FR-001, research.md #1) — depende de T001
- [X] T003 [P] Generalizar `TestSuite#framework` en `lib/mutaterb/test_suite.rb`: dejar de
      hardcodear `:rspec` en el constructor, recibirlo como parámetro, y agregar
      `VALID_FRAMEWORKS = %i[rspec minitest]` (data-model.md)
- [X] T004 Extraer la lógica específica de RSpec de `lib/mutaterb/test_runner.rb`
      (`rspec_command`, `parse_output`) a una nueva clase `lib/mutaterb/test_adapters/
      rspec_adapter.rb`, y actualizar `TestRunner` para delegar a un adapter elegido por un
      hash `ADAPTERS = { rspec: RspecAdapter }` (mismo patrón que `Mutator::OPERATORS`) — es
      un refactor puro, **sin cambio de comportamiento observable** (research.md #3); los 35
      tests existentes deben seguir pasando igual después de este paso
- [X] T005 Generalizar `Mutator#mapped_spec_file` en `lib/mutaterb/mutator.rb` a
      `mapped_test_file`, parametrizado por el framework detectado: `spec/` + sufijo
      `_spec.rb` para RSpec (sin cambio), `test/` + sufijo `_test.rb` para Minitest
      (research.md #5) — depende de T002

**Checkpoint**: el refactor de T004 no rompe nada (`bundle exec rake spec` sigue en 35/35);
`Config`/`ProjectDetector`/`TestSuite` ya saben hablar de "framework" en abstracto, aunque
Minitest todavía no tiene adapter propio.

---

## Phase 3: User Story 1 - Run mutation testing on a Minitest project (Priority: P1) 🎯 MVP

**Goal**: que un proyecto Ruby o Rails que usa Minitest (sin RSpec) funcione con `mutaterb` sin
flags, con el mismo resultado killed/survived por test individual que ya entrega RSpec.

**Independent Test**: correr `mutaterb` dentro de un proyecto con `test/**/*_test.rb` y sin
`spec/`; confirmar que detecta y analiza esos tests (Escenario 1 y 4 de quickstart.md).

### Implementation for User Story 1

- [X] T006 [US1] Implementar `MinitestAdapter#command_for(files, project_type:)` en
      `lib/mutaterb/test_adapters/minitest_adapter.rb`: `bin/rails test <archivos> -v` si
      `project_type == :rails`; si no, `ruby -Itest -Ilib <archivo> -v` por archivo, uniendo
      con `&&` si `files` tiene más de uno (research.md #4) — depende de T004
- [X] T007 [US1] Implementar `MinitestAdapter#parse(raw)` parseando líneas con la forma
      `ClassName#test_method_name = 0.0123 s = .` (`.`=passed, `F`/`E`=failed, `S`=excluido de
      la lista, no contado como passed/failed), devolviendo el mismo shape de hash que
      `RspecAdapter#parse` (`id:`, `description:`, `file_path:`, `status:`, `duration:`)
      (research.md #2, data-model.md) — depende de T006
- [X] T008 [US1] Registrar `minitest: MinitestAdapter` en el hash `ADAPTERS` de
      `lib/mutaterb/test_runner.rb` — depende de T004, T007
- [X] T009 [US1] Conectar el `test_framework` detectado por `ProjectDetector` hasta la
      construcción de `TestSuite`/`TestRunner` en `lib/mutaterb/cli.rb`, para que un proyecto
      solo-Minitest use el adapter correcto de punta a punta — depende de T002, T003, T008
- [X] T010 [P] [US1] Tests de `MinitestAdapter` en
      `spec/mutaterb/test_adapters/minitest_adapter_spec.rb`: construcción del comando (Rails
      vs. Ruby puro, un archivo vs. varios) y parseo de líneas passed/failed/error/skip —
      depende de T007
- [X] T011 [P] [US1] Extender `spec/mutaterb/project_detector_spec.rb` con un fixture
      solo-Minitest (`test/` con archivos, sin `spec/`) confirmando
      `detection.test_framework == :minitest` — depende de T002
- [X] T012 [US1] Correr manualmente los Escenarios 1 y 4 de quickstart.md (proyecto Ruby puro
      con Minitest; test débil vs. fuerte nombrado por test individual) — depende de
      T009, T010, T011

**Checkpoint**: un proyecto solo-Minitest funciona de punta a punta, con la misma precisión
por test individual que ya tenía RSpec.

---

## Phase 4: User Story 2 - Proyectos con RSpec y Minitest presentes a la vez (Priority: P2)

**Goal**: que un proyecto con ambos frameworks tenga un comportamiento explícito y
controlable, no ambiguo.

**Independent Test**: correr `mutaterb` contra un fixture con `spec/` y `test/` presentes,
con y sin `--framework` (Escenario 2 y 3 de quickstart.md).

### Implementation for User Story 2

- [X] T013 [US2] Agregar el flag `--framework FRAMEWORK` en `lib/mutaterb/flag_parser.rb`,
      mapeado a la clave `test_framework` de `Config` (contracts/framework-detection.md) —
      depende de T001
- [X] T014 [US2] Implementar el caso "ambos presentes": `ProjectDetector` elige RSpec por
      default, y `lib/mutaterb/cli.rb` imprime una línea informativa antes del resumen (p. ej.
      `mutaterb: se detectaron RSpec y Minitest — usando RSpec...`) cuando eso ocurre (FR-002,
      contracts/framework-detection.md) — depende de T002, T013
- [X] T015 [US2] Agregar el campo `"framework"` al objeto `config` del JSON exportado en
      `lib/mutaterb/reporter.rb` (contracts/framework-detection.md) — depende de T009
- [X] T016 [P] [US2] Tests en `spec/mutaterb/config_spec.rb`: `test_framework` inválido se
      rechaza, y un flag `--framework` gana sobre el valor del archivo de config (mismo patrón
      que ya existe para `strictness`) — depende de T001, T013
- [X] T017 [P] [US2] Extender `spec/mutaterb/project_detector_spec.rb` con un fixture que
      tiene `spec/` y `test/` a la vez: confirmar que gana RSpec por default, y que
      `test_framework: :minitest` fuerza Minitest — depende de T014
- [X] T018 [US2] Correr manualmente los Escenarios 2 y 3 de quickstart.md (ambos frameworks
      presentes; proyecto Rails con Minitest vía `bin/rails test`) — depende de
      T014, T015, T016, T017

**Checkpoint**: ambas user stories funcionan de forma independiente; el spec completo (FR-001
a FR-009) queda cubierto.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T019 [P] Bump de `lib/mutaterb/version.rb` a la próxima versión MINOR (FR-008)
- [X] T020 [P] Actualizar `README.md`: mencionar soporte Minitest y el flag `--framework`
- [X] T021 Correr `bundle exec rake spec` + `bundle exec rubocop` completos y confirmar cero
      regresiones sobre los fixtures RSpec-only ya existentes (SC-002) — depende de todo lo
      anterior

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: bloquea ambas user stories.
- **User Story 1 (Phase 3)**: depende solo de Foundational.
- **User Story 2 (Phase 4)**: depende de Foundational; reutiliza el `test_framework` que ya
  agregó T001/T002, pero no depende de que Minitest funcione de punta a punta (T006-T012) —
  podría implementarse en paralelo con Phase 3 si hay más de una persona trabajando.
- **Polish (Phase 5)**: depende de que ambas user stories estén completas.

### Parallel Opportunities

- Foundational: T003 en paralelo con T002/T004 (archivos distintos)
- US1: T010 y T011 en paralelo entre sí tras T007/T002 respectivamente
- US2: T016 y T017 en paralelo entre sí tras T013/T014 respectivamente
- Polish: T019 y T020 en paralelo

---

## Parallel Example: Foundational

```bash
# T002 y T003 pueden arrancar juntos apenas termina T001:
Task: "Extender ProjectDetector::Detection con test_framework en lib/mutaterb/project_detector.rb"
Task: "Generalizar TestSuite#framework en lib/mutaterb/test_suite.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 2 (Foundational) — incluye el refactor de T004, que debe dejar la suite existente
   intacta antes de seguir.
2. Phase 3 (US1) → validar con Escenarios 1 y 4 de quickstart.md — **acá ya hay valor real**:
   Minitest funciona.
3. Phase 4 (US2) → validar con Escenarios 2 y 3 (comportamiento explícito con ambos
   frameworks).
4. Phase 5 (Polish) → bump de versión + README + verificación final de no-regresión.

### Incremental Delivery

Cada checkpoint de fase es un punto seguro para probar manualmente antes de seguir con la
siguiente.
