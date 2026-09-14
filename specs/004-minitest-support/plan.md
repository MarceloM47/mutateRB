# Implementation Plan: Minitest Support

**Branch**: `004-minitest-support` | **Date**: 2026-09-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-minitest-support/spec.md`

## Summary

Generaliza MutateRB para que detecte y corra mutation testing sobre proyectos que usan
Minitest (además de RSpec, que ya funciona). El motor de mutación (`Mutator`,
`MutationOperators`) no cambia — solo la capa de detección de framework y la capa de
ejecución/parseo de tests. Enfoque: extraer un "adapter" por framework (`RspecAdapter`,
`MinitestAdapter`) responsable únicamente de construir el comando a correr y parsear su
salida; `TestRunner` sigue siendo el dueño genérico de spawnear el proceso, aplicar el
timeout y matar procesos colgados (sin cambios en esa parte). `ProjectDetector` se extiende
para además decidir qué framework usar (`spec/` → RSpec, `test/` → Minitest, ambos → RSpec
por default salvo override explícito).

## Technical Context

**Language/Version**: Ruby 3.x (sin cambios respecto a la feature 001)

**Primary Dependencies**: Ninguna nueva — el parseo de Minitest se hace con la salida
`--verbose` nativa (stdlib de Minitest, ya viene con cualquier proyecto que lo use), sin
agregar `minitest-reporters` ni ninguna gem al proyecto objetivo (FR-009, research.md #2).

**Storage**: N/A

**Testing**: RSpec + Rubocop (sin cambios) — se agregan fixtures de proyectos Minitest
(plain Ruby y Rails-like) para la spec suite de MutateRB en sí.

**Target Platform**: Sin cambios respecto a la feature 001.

**Project Type**: Single project — gem Ruby existente, se extiende su estructura interna.

**Performance Goals**: Sin objetivo formal nuevo. Nota: si el proyecto objetivo Minitest no
es Rails y `related_tests` incluye más de un archivo, MutateRB corre un proceso Ruby por
archivo (en vez de uno solo como con RSpec) — ver research.md #4 para el porqué.

**Constraints**: FR-002/SC-003 exigen que, cuando ambos frameworks están presentes, la
elección quede explícita en la salida — no puede ser un comportamiento silencioso.

**Scale/Scope**: Mismo alcance que la feature 001 (sin límite artificial de mutaciones por
corrida).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Chequeo | Resultado |
|---|---|---|
| I. Naturaleza y Propósito | ¿Sirve al propósito de detectar tests débiles vía mutación? | PASS — generaliza el framework de test soportado, no agrega capacidades fuera de ese propósito. |
| II. Stack Tecnológico | ¿Se mantiene 100% Ruby, sin dependencias nuevas? | PASS — cero gems nuevas (FR-009); el parseo de Minitest es texto plano vía stdlib. |
| III. Reglas de Dominio (NO NEGOCIABLES) | ¿Sigue auto-detectando el proyecto sin intervención manual? | PASS — la auto-detección de framework (FR-001) es una extensión directa del mismo principio que ya rige la detección Ruby/Rails. |
| IV. Estructura y Estilo | ¿Se mantiene la estructura plana y POO, sin Clean Architecture? | PASS — el patrón "adapter por framework" reutiliza exactamente el mismo idioma que ya usa `Mutator::OPERATORS` para los operadores de mutación (un hash de símbolo → clase), no introduce una capa nueva de abstracción. |
| V. Manejo de Errores y Validaciones | ¿El parseo de Minitest maneja fallos sin abortar la corrida? | PASS (a nivel de diseño) — un parseo que no reconoce una línea se trata como "error" de ese test puntual (Edge Case del spec), nunca como excepción sin capturar; se exige en `/speckit-implement`. |
| Comportamiento del Agente de IA | ¿El plan se limita a lo documentado en spec.md? | PASS — sin funcionalidad fuera de FR-001 a FR-009 y las Non-Goals del spec. |

Sin violaciones detectadas. No aplica "Complexity Tracking".

**Re-chequeo post-Phase 1**: `data-model.md` y `contracts/` no introducen nada fuera de lo
aprobado arriba — el patrón adapter sigue siendo composición simple, no herencia profunda ni
capas nuevas. Gate sigue en PASS.

## Project Structure

### Documentation (this feature)

```text
specs/004-minitest-support/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md         # Phase 1 output
├── quickstart.md         # Phase 1 output
└── contracts/
    └── framework-detection.md   # delta sobre contracts/cli.md y config-schema.md de la feature 001
```

No se regeneran `contracts/cli.md`/`config-schema.md`/`json-report-schema.md` de la feature
001 — `framework-detection.md` documenta solo lo que esta feature agrega/cambia sobre esos
contratos ya existentes.

### Source Code (repository root)

```text
lib/mutaterb/
├── project_detector.rb        # extendido: además de project_type, decide test_framework (FR-001, FR-002, FR-003)
├── test_runner.rb             # sin cambios en spawn/timeout/kill; delega command/parse al adapter
├── test_adapters/
│   ├── rspec_adapter.rb       # extraído de la lógica actual de test_runner.rb (command_for + parse)
│   └── minitest_adapter.rb    # nuevo: command_for (bin/rails test | ruby -Itest) + parse (salida --verbose)
├── mutator.rb                 # mapped_spec_file generaliza a mapped_test_file según el framework detectado
└── config.rb                  # nuevo campo test_framework (:auto/:rspec/:minitest)

exe/                            # sin cambios
spec/mutaterb/
├── project_detector_spec.rb    # casos nuevos: detección de test/ y de "ambos presentes"
├── test_adapters/
│   ├── rspec_adapter_spec.rb   # extraído de test_runner_spec.rb existente
│   └── minitest_adapter_spec.rb # nuevo: fixtures Minitest plain-Ruby y Rails-like
└── config_spec.rb              # casos nuevos: validación de test_framework
```

**Structure Decision**: se mantiene la Opción 1 (single project, gema plana). El único
concepto nuevo es `test_adapters/`, un subdirectorio hermano de `mutation_operators/` que
sigue exactamente el mismo patrón ya establecido (una clase por variante, seleccionada vía un
hash `ADAPTERS = { rspec: ..., minitest: ... }` en `TestRunner`, igual que
`Mutator::OPERATORS`).

## Complexity Tracking

> No aplica — la Constitution Check no encontró violaciones que requieran justificación.
