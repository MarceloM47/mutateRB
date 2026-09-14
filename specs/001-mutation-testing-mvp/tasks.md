---

description: "Task list template for feature implementation"
---

# Tasks: MutateRB — Mutation Testing para Ruby/Rails (MVP)

**Input**: Design documents from `/specs/001-mutation-testing-mvp/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (todos presentes)

**Tests**: el spec no pide explícitamente TDD, pero `plan.md` ya define una carpeta `spec/`
que espeja `lib/mutaterb/` (Principio IV/V de la constitución: Rubocop + validación
rigurosa). Se incluye una tarea de test por componente relevante, escrita junto a su
implementación (no como ciclo TDD estricto de "debe fallar primero").

**Organization**: Tareas agrupadas por user story para poder implementar y testear cada una
de forma independiente.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede correr en paralelo (archivo distinto, sin dependencias pendientes)
- **[Story]**: a qué user story de spec.md pertenece (US1, US2, US3)
- Cada tarea incluye la ruta exacta del archivo

## Path Conventions

Single project (gema Ruby) — rutas bajo la raíz del repo: `lib/`, `exe/`, `spec/` (ver
"Project Structure" en plan.md).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: inicialización del proyecto como gema Ruby

- [X] T001 Crear el esqueleto de la gema: `mutaterb.gemspec`, `Gemfile`, `lib/mutaterb.rb`
      (requiere todo `lib/mutaterb/*`), `exe/mutaterb` (shebang + `require "mutaterb"` +
      `MutateRB::CLI.run(ARGV)`), según la estructura de `plan.md`
- [X] T002 [P] Configurar `.rubocop.yml` en la raíz (Principio IV de la constitución:
      "Rubocop es obligatorio para mantener consistencia de estilo en todo el código")
- [X] T003 [P] Agregar RSpec y Rubocop como `development` dependencies en
      `mutaterb.gemspec` y crear `spec/spec_helper.rb`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: entidades y errores compartidos que TODAS las user stories necesitan

**⚠️ CRITICAL**: ninguna user story puede empezar hasta terminar esta fase

- [X] T004 Crear jerarquía de errores propios (`MutateRB::ConfigError`,
      `MutateRB::MutationError`) en `lib/mutaterb/errors.rb` — usados por todo el sistema
      para nunca dejar una excepción sin capturar (Principio V: "todo posible error DEBE
      capturarse mediante `begin/rescue`")
- [X] T005 [P] Crear entidad `Mutant` en `lib/mutaterb/mutant.rb` con los campos de
      data-model.md (`id`, `operator_type`, `file_path`, `line`, `column_range`,
      `original_fragment`, `mutated_fragment`, `status`, `kill_reason`, `related_tests`,
      `failing_tests`, `error_message`) y la transición de estado: "`:pending` es el único
      estado inicial; transiciona una sola vez a exactamente uno de `:killed`, `:survived`,
      `:error`"
- [X] T006 [P] Crear entidad `TestCase` en `lib/mutaterb/test_case.rb` con `id`,
      `description`, `file_path`, `baseline_status` (`:passed`/`:failed`),
      `baseline_duration_seconds`
- [X] T007 [P] Crear entidad `TestSuite` en `lib/mutaterb/test_suite.rb` con `framework`
      (fijo en `:rspec`), `project_type` (`:ruby`/`:rails`), `test_cases`
- [X] T008 Crear entidad `Config` en `lib/mutaterb/config.rb` solo con los defaults de
      data-model.md (`target_dir: "."`, `include_paths: []`, `exclude_paths: []`,
      `strictness: :default`, `mutation_types`: todos los operadores registrados,
      `exit_on_survivors: true`, `json_output_path: nil`) — la carga de YAML, el parseo de
      flags y la validación completa se implementan en la Phase 5 (US3)
- [X] T009 Crear entidad `MutationRun` en `lib/mutaterb/mutation_run.rb` con `config`,
      `test_suite`, `mutants`, `baseline_broken_tests`, `started_at`/`finished_at`,
      `interrupted`, y los métodos derivados `survived?` y `summary` (placeholder, se
      completan en Phase 4/US2)
- [X] T010 Crear el esqueleto de `lib/mutaterb/cli.rb` (clase `MutateRB::CLI` con método
      `.run(argv)` que arma un `Config` por defecto y termina con exit code `0`) y verificar
      que `exe/mutaterb` lo invoca correctamente

**Checkpoint**: la gema instala y `mutaterb` corre sin crashear (aunque no haga nada útil
todavía) — recién ahora pueden empezar las user stories

---

## Phase 3: User Story 1 - Correr mutation testing sin configuración previa (Priority: P1) 🎯 MVP

**Goal**: detectar automáticamente el tipo de proyecto (Ruby/Rails) y sus specs RSpec, aplicar
mutaciones al código cubierto, ejecutar los tests relevantes con timeout, y restaurar siempre
el archivo original — sin necesitar ningún archivo de configuración.

**Independent Test**: correr `mutaterb` sin flags ni config dentro de un proyecto Ruby de
ejemplo con RSpec y verificar que encuentra los tests y produce un resultado (ver Escenario 1
de quickstart.md).

### Implementation for User Story 1

- [X] T011 [P] [US1] Implementar `ProjectDetector` en `lib/mutaterb/project_detector.rb`:
      Rails si existe `config/application.rb` o `bin/rails`, Ruby puro en otro caso; specs
      descubiertos con `Dir.glob("spec/**/*_spec.rb")` relativo a la raíz detectada (FR-001,
      FR-002); si no hay ningún spec, debe permitir a la CLI terminar con "un mensaje claro
      indicando que no encontró tests, sin lanzar un error no controlado" (Edge Case del spec)
