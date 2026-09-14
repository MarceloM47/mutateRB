# Quickstart: Validar progreso y --verbose

## Prerrequisitos

- Ruby 3.x. Sin gemas adicionales (research.md #6).
- Un proyecto de prueba con varios mutantes posibles, para que la corrida dure lo suficiente
  como para observar el ticker (ej. reusar los fixtures de `spec/mutaterb/mutator_spec.rb`, o
  el proyecto Minitest de `specs/004-minitest-support/quickstart.md`).

## Escenario 1 — Progreso por defecto (sin flags)

```bash
mutaterb --dir /tmp/mt-sample
```

**Resultado esperado**: aparece `Running baseline tests...` con un indicador que sigue
cambiando (spinner/tiempo transcurrido) mientras el baseline corre; al arrancar el loop de
mutantes, un contador `procesados/total` que avanza a medida que cada mutante termina, sin
quedar nunca más de unos segundos sin cambios en pantalla (US1, SC-001, SC-002).

## Escenario 2 — `--verbose`

```bash
mutaterb --dir /tmp/mt-sample --verbose
```

**Resultado esperado**: el baseline se anuncia igual que en el Escenario 1; durante el loop de
mutantes, en vez del contador, aparece una línea por mutante (archivo:línea, tipo de mutación,
resultado) a medida que se evalúa — nunca ambos formatos a la vez (US2, contracts/
progress-output.md).

## Escenario 3 — Logs no interactivos (CI / redirección)

```bash
mutaterb --dir /tmp/mt-sample > /tmp/mutaterb.log 2>&1
cat /tmp/mutaterb.log
```

**Resultado esperado**: el archivo contiene líneas completas (con salto de línea), sin
caracteres `\r` sueltos ni líneas parcialmente sobrescritas (US3, SC-005). El resumen final y
cualquier `--json-output` generado en la misma corrida no cambian de formato respecto a antes
de esta feature (SC-004).

## Escenario 4 — Cero mutantes

```bash
mutaterb --dir /tmp/mt-sample --exclude /tmp/mt-sample
```

**Resultado esperado**: se imprime de inmediato que no hay mutantes para correr (FR-008), sin
mostrar un contador vacío ni un ticker que nunca avanza, y el resumen final reporta
`0 mutations`.

## Escenario 5 — Config file

Agregar `verbose: true` a `.mutaterb.yml` en `/tmp/mt-sample` y correr `mutaterb --dir
/tmp/mt-sample` sin el flag: debe comportarse igual que el Escenario 2 (FR-010). Correr con
`--dir /tmp/mt-sample` y sin `--verbose` pero con el YAML en `true`, luego repetir agregando
explícitamente el flag inverso si existiera — como no hay `--no-verbose`, alcanza con confirmar
que el flag CLI (`--verbose`) sigue ganando cuando ambos están presentes y en desacuerdo con
otros flags booleanos existentes (mismo mecanismo que `exit_on_survivors`).

## Criterio de aceptación de la iteración

La feature se considera validada cuando los 5 escenarios se comportan como se describe, la
suite completa de MutateRB (RSpec + Rubocop) sigue pasando sin regresiones, y los specs nuevos
de `ProgressReporter`/`Mutator#total_mutants` corren sin `sleep` de duración real (research.md
#7).
