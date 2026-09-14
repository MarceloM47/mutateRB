# Contract: Progress Output (delta sobre contracts/cli.md)

Este documento agrega a `specs/001-mutation-testing-mvp/contracts/cli.md` — no lo reemplaza.
Los exit codes, señales, y el formato del resumen final no cambian.

## Flags (delta sobre FR-008 de la feature 001)

| Flag | Config equivalente | Tipo | Descripción |
|---|---|---|---|
| `--verbose` | `verbose = true` | Boolean flag | Imprime una línea por mutante a medida que se evalúa, en vez del contador por defecto (FR-004, FR-005) |

## stdout durante la corrida (nuevo — antes esta sección estaba vacía)

### Sin `--verbose` (default)

1. Al arrancar el baseline: una línea `Running baseline tests...` seguida del ticker en vivo
   (FR-003, FR-003a). En TTY, el ticker redibuja la misma línea (`\r`) cada ~0.3s con un
   spinner y el tiempo transcurrido; fuera de TTY, imprime una línea nueva cada ~5s con el
   mismo contenido en texto plano (FR-007).
2. Al terminar el baseline y arrancar el loop de mutantes: si `total_mutants == 0`, una única
   línea (`No mutants to run for the given scope.`) y se salta directo al resumen (FR-008). Si
   `total_mutants > 0`, el mismo mecanismo de ticker que en (1), mostrando `processed/total`
   en vez del mensaje de baseline.

Formato de ejemplo (TTY, redibujando la misma línea):

```text
Running baseline tests... (| 4s)
Mutating... 12/340 (/ 18s)
```

Formato de ejemplo (no-TTY, una línea por heartbeat):

```text
Running baseline tests... (4s elapsed)
Mutating... 12/340 (18s elapsed)
Mutating... 12/340 (23s elapsed)
```

### Con `--verbose`

El mensaje de baseline (paso 1 arriba) se muestra igual. Durante el loop de mutantes, en vez
del contador/ticker, se imprime una línea por mutante al terminar, sin importar TTY o no
(FR-004, FR-005):

```text
lib/calc.rb:12 [conditional_boundary] '>' -> '>=' => survived
lib/calc.rb:20 [boolean_literal] 'true' -> 'false' => killed
lib/calc.rb:33 [nil_literal] 'nil' -> '0' => timeout
```

Mismo formato de identificación que ya usa `Reporter#print_survived` para consistencia
(`file:line [operator_type] 'original' -> 'mutated'`), con `=> <status>` agregado al final.

## JSON export (delta sobre json-report-schema.md)

`config.verbose` (Boolean) se agrega al objeto `config` del JSON, junto al resto de los flags
ya exportados (`strictness`, `test_framework`, `exit_on_survivors`, etc.) — ningún otro campo
del schema cambia (FR-006).
