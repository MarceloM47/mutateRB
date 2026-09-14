# Implementation Plan: Fix Minitest Baseline Truncated by an Early Test Failure

**Branch**: `006-fix-minitest-chain-halt` | **Date**: 2026-09-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-fix-minitest-chain-halt/spec.md`

## Summary

`MinitestAdapter.command_for` chains one shell command per test file with `&&`. Since
`ruby`/`bin/rails test` exits non-zero on any failing or erroring test — the ordinary state of
a real project, not an edge case — the first file with a failure stops the whole chain, and
every file after it silently never runs. The baseline ends up containing only the files
processed before that point, and any mutant mapped to a dropped file falls back to being
scored against that unrelated, partial set of tests. Fix: join with `;` instead, since nothing
downstream reads the shell's exit status — classification is entirely output-based.

## Technical Context

**Language/Version**: Ruby 3.x (sin cambios)

**Primary Dependencies**: Ninguna nueva — cambio de un separador de shell (`&&` → `;`) en un
string ya construido con `Shellwords`.

**Storage**: N/A

**Testing**: RSpec + Rubocop (sin cambios). Se agrega un test de regresión que arma el comando
real, fuerza que el primer archivo falle, y confirma que el marcador del segundo archivo
igual aparece en el output.

**Target Platform**: Sin cambios.

**Project Type**: Single project — gem Ruby existente.

**Performance Goals**: Sin objetivo nuevo — el fix no cambia cuántos procesos se spawnean,
solo si el resto de la cadena se ejecuta cuando uno falla.

**Constraints**: El exit status del comando compuesto no debe usarse en ningún punto para
decidir nada (ya verificado: no hay ningún `exitstatus`/`$?`/`success?` en `test_runner.rb` ni
en los adapters) — condición necesaria para que cambiar `&&` por `;` sea seguro.

**Scale/Scope**: Afecta a cualquier corrida de Minitest con más de un archivo relacionado
(baseline casi siempre, y cualquier mutante cuyos tests relacionados abarquen más de un
archivo).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Chequeo | Resultado |
|---|---|---|
| I. Naturaleza y Propósito | ¿Sirve al propósito de detectar tests débiles vía mutación de forma confiable? | PASS — corrige un caso donde el propio motor de clasificación usaba datos incompletos; sin esto, "survived"/"killed" podían ser incorrectos. |
| II. Stack Tecnológico | ¿Se mantiene 100% Ruby, sin dependencias nuevas? | PASS — un carácter de separador en un string de shell, cero gems. |
| III. Reglas de Dominio (NO NEGOCIABLES) | ¿Sigue detectando tests automáticamente sin intervención manual? | PASS — no cambia detección, solo la robustez de la ejecución ya existente. |
| IV. Estructura y Estilo | ¿Se mantiene la estructura plana? | PASS — cambio de una línea en un método ya existente, sin abstracciones nuevas. |
| V. Manejo de Errores y Validaciones | ¿Mejora o empeora el manejo de fallos? | PASS — mejora: antes un fallo real (esperable) causaba pérdida silenciosa de datos; ahora cada archivo se ejecuta y su resultado (aunque sea un fallo) se captura y maneja como ya lo hacía el parser. |
| Comportamiento del Agente de IA | ¿El plan se limita a lo documentado en spec.md? | PASS — un solo cambio, sin funcionalidad nueva fuera de FR-001 a FR-004. |

Sin violaciones detectadas. No aplica "Complexity Tracking".

**Re-chequeo post-Phase 1**: no se generan `data-model.md` ni `contracts/` (ver Project
Structure) — no hay entidades ni contratos nuevos que puedan introducir una violación. Gate
sigue en PASS.

## Project Structure

### Documentation (this feature)

```text
specs/006-fix-minitest-chain-halt/
├── plan.md              # This file
├── research.md          # Phase 0 output
└── quickstart.md        # Phase 1 output
```

No aplica `data-model.md` (no hay entidades nuevas ni cambiadas) ni `contracts/` (no cambia
ningún flag, formato de salida, o interfaz pública — ver Assumptions del spec).

### Source Code (repository root)

```text
lib/mutaterb/test_adapters/
└── minitest_adapter.rb    # command_for: separador entre archivos && -> ;

spec/mutaterb/test_adapters/
└── minitest_adapter_spec.rb   # test de regresión: un archivo "falla", el siguiente igual corre
```

**Structure Decision**: Opción 1 (single project, gema plana) — ya se sigue. Un solo archivo
de código productivo tocado, un solo archivo de spec actualizado.

## Complexity Tracking

> No aplica — la Constitution Check no encontró violaciones que requieran justificación.
