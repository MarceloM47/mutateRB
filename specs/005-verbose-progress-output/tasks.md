---

description: "Task list template for feature implementation"
---

# Tasks: Verbose Flag and Run Progress Output

**Input**: Design documents from `/specs/005-verbose-progress-output/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md
(todos presentes)

**Tests**: el spec no pide TDD explícito, pero sigue la misma convención ya establecida en las
features anteriores (un spec de RSpec por componente nuevo/tocado) — se incluyen tareas de test
junto a su implementación.

**Organization**: 3 user stories (P1: indicador de progreso por defecto; P2: flag `--verbose`;
P3: logs limpios en no-TTY). Foundational cubre lo que las tres necesitan: el campo `verbose`
de `Config` y el conteo total de mutantes por adelantado en `Mutator` — ninguno de los dos
cambia comportamiento observable por sí solo, son prerrequisitos de datos.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

No aplica — no hay inicialización de proyecto nueva; se extiende la gema ya existente.

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: lo mínimo que las tres user stories necesitan antes de poder construirse.

**⚠️ CRITICAL**: ninguna user story puede empezar hasta terminar esta fase.

- [X] T001 Agregar el campo `verbose` (Boolean, default `false`) a
      `lib/mutaterb/config.rb`: `attr_accessor`, parámetro del constructor,
      reconocerlo en `attributes_from_yaml` (`raw.fetch("verbose", false)`, agregar
      `"verbose"` a `known_keys`), y validar en `validate!` — "Debe ser `true` o `false`"
      (mismo chequeo que ya existe para `exit_on_survivors`) (data-model.md, FR-010)
- [X] T002 [P] Memoizar la lista de candidatos en `lib/mutaterb/mutator.rb`: extraer
      `source_files.flat_map { |file| candidates_for(file) }` a un método privado
      `candidates` cacheado en `@candidates ||= ...`, y exponer `total_mutants` público
      (`= candidates.size`); `each_mutant` pasa a iterar sobre `candidates` en vez de
      recalcular por archivo — sin cambio de comportamiento observable, los 4 tipos de
      mutación y el orden de iteración quedan iguales (research.md #3, data-model.md)

**Checkpoint**: `Config` ya sabe validar `verbose` (aunque nada todavía lo setea desde la
CLI) y `Mutator#total_mutants` da el conteo correcto sin correr ningún test — la suite
existente (`bundle exec rake spec`) sigue en verde.

---

## Phase 3: User Story 1 - See that the run is actually working (Priority: P1) 🎯 MVP

**Goal**: que `mutaterb`, sin ningún flag extra, muestre el mensaje de baseline con un ticker
en vivo y un contador `procesados/total` durante el loop de mutantes, en vez del silencio
total actual.

**Independent Test**: correr `mutaterb` en un proyecto con varios mutantes y confirmar que
aparece output nuevo repetidamente durante el baseline y durante el loop, antes del resumen
final (Escenario 1 y 4 de quickstart.md).

### Implementation for User Story 1

- [X] T003 [US1] Crear `lib/mutaterb/progress_reporter.rb` con el esqueleto de
      `ProgressReporter`: estado interno protegido por `Mutex` (`phase`: `:idle`\|
      `:baseline`\|`:mutating`\|`:done`, `processed`, `total`, `phase_started_at`), un
      método privado que lanza un `Thread` de ticking (intervalo inyectable via
      `tick_interval:`, default sensato) cuyo cuerpo completo va envuelto en
      `begin ... rescue StandardError ... end` para que un fallo de dibujo nunca aborte la
      corrida real (Principio V), y `start_baseline`/`finish_baseline`: imprime
      `Running baseline tests...`, arranca el ticker (redibuja con `\r` un spinner +
      segundos transcurridos), y lo mata + hace `join` al terminar (research.md #1,
      FR-001, FR-003, FR-003a)
- [X] T004 [US1] Agregar a `ProgressReporter` (`lib/mutaterb/progress_reporter.rb`):
      `start_mutants(total)` (guarda `total`, resetea `processed` a 0, arranca el mismo
      mecanismo de ticker mostrando `Mutating... procesados/total` + spinner/tiempo),
      `mutant_finished(mutant)` (incrementa `processed` de forma thread-safe), y
      `finish_mutants` (mata + `join` el ticker) — depende de T003
