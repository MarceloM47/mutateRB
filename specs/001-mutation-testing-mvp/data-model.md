# Data Model: MutateRB — Mutation Testing para Ruby/Rails (MVP)

Todas las entidades son objetos en memoria de una sola corrida de proceso (no hay persistencia
entre corridas — ver Non-Goals del spec). Los tipos de datos son Ruby nativos (String, Symbol,
Integer, Float, Boolean, Array, Hash); no hay ORM ni base de datos involucrada.

## Config

Opciones resueltas para una corrida, combinando `.mutaterb.yml` y flags de CLI (flags ganan,
FR-009).

| Campo | Tipo | Default | Validación (FR-011) |
|---|---|---|---|
| `target_dir` | String | `"."` | Debe existir y ser un directorio |
| `include_paths` | Array\<String\> | `[]` (= todo `target_dir`) | Cada path debe existir dentro de `target_dir` |
| `exclude_paths` | Array\<String\> | `[]` | Cada path debe existir dentro de `target_dir` |
| `strictness` | Symbol | `:default` | Debe ser uno de `:low`, `:default`, `:high` |
| `mutation_types` | Array\<Symbol\> | todos los operadores disponibles | Cada valor debe ser un operador registrado (ver Mutant#operator_type) |
| `exit_on_survivors` | Boolean | `true` | Debe ser `true`/`false` |
| `json_output_path` | String o `nil` | `nil` | Si está presente, el directorio padre debe ser escribible |

**Reglas**:
- `include_paths`/`exclude_paths`: si un path aparece en ambos, `exclude_paths` gana (más
  específico).
- `strictness: :high` amplía `mutation_types` por defecto y/o exige que el 100% de mutantes no
  "survived" cuenten como aceptables (detalle de umbral se define en implementación, dentro de
  lo permitido por Assumptions del spec).
- Config inválido → se lanza `MutateRB::ConfigError` con mensaje humano-legible; el CLI la
  captura y termina con exit code de error operativo (ver contracts/cli.md), nunca con una
  excepción sin capturar (Principio V).

## TestCase

Representa un test individual detectado en el proyecto objetivo.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | String | Identificador estable, ej. `"spec/models/user_spec.rb:12"` |
| `description` | String | Descripción legible del test (de RSpec) |
| `file_path` | String | Ruta del archivo de spec |
| `baseline_status` | Symbol | `:passed` o `:failed`, de la corrida base sin mutar |
| `baseline_duration_seconds` | Float | Duración en la corrida base; base del cálculo de timeout (FR-014) |

Un `TestCase` con `baseline_status == :failed` se excluye de los conteos "killed/survived" en
cualquier `Mutant` que dependa de él (FR-012) y se reporta aparte.

## TestSuite

| Campo | Tipo | Notas |
|---|---|---|
| `framework` | Symbol | Fijo en `:rspec` para el MVP (ver Assumptions) |
| `project_type` | Symbol | `:ruby` o `:rails` (FR-001) |
| `test_cases` | Array\<TestCase\> | Todos los tests detectados dentro del alcance de `Config` |

## Mutant

Una mutación puntual aplicada a una ubicación del código fuente.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | String | Identificador único dentro de la corrida |
| `operator_type` | Symbol | Uno de: `:conditional_boundary`, `:boolean_literal`, `:nil_literal`, `:arithmetic_comparison` |
| `file_path` | String | Archivo fuente mutado |
| `line` / `column_range` | Integer / Range | Ubicación exacta del nodo mutado (de `RubyVM::AbstractSyntaxTree`) |
| `original_fragment` | String | Texto original reemplazado |
| `mutated_fragment` | String | Texto que reemplaza al original |
| `status` | Symbol | `:pending` → `:killed` \| `:survived` \| `:error` |
| `kill_reason` | Symbol o `nil` | Si `status == :killed`: `:assertion_failure` o `:timeout` |
| `related_tests` | Array\<TestCase\> | Tests ejecutados contra este mutante |
| `failing_tests` | Array\<TestCase\> | Subconjunto de `related_tests` que falló (si `:killed`) |
| `error_message` | String o `nil` | Si `status == :error` (ej. código inválido tras la mutación) |

**Transiciones de estado**: `:pending` es el único estado inicial; transiciona una sola vez a
exactamente uno de `:killed`, `:survived`, `:error` tras ejecutar `related_tests` (o al
detectar que la mutación produce código no parseable, sin llegar a ejecutar tests).

## MutationRun

Agrega una corrida completa.

| Campo | Tipo | Notas |
|---|---|---|
| `config` | Config | Configuración resuelta usada |
| `test_suite` | TestSuite | Specs detectados |
| `mutants` | Array\<Mutant\> | Todos los mutantes generados y su resultado |
| `baseline_broken_tests` | Array\<TestCase\> | Tests con `baseline_status == :failed` (FR-012) |
| `started_at` / `finished_at` | Time | Para el reporte |
| `interrupted` | Boolean | `true` si la corrida terminó por `Ctrl+C` (FR-005) |

**Métodos derivados** (no persistidos, calculados sobre `mutants`):
- `survived?` → `true` si algún `Mutant#status == :survived`
- `summary` → conteo por `status`/`kill_reason`, usado por `Reporter` (FR-006) y para el exit
  code (FR-013)

## Relaciones

```text
Config ──1:1── MutationRun ──1:1── TestSuite ──1:N── TestCase
                    │
                    └──1:N── Mutant ──N:N── TestCase (related_tests / failing_tests)
```
