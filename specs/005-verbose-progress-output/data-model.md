# Data Model: Verbose Flag and Run Progress Output

Extiende `Config` con un campo nuevo y agrega un objeto de presentación (`ProgressReporter`)
que mantiene estado en memoria durante la corrida, no persistido — no hay entidades de dominio
nuevas (`Mutant`, `TestCase`, `TestSuite`, `MutationRun` no cambian de forma).

## Config (extendido)

| Campo nuevo | Tipo | Default | Validación |
|---|---|---|---|
| `verbose` | Boolean | `false` | Debe ser `true` o `false` (mismo chequeo que `exit_on_survivors`) |

**Reglas**: mismo patrón que cualquier otro flag existente — CLI (`--verbose`) gana sobre
`.mutaterb.yml` (`verbose: true`) si ambos están presentes (research.md #4).

## ProgressReporter (nuevo — estado en memoria, no persiste)

No es una entidad de dominio sino el estado interno del objeto de presentación descrito en
research.md #1 y #5:

| Campo | Tipo | Descripción |
|---|---|---|
| `phase` | Symbol (`:idle`\|`:baseline`\|`:mutating`\|`:done`) | Fase actual de la corrida, leída por el hilo del ticker para saber qué dibujar |
| `processed` | Integer | Mutantes ya finalizados en la fase `:mutating` |
| `total` | Integer | Total de mutantes a procesar (`Mutator#total_mutants`), conocido antes de arrancar el loop |
| `phase_started_at` | Time | Marca de tiempo al entrar a `:baseline` o `:mutating`, usada para el tiempo transcurrido del ticker |
| `verbose` | Boolean | Copia de `Config#verbose`; determina si el loop de mutantes dibuja el ticker (`false`) o imprime líneas por mutante (`true`) |

Todas las lecturas/escrituras cruzadas entre el hilo principal y el hilo del ticker pasan por
un `Mutex` interno (research.md #1) — no se expone como atributo público, es un detalle de
implementación de `ProgressReporter`.

## Mutator (extendido)

| Campo/Método nuevo | Cambio |
|---|---|
| `total_mutants` | Nuevo método público: tamaño de la lista de candidatos, memoizada la primera vez que se calcula (research.md #3). |
| `candidates` (privado) | La lista que hoy se recalcula dentro de `each_mutant` pasa a memoizarse en un `@candidates ||= ...`, compartida entre `total_mutants` y `each_mutant`. |

`Mutant` no cambia de forma — `ProgressReporter#mutant_finished(mutant)` solo lee sus atributos
ya existentes (`file_path`, `line`, `operator_type`, `original_fragment`, `mutated_fragment`,
`status`, `kill_reason`) para armar la línea verbose (FR-004), igual que ya hace
`Reporter#print_survived`.

## MutationRun / Reporter

Sin cambios de forma. `Reporter#config_h` agrega una entrada más (`verbose: c.verbose`) al hash
ya existente, siguiendo el mismo precedente que cada flag anterior (research.md #4) — no
cambia la estructura del JSON, solo agrega el campo correspondiente al nuevo flag.