- [X] T012 [US1] Implementar en `lib/mutaterb/test_runner.rb` la corrida base: ejecutar
      `bundle exec rspec --format json` vía `Process.spawn` en el directorio del proyecto
      objetivo (con `RAILS_ENV=test` si `project_type == :rails`), parsear el JSON de RSpec
      con `JSON.parse` (stdlib) y poblar `TestCase#baseline_status` y
      `TestCase#baseline_duration_seconds` para cada test (FR-003 parcial, insumo de FR-012 y
      FR-014)
- [X] T013 [US1] Extender `lib/mutaterb/test_runner.rb` para ejecutar un test puntual contra
      una mutación con timeout = "el doble del tiempo que ese mismo test tardó en la corrida
      base (sin mutar), con un piso mínimo de 5 segundos" (FR-014): usar `Process.spawn` +
      `Timeout.timeout` y, si expira, matar el proceso explícitamente con
      `Process.kill("TERM", pid)` (con `"KILL"` de respaldo) — depende de T012
- [X] T014 [US1] Implementar `MutateRB::MutationOperators::BaseOperator` en
      `lib/mutaterb/mutation_operators/base_operator.rb`: localizar nodos mutables vía
      `RubyVM::AbstractSyntaxTree.parse_file` y aplicar/revertir el mutante como reemplazo de
      texto quirúrgico sobre el string fuente original (research.md #1) — no reserializar el
      archivo completo
- [X] T015 [P] [US1] Implementar `ConditionalBoundaryOperator` en
      `lib/mutaterb/mutation_operators/conditional_boundary_operator.rb` (hereda de
      BaseOperator; depende de T014)
- [X] T016 [P] [US1] Implementar `BooleanLiteralOperator` en
      `lib/mutaterb/mutation_operators/boolean_literal_operator.rb` (depende de T014)
- [X] T017 [P] [US1] Implementar `NilLiteralOperator` en
      `lib/mutaterb/mutation_operators/nil_literal_operator.rb` (depende de T014)
- [X] T018 [P] [US1] Implementar `ArithmeticComparisonOperator` en
      `lib/mutaterb/mutation_operators/arithmetic_comparison_operator.rb` (depende de T014)
- [X] T019 [US1] Implementar `Mutator` en `lib/mutaterb/mutator.rb`: para cada `Mutant`
      generado, aplicar el patch, invocar `TestRunner` (T013) sobre los tests relacionados, y
      **siempre** (bloque `ensure`) restaurar el archivo original — "El sistema DEBE restaurar
      el código fuente original después de cada mutación, incluso si la ejecución de tests
      falla de forma inesperada o el proceso se interrumpe" (FR-005); cualquier mutación que
      genere código no parseable se captura y marca `status: :error` sin abortar el resto de
      la corrida (FR-010) — depende de T011-T018
- [X] T020 [US1] Implementar manejo de `SIGINT` en `lib/mutaterb/cli.rb` (`Signal.trap`):
      restaurar cualquier archivo mutado en progreso (delegando en Mutator) y terminar con
      exit code `130` (contracts/cli.md) — depende de T019
- [X] T021 [US1] Conectar el comando por defecto en `lib/mutaterb/cli.rb`: `ProjectDetector`
      → `TestRunner` (corrida base) → generar `Mutant`s con los operadores → `Mutator` →
      imprimir un resumen mínimo por stdout (conteos de mutantes) vía un `Reporter` inicial
      en `lib/mutaterb/reporter.rb` — cubre los Acceptance Scenarios 1-3 de User Story 1 —
      depende de T011-T020
- [X] T022 [P] [US1] Tests de `ProjectDetector` en
      `spec/mutaterb/project_detector_spec.rb` (Ruby puro, Rails, sin tests encontrados)
- [X] T023 [P] [US1] Tests de `Mutator` en `spec/mutaterb/mutator_spec.rb` (el archivo queda
      idéntico al original tras una corrida normal, tras un error de mutación, y tras una
      interrupción simulada — SC-004)
- [X] T024 [P] [US1] Tests de `TestRunner` en `spec/mutaterb/test_runner_spec.rb` (timeout
      mata el proceso colgado y no dejarlo corriendo en background)

**Checkpoint**: `mutaterb` corrido sin config sobre un proyecto Ruby o Rails de ejemplo
detecta tests, aplica mutaciones, y termina siempre con el código fuente intacto.

---

## Phase 4: User Story 2 - Identificar tests débiles (Priority: P1)

**Goal**: clasificar cada mutación como "killed"/"survived"/"error", excluir tests que ya
fallaban antes de mutar, y reportar el detalle accionable de las mutaciones "survived" —
en consola y opcionalmente en JSON.

**Independent Test**: introducir un test fuerte y uno débil sobre el mismo método y confirmar
que el reporte los distingue correctamente (ver Escenario 2 de quickstart.md).

### Implementation for User Story 2

- [X] T025 [US2] Completar la clasificación en `lib/mutaterb/mutant.rb` /
      `lib/mutaterb/mutation_run.rb`: mapear el resultado crudo de `Mutator`/`TestRunner`
      (T019) a `status` (`:killed`/`:survived`/`:error`) y `kill_reason`
      (`:assertion_failure`/`:timeout`) por cada `Mutant` — depende de Phase 3 completa
- [X] T026 [US2] Implementar la exclusión de tests base rotos en
      `lib/mutaterb/test_suite.rb`/`lib/mutaterb/test_runner.rb`: todo `TestCase` con
      `baseline_status == :failed` se excluye del conteo "killed/survived" de cualquier
      `Mutant` que dependa de él y se agrega a `MutationRun#baseline_broken_tests` (FR-012)
- [X] T027 [US2] Completar `Reporter#to_console` en `lib/mutaterb/reporter.rb`: resumen con
      total de mutaciones, cuántas "killed" y cuántas "survived", y el detalle de cada
      mutación "survived" con archivo, línea y test(s) relacionados (FR-006); debe cubrir el
      100% de las mutaciones "survived" (SC-002)
- [X] T028 [P] [US2] Implementar `Reporter#to_json` en `lib/mutaterb/reporter.rb` y el flag
      `--json-output PATH` en `lib/mutaterb/cli.rb`, siguiendo exactamente
      contracts/json-report-schema.md (FR-015)
- [X] T029 [P] [US2] Tests de clasificación y exclusión de baseline en
      `spec/mutaterb/mutation_run_spec.rb`
- [X] T030 [P] [US2] Tests de `Reporter` en `spec/mutaterb/reporter_spec.rb` (consola y
      conformidad del JSON contra contracts/json-report-schema.md)

**Checkpoint**: User Stories 1 y 2 juntas entregan el MVP completo: detectar, mutar, y
reportar tests débiles con evidencia accionable, sin ninguna configuración.

---

## Phase 5: User Story 3 - Configurar alcance y estricticidad (Priority: P2)

**Goal**: permitir fijar carpeta objetivo, estricticidad, tipos de mutación y política de
exit code vía `.mutaterb.yml` y/o flags de CLI, con los flags ganando sobre el archivo.

**Independent Test**: correr la CLI dos veces sobre el mismo proyecto —default vs. carpeta y
tipo de mutación limitados— y confirmar que la segunda corrida solo mutó lo indicado (ver
Escenario 3 de quickstart.md).

### Implementation for User Story 3

- [X] T031 [US3] Implementar la carga de `.mutaterb.yml` en `lib/mutaterb/config.rb` con
      `YAML.safe_load` y las reglas de contracts/config-schema.md: rechazar mapping inválido,
      rechazar tipos de clave incorrectos, `strictness` fuera de `{low, default, high}`,
      `mutation_types` con operadores no registrados — todo error se convierte en
      `MutateRB::ConfigError` con mensaje humano-legible, nunca una excepción sin capturar
      (FR-007, FR-011)
- [X] T032 [US3] Implementar el parseo de flags con `OptionParser` en `lib/mutaterb/cli.rb`
      según contracts/cli.md: `--dir`, `--include`, `--exclude`, `--strictness`,
      `--mutation-types`, `--exit-zero`, `--json-output`, `--config` (FR-008)
- [X] T033 [US3] Implementar el merge de precedencia en `lib/mutaterb/config.rb`: cargar y
      validar el YAML (T031), luego sobrescribir campo por campo con cualquier flag presente
      (T032) — "Cuando un flag de CLI y el archivo de configuración definen la misma opción
      con valores distintos, el sistema DEBE priorizar el valor del flag de CLI" (FR-009) —
      depende de T031, T032
- [X] T034 [US3] Aplicar `include_paths`/`exclude_paths` (exclude gana sobre include si se
      solapan) y el mapeo `strictness` → `mutation_types`/criterio de test fuerte en
      `lib/mutaterb/project_detector.rb` y `lib/mutaterb/mutator.rb` — depende de T033
- [X] T035 [US3] Implementar la política de exit code en `lib/mutaterb/cli.rb` según
      contracts/cli.md: `0` sin "survived" (o `exit_on_survivors: false` sin errores), `1` con
      al menos un "survived", `2` para errores operativos (config inválida, sin tests), `130`
      en `SIGINT` (FR-013) — depende de T033, T020
- [X] T036 [P] [US3] Tests de `Config` en `spec/mutaterb/config_spec.rb`: la tabla de
      validación de data-model.md completa (tipos, defaults, enums) y la precedencia
      flag > YAML
- [X] T037 [P] [US3] Tests de `CLI` en `spec/mutaterb/cli_spec.rb`: parseo de cada flag y
      cada exit code de contracts/cli.md

**Checkpoint**: las 3 user stories funcionan de forma independiente; el spec completo (FR-001
a FR-015) queda cubierto.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: cierre de calidad transversal, no ligado a una sola user story

- [X] T038 [P] Pasar Rubocop sobre todo `lib/` y `spec/` y corregir hallazgos (Principio IV)
- [X] T039 Completar metadata final de `mutaterb.gemspec` (versión, summary, `files`,
      `executables`)
- [X] T040 Ejecutar manualmente los 4 escenarios de `quickstart.md` de punta a punta sobre un
      proyecto Ruby y uno Rails de ejemplo, y confirmar que coinciden con lo esperado

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias, arranca de inmediato
- **Foundational (Phase 2)**: depende de Setup — bloquea las 3 user stories
- **User Story 1 (Phase 3)**: depende solo de Foundational
- **User Story 2 (Phase 4)**: depende de Foundational **y** de que Phase 3 (Mutator/TestRunner
  produciendo resultado crudo) esté completa — no es independiente en el sentido de
  implementación (clasifica lo que US1 ya ejecuta), pero sí es demostrable/testeable como
  incremento propio una vez que US1 está lista
- **User Story 3 (Phase 5)**: depende de Foundational; reutiliza `ProjectDetector`/`Mutator`
  de US1, pero puede implementarse sin esperar a US2
- **Polish (Phase 6)**: depende de que las user stories que se vayan a entregar estén listas

### Parallel Opportunities

- Setup: T002 y T003 en paralelo
- Foundational: T005, T006, T007 en paralelo (entidades independientes); T004 y T008-T010 son
  secuenciales entre sí por simplicidad de wiring
- US1: T015-T018 (los 4 operadores) en paralelo entre sí tras T014; T022-T024 (tests) en
  paralelo entre sí tras T021
- US2: T028 en paralelo con T027 (archivos distintos); T029-T030 en paralelo
- US3: T036-T037 en paralelo tras T035
- Polish: T038 en paralelo con T039

---

## Parallel Example: User Story 1

```bash
# Tras completar T014 (BaseOperator), lanzar los 4 operadores en paralelo:
Task: "Implementar ConditionalBoundaryOperator en lib/mutaterb/mutation_operators/conditional_boundary_operator.rb"
Task: "Implementar BooleanLiteralOperator en lib/mutaterb/mutation_operators/boolean_literal_operator.rb"
Task: "Implementar NilLiteralOperator en lib/mutaterb/mutation_operators/nil_literal_operator.rb"
Task: "Implementar ArithmeticComparisonOperator en lib/mutaterb/mutation_operators/arithmetic_comparison_operator.rb"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

Ambas son P1 y, juntas, son el MVP real: US1 sin US2 solo produce números crudos sin el
valor central de la herramienta (identificar tests débiles); US2 no existe sin el motor de
US1. Orden sugerido:

1. Phase 1 (Setup) → Phase 2 (Foundational)
2. Phase 3 (US1) → validar con Escenario 1 de quickstart.md
3. Phase 4 (US2) → validar con Escenario 2 de quickstart.md — **acá ya hay un MVP demostrable**
4. Phase 5 (US3) → validar con Escenario 3 de quickstart.md (incremento de configurabilidad)
5. Phase 6 (Polish) → validar Escenario 4 (resiliencia) de punta a punta

### Incremental Delivery

Cada checkpoint de fase es un punto seguro para hacer una demo o cortar una versión interna de
la gema antes de seguir con la siguiente.

---

## Phase 7: Convergence

- [X] T041 Sanitizar las variables de entorno `BUNDLE_*`/`RUBYOPT` heredadas antes de
      spawnear `bundle exec rspec` en `lib/mutaterb/test_runner.rb#spawn_rspec`, para que el
      subproceso use el `Gemfile`/RSpec del proyecto objetivo y no el de MutateRB, incluso
      cuando `mutaterb` se invoque vía `bundle exec` (research.md #2) (contradicts)
- [X] T042 Envolver la ejecución completa (`ProjectDetector`, corrida base, `Mutator`) en
      `lib/mutaterb/cli.rb#execute` con un rescate genérico de `StandardError` que reporte el
      fallo por stderr y devuelva `CLI::EXIT_OPERATIONAL_ERROR` (2), para que ningún error no
      previsto salga sin capturar (Constitution Principio V, contracts/cli.md, SC-005)
      (partial)
- [X] T043 Implementar el efecto real de `strictness` (`low`/`default`/`high`) sobre
      `mutation_types` y/o el criterio de clasificación en `lib/mutaterb/mutator.rb`, para
      satisfacer el Acceptance Scenario 2 de User Story 3 (FR-008, US3/AC2) (partial)

---

## Phase 8: Release Readiness (RubyGems)

**Purpose**: dejar la gema lista para publicarse en RubyGems.org, agregado vía
`/speckit-clarify` + `/speckit-plan` después del MVP original (FR-016 a FR-019, SC-006).
Es un incremento independiente y verificable por su cuenta (Escenario 5 de quickstart.md), no
depende de ninguna user story de mutación en sí — solo de que la gema ya exista como tal.

**Independent Test**: `gem build mutaterb.gemspec && gem install ./mutaterb-*.gem` sin
warnings de metadata, más `rake spec` y `rubocop` en verde (Escenario 5 de quickstart.md).

- [X] T044 [P] Crear `README.md` en la raíz: título + descripción de una línea, instalación
      (`gem install mutaterb`), uso básico (comando por defecto y los flags principales de
      `contracts/cli.md`), y licencia (FR-016, research.md #11)
- [X] T045 [P] Crear `LICENSE.txt` en la raíz con el texto estándar de licencia MIT y
      "MarceloM47" como titular del copyright (FR-017, research.md #12)
- [X] T046 Actualizar `mutaterb.gemspec`: `spec.authors = ["MarceloM47"]`,
      `spec.email = ["marcelo.esteche@proton.me"]`, `spec.homepage =
      "https://github.com/MarceloM47/mutateRB"`, `spec.metadata["homepage_uri"]` y
      `spec.metadata["source_code_uri"]` apuntando a ese homepage, y agregar
      `spec.add_development_dependency "rake", "~> 13"` (FR-017, FR-018)
- [X] T047 [P] Crear `Rakefile` en la raíz: `require "bundler/gem_tasks"`,
      `require "rspec/core/rake_task"`, `RSpec::Core::RakeTask.new(:spec)`,
      `task default: :spec` (FR-018, research.md #10)
- [X] T048 [P] Crear `.github/workflows/ci.yml`: matriz de Ruby (3.0 a la última estable),
      job que corre `bundle exec rake spec`, job separado que corre `bundle exec rubocop`, en
      cada push a `main` y en cada pull request (FR-018)
- [X] T049 Crear `.github/workflows/release.yml`: trigger en push de tags `v*`, permisos
      `contents: write` + `id-token: write`, pasos `ruby/setup-ruby` +
      `rubygems/release-gem@v1` (autenticación por trusted publisher/OIDC, sin
      `RUBYGEMS_API_KEY`) (FR-019, research.md #9) — depende de T046 (la metadata del gemspec
      debe ser correcta antes de publicar con ella)
- [X] T050 Ejecutar el Escenario 5 de `quickstart.md` (`gem build`, `gem install` local,
      `mutaterb --help`, `rake spec`, `rubocop`) y confirmar que no hay warnings de metadata
      del gemspec — depende de T044-T049

**Checkpoint**: `gem build` no advierte nada, el gem se instala y funciona localmente, y CI
correría en verde si se pushea (release.yml solo se valida por inspección, no requiere
pushear un tag real para este checkpoint).
