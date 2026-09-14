# Contract Delta: Selección de Framework (RSpec/Minitest)

Este documento es un **delta** sobre `specs/001-mutation-testing-mvp/contracts/cli.md`,
`config-schema.md` y `json-report-schema.md` — no los reemplaza, solo agrega lo que introduce
esta feature.

## CLI (delta sobre contracts/cli.md de la feature 001)

| Flag nuevo | Config equivalente | Tipo | Descripción |
|---|---|---|---|
| `--framework FRAMEWORK` | `test_framework` | Symbol (`auto`\|`rspec`\|`minitest`) | Fuerza el framework de test a usar, salteando la auto-detección |

Un valor fuera de `{auto, rspec, minitest}` DEBE rechazarse igual que cualquier otro valor
inválido (FR-011 de la feature 001): mensaje de error claro, exit code de error operativo, sin
arrancar la corrida.

## Config file (delta sobre contracts/config-schema.md de la feature 001)

```yaml
# .mutaterb.yml (clave nueva, opcional)
test_framework: auto   # "auto" | "rspec" | "minitest"
```

## Salida en consola (nuevo, FR-002/SC-003)

Cuando la auto-detección encuentra ambos frameworks presentes, la primera línea de salida
DEBE informarlo antes del resumen de mutaciones, por ejemplo:

```text
mutaterb: se detectaron RSpec y Minitest — usando RSpec (fijalo explícitamente con --framework)
MutateRB — 3 mutaciones: 2 killed, 1 survived, 0 errores
```

## JSON export (delta sobre contracts/json-report-schema.md de la feature 001)

Se agrega una clave `"framework"` (`"rspec"` o `"minitest"`) al objeto `config` del JSON
exportado, indicando qué framework se usó efectivamente en esa corrida (no solo lo que el
usuario pidió, sino el resultado final de la detección/override):

```jsonc
{
  "config": {
    "target_dir": ".",
    "framework": "minitest",
    // ...resto de campos sin cambios
  }
  // ...resto del esquema sin cambios
}
```
