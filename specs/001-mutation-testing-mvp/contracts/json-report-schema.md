# Contract: Esquema del export JSON (`--json-output`)

Generado solo si se pasa `--json-output PATH` o `json_output_path` en la config (FR-015). Misma
información que el reporte de consola (FR-006), en forma estructurada.

```jsonc
{
  "mutaterb_version": "0.1.0",
  "started_at": "2026-09-13T15:04:00Z",
  "finished_at": "2026-09-13T15:06:32Z",
  "interrupted": false,
  "config": {
    "target_dir": ".",
    "include_paths": [],
    "exclude_paths": [],
    "strictness": "default",
    "mutation_types": ["conditional_boundary", "boolean_literal", "nil_literal", "arithmetic_comparison"],
    "exit_on_survivors": true
  },
  "summary": {
    "total_mutants": 42,
    "killed": 35,
    "survived": 5,
    "errors": 2,
    "baseline_broken_tests": 1
  },
  "baseline_broken_tests": [
    { "id": "spec/models/user_spec.rb:8", "description": "valida el email" }
  ],
  "survived_mutants": [
    {
      "id": "m-017",
      "operator_type": "conditional_boundary",
      "file_path": "app/models/user.rb",
      "line": 22,
      "original_fragment": ">",
      "mutated_fragment": ">=",
      "related_tests": [
        { "id": "spec/models/user_spec.rb:31", "description": "es mayor de edad" }
      ]
    }
  ],
  "exit_code": 1
}
```

## Reglas

- `summary.total_mutants == killed + survived + errors` (los `baseline_broken_tests` no cuentan
  como mutantes).
- `survived_mutants` incluye **todos** los mutantes con `status == "survived"` (SC-002: el
  reporte identifica el 100%), con suficiente información para ubicar el archivo/línea y el/los
  test(s) relacionados sin necesitar volver a correr MutateRB.
- Los mutantes `"killed"` y `"error"` NO se listan en detalle en el JSON del MVP (solo se
  cuentan en `summary`) — el foco del reporte es accionar sobre lo "survived" (FR-006); esto
  puede ampliarse en una iteración futura sin romper este esquema (los consumidores deben
  ignorar claves nuevas, no asumir que esta lista es exhaustiva de todos los mutantes).
- `exit_code` refleja el mismo valor con el que termina el proceso (ver contracts/cli.md),
  para que un consumidor del JSON no tenga que inferirlo del código de salida del shell por
  separado.
