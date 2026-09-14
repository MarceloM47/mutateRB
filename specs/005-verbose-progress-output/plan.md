# Implementation Plan: Verbose Flag and Run Progress Output

**Branch**: `005-verbose-progress-output` | **Date**: 2026-09-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-verbose-progress-output/spec.md`

## Summary

Hoy `mutaterb` no imprime nada desde que arranca hasta el resumen final, incluso en corridas
de minutos u horas — el usuario no puede distinguir "está trabajando" de "se colgó". Esta
feature agrega: (1) un indicador de progreso por defecto (baseline + contador de mutantes
procesados/total) con un ticker en vivo que avanza por tiempo mientras una fase está en curso,
sin depender de que el subproceso de tests termine; y (2) un flag `--verbose` que, en vez del
contador, imprime una línea por mutante con su archivo/línea/tipo/resultado. Enfoque técnico:
sin gemas nuevas — `Thread`/`Mutex`/`Time`/`IO#tty?` de la stdlib alcanzan; el motor de
mutación (`Mutator`, `TestRunner`) no cambia su lógica de negocio, solo se le agrega la
capacidad de reportar su total de mutantes por adelantado.

## Technical Context

**Language/Version**: Ruby 3.x (sin cambios respecto a las features anteriores)

**Primary Dependencies**: Ninguna nueva. El ticker en vivo y el modo verbose se implementan
con stdlib pura (`Thread`, `Mutex`, `Time`, `$stdout`, `IO#tty?`) — ver research.md #1 y #6.

**Storage**: N/A

**Testing**: RSpec + Rubocop (sin cambios). Los specs de `ProgressReporter` corren con el
ticker deshabilitado o con un intervalo mínimo inyectado, para no depender de `sleep` real ni
introducir flakiness (research.md #7).

**Target Platform**: Sin cambios respecto a las features anteriores.

**Project Type**: Single project — gem Ruby existente, se extiende su estructura interna.

**Performance Goals**: El overhead del thread de ticking debe ser despreciable frente al
costo real de correr tests (un `sleep` por intervalo, sin I/O ni cómputo pesado).

**Constraints**: FR-003a exige que el ticker avance por tiempo, no por finalización de
subproceso — obliga a un hilo en segundo plano en vez de solo `puts` sincrónicos en el hilo
principal (research.md #1). FR-005 exige que verbose reemplace, no sume, el contador por
defecto durante el loop de mutantes.

**Scale/Scope**: Mismo alcance que las features anteriores (sin límite artificial de
mutaciones por corrida); el conteo total de mutantes debe calcularse por adelantado sin correr
ningún test (research.md #3).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Chequeo | Resultado |
|---|---|---|
| I. Naturaleza y Propósito | ¿Sirve al propósito de detectar tests débiles vía mutación? | PASS — es observabilidad sobre una corrida que ya existe, no agrega capacidades fuera de ese propósito. |
| II. Stack Tecnológico | ¿Se mantiene 100% Ruby, sin dependencias nuevas? | PASS — cero gems nuevas (research.md #6); el ticker usa `Thread`/`Mutex`/`Time` de la stdlib. |
| III. Reglas de Dominio (NO NEGOCIABLES) | ¿La CLI expone flags según lo requerido? | PASS — `--verbose` sigue exactamente el mismo patrón que los flags existentes (FlagParser + Config, FR-010). |
| IV. Estructura y Estilo | ¿Se mantiene la estructura plana y POO, sin Clean Architecture? | PASS — un único objeto nuevo (`ProgressReporter`) inyectado por la CLI; `Mutator`/`TestRunner` no se acoplan a presentación (research.md #5). |
| V. Manejo de Errores y Validaciones | ¿Un fallo en el reporte de progreso puede abortar la corrida real? | PASS (a nivel de diseño) — el cuerpo del hilo de ticking se ejecuta dentro de un `begin/rescue StandardError` que nunca propaga; en el peor caso el ticker deja de dibujar pero la corrida sigue (research.md #1); se exige en `/speckit-implement`. |
| Comportamiento del Agente de IA | ¿El plan se limita a lo documentado en spec.md? | PASS — sin funcionalidad fuera de FR-001 a FR-010 y las Assumptions del spec. |

Sin violaciones detectadas. No aplica "Complexity Tracking".

**Re-chequeo post-Phase 1**: `data-model.md` y `contracts/` no introducen nada fuera de lo
aprobado arriba — `ProgressReporter` sigue siendo un único objeto con estado simple (fase,
procesados, total, hora de inicio), sin herencia ni capas nuevas. Gate sigue en PASS.

## Project Structure

### Documentation (this feature)

```text
specs/005-verbose-progress-output/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── contracts/
    └── progress-output.md   # delta sobre contracts/cli.md de la feature 001
```

No se regenera `contracts/cli.md`/`json-report-schema.md` de la feature 001 —
`progress-output.md` documenta solo lo que esta feature agrega sobre esos contratos ya
existentes.

### Source Code (repository root)

```text
lib/mutaterb/
├── progress_reporter.rb   # nuevo: ticker en vivo + contador por defecto + líneas verbose
├── flag_parser.rb         # agrega --verbose
├── config.rb              # agrega el campo verbose (mismo patrón que exit_on_survivors)
├── cli.rb                 # instancia ProgressReporter y lo pasa a build_test_suite/run_mutations
├── test_runner.rb         # sin cambios de lógica (progreso se engancha alrededor, no adentro)
└── mutator.rb             # candidates_for/source_files se memoizan para exponer total_mutants
                            # por adelantado, sin correr ningún test (FR-002)

exe/                       # sin cambios
spec/mutaterb/
├── progress_reporter_spec.rb   # nuevo: estados, formato de línea verbose, TTY vs no-TTY
├── flag_parser_spec.rb (dentro de cli_spec.rb, sigue el patrón actual) # caso --verbose
├── config_spec.rb              # caso nuevo: validación de verbose
├── mutator_spec.rb             # caso nuevo: total_mutants antes de correr
└── cli_spec.rb                 # caso nuevo: progreso se invoca en el orden esperado
```

**Structure Decision**: se mantiene la Opción 1 (single project, gema plana). El único
concepto nuevo es `ProgressReporter`, una clase hermana de `Reporter` (misma carpeta
`lib/mutaterb/`, mismo nivel de responsabilidad: presentación, no motor de mutación) —
sin introducir un subdirectorio nuevo ni un patrón de diseño adicional.

## Complexity Tracking

> No aplica — la Constitution Check no encontró violaciones que requieran justificación.