- [X] T005 [US1] Conectar `ProgressReporter` en `lib/mutaterb/cli.rb`: instanciarlo en
      `execute` con `verbose: config.verbose` (aunque ningún flag lo setee todavía),
      envolver la llamada a `test_runner.run_baseline` en `build_test_suite` con
      `start_baseline`/`finish_baseline`, y en `run_mutations` calcular
      `mutator.total_mutants` antes del loop: si es `0`, imprimir
      `"mutaterb: no mutants to run for the given scope"` y saltar el loop (FR-008); si no,
      `start_mutants(total)`, llamar `mutant_finished(mutant)` por cada mutante recibido, y
      `finish_mutants` al salir del loop (contracts/progress-output.md) — depende de T001,
      T002, T004
- [X] T006 [P] [US1] Tests de `ProgressReporter` en
      `spec/mutaterb/progress_reporter_spec.rb`: transición de fases, que
      `mutant_finished` incrementa `processed`, y que el hilo de ticking no propaga
      excepciones — instanciando con un `tick_interval` mínimo (ej. `0.01`) y un `io` tipo
      `StringIO`, nunca con los intervalos reales de producción (research.md #7) — depende
      de T004
- [X] T007 [P] [US1] Test en `spec/mutaterb/mutator_spec.rb`: `total_mutants` coincide con
      la cantidad de mutantes que efectivamente yieldea `each_mutant`, y no cambia entre
      llamadas sucesivas (memoización) — depende de T002
- [X] T008 [US1] Correr manualmente los Escenarios 1 y 4 de quickstart.md (progreso por
      defecto; cero mutantes) — depende de T005, T006, T007

**Checkpoint**: correr `mutaterb` sin flags ya no se queda en silencio — se ve el baseline,
el ticker, y el contador de mutantes avanzando.

---

## Phase 4: User Story 2 - Inspect what happened to each mutant as it happens (Priority: P2)

**Goal**: que `--verbose` reemplace el contador por defecto del loop de mutantes por una
línea de detalle por cada uno.

**Independent Test**: correr `mutaterb --verbose` y confirmar que aparece una línea por
mutante (archivo, línea, tipo, resultado) en vez del contador, sin romper ningún otro flag
(Escenario 2 y 5 de quickstart.md).

### Implementation for User Story 2

- [X] T009 [US2] Agregar el flag `--verbose` en `lib/mutaterb/flag_parser.rb`:
      `opts.on("--verbose", "Print one line per mutant as it runs") { flags[:verbose] = true }`
      (booleano, sin argumento — mismo patrón que `--exit-zero`), mapeado a la clave
      `verbose` de `Config` (research.md #4) — depende de T001
- [X] T010 [US2] En `ProgressReporter#mutant_finished` (`lib/mutaterb/progress_reporter.rb`):
      cuando `verbose` es `true`, no arrancar/actualizar el ticker del loop de mutantes —
      en su lugar imprimir una línea por mutante con el formato
      `"#{file_path}:#{line} [#{operator_type}] '#{original_fragment}' -> '#{mutated_fragment}' => #{status}"`
      (mismo estilo que `Reporter#print_survived`); el mensaje/ticker de baseline de T003 no
      cambia con este flag (FR-004, FR-005, contracts/progress-output.md) — depende de T004,
      T009
- [X] T011 [US2] Agregar `verbose: c.verbose` al hash de `config_h` en
      `lib/mutaterb/reporter.rb`, junto al resto de los campos de `Config` ya exportados
      (contracts/progress-output.md) — depende de T009
- [X] T012 [P] [US2] Tests en `spec/mutaterb/cli_spec.rb` (parseo de `--verbose`) y
      `spec/mutaterb/config_spec.rb` (`verbose` inválido se rechaza; un flag `--verbose` gana
      sobre `verbose: false` del archivo de config, mismo patrón que ya existe para
      `strictness`/`exit_on_survivors`) — depende de T009
- [X] T013 [P] [US2] Tests de `ProgressReporter` en verbose en
      `spec/mutaterb/progress_reporter_spec.rb`: `mutant_finished` con `verbose: true`
      imprime la línea esperada con archivo/línea/tipo/resultado, y no imprime el contador
      por defecto; con `verbose: false` sigue el comportamiento de T006 sin cambios — depende
      de T010
- [X] T014 [US2] Correr manualmente los Escenarios 2 y 5 de quickstart.md (`--verbose`;
      `verbose: true` en `.mutaterb.yml`) — depende de T010, T011, T012, T013

**Checkpoint**: `--verbose` funciona de punta a punta y es combinable con cualquier otro flag
existente sin alterar su comportamiento.

---

## Phase 5: User Story 3 - Keep logs clean in non-interactive environments (Priority: P3)

**Goal**: que redirigir la salida a un archivo o correr en CI produzca líneas planas y
completas, sin caracteres de control ni líneas sobrescritas.

**Independent Test**: correr `mutaterb` con stdout redirigido a un archivo y confirmar que el
log resultante tiene una línea por actualización, sin `\r` sueltos (Escenario 3 de
quickstart.md).

### Implementation for User Story 3

- [X] T015 [US3] En el mecanismo de ticking de `ProgressReporter`
      (`lib/mutaterb/progress_reporter.rb`), ramificar por `io.tty?`: en TTY, mantener el
      redibujado con `\r` en el intervalo corto ya construido en T003/T004; fuera de TTY,
      imprimir una línea completa (`\n`, sin `\r`) en un intervalo más espaciado (default
      ~5s) con el mismo contenido en texto plano (research.md #2, FR-007)
- [X] T016 [P] [US3] Tests en `spec/mutaterb/progress_reporter_spec.rb` con un doble de
      `io` cuyo `tty?` devuelve `false`: confirmar que la salida no contiene `\r` y que cada
      actualización es una línea completa (SC-005) — depende de T015
- [X] T017 [US3] Correr manualmente el Escenario 3 de quickstart.md (stdout redirigido a
      archivo) y confirmar que el resumen final y un `--json-output` generado en la misma
      corrida no cambian de formato (SC-004) — depende de T015, T016

**Checkpoint**: las tres user stories funcionan de forma independiente; el spec completo
(FR-001 a FR-010) queda cubierto.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T018 [P] Bump de `lib/mutaterb/version.rb` a la próxima versión MINOR
- [X] T019 [P] Actualizar `README.md`: mencionar el flag `--verbose` y el nuevo progreso por
      defecto durante la corrida
- [X] T020 Correr `bundle exec rake spec` + `bundle exec rubocop` completos y confirmar cero
      regresiones sobre la suite existente (SC-004) — depende de todo lo anterior

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: bloquea las tres user stories.
- **User Story 1 (Phase 3)**: depende solo de Foundational.
- **User Story 2 (Phase 4)**: depende de Foundational y de que `ProgressReporter` exista
  (T003/T004 de US1) — el flag `--verbose` cambia cómo se dibuja el mismo objeto, no puede
  implementarse antes.
- **User Story 3 (Phase 5)**: depende del mecanismo de ticking de US1 (T003/T004) — refina la
  rama TTY/no-TTY del mismo método; puede implementarse en paralelo con US2 si hay más de una
  persona trabajando (no dependen entre sí).
- **Polish (Phase 6)**: depende de que las tres user stories estén completas.

### Parallel Opportunities

- Foundational: T001 y T002 en paralelo (archivos distintos)
- US1: T006 y T007 en paralelo entre sí tras T004/T002 respectivamente
- US2 y US3: pueden trabajarse en paralelo una vez terminada US1 (tocan el mismo archivo
  `progress_reporter.rb` en secciones distintas — coordinar el orden de merge)
- US2: T012 y T013 en paralelo entre sí tras T009/T010 respectivamente
- US3: T016 puede arrancar apenas termina T015
- Polish: T018 y T019 en paralelo

---

## Parallel Example: Foundational

```bash
# T001 y T002 pueden arrancar juntos, no comparten archivo:
Task: "Agregar el campo verbose a lib/mutaterb/config.rb"
Task: "Memoizar candidates y exponer total_mutants en lib/mutaterb/mutator.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 2 (Foundational) — campo `verbose` en `Config` + `total_mutants` en `Mutator`.
2. Phase 3 (US1) → validar con Escenarios 1 y 4 de quickstart.md — **acá ya hay valor real**:
   `mutaterb` deja de quedarse en silencio.
3. Phase 4 (US2) → validar con Escenarios 2 y 5 (`--verbose` de punta a punta).
4. Phase 5 (US3) → validar con Escenario 3 (logs no interactivos limpios).
5. Phase 6 (Polish) → bump de versión + README + verificación final de no-regresión.

### Incremental Delivery

Cada checkpoint de fase es un punto seguro para probar manualmente antes de seguir con la
siguiente.
