# Contract: CLI de MutateRB

## Comando

```text
mutaterb [flags]
```

Se ejecuta desde la raíz del proyecto objetivo (Assumptions del spec).

## Flags (FR-008)

| Flag | Config equivalente | Tipo | Descripción |
|---|---|---|---|
| `--dir PATH` | `target_dir` | String | Carpeta objetivo a analizar |
| `--include PATH[,PATH...]` | `include_paths` | Array\<String\> | Restringe el análisis a estas subcarpetas/archivos |
| `--exclude PATH[,PATH...]` | `exclude_paths` | Array\<String\> | Excluye estas subcarpetas/archivos |
| `--strictness LEVEL` | `strictness` | Symbol (`low`\|`default`\|`high`) | Nivel de estricticidad |
| `--mutation-types TYPE[,TYPE...]` | `mutation_types` | Array\<Symbol\> | Tipos de mutación a aplicar |
| `--exit-zero` | `exit_on_survivors = false` | Boolean flag | No fallar (exit 0) aunque haya mutaciones "survived" |
| `--json-output PATH` | `json_output_path` | String | Exporta el resumen de resultados a un archivo JSON (FR-015) |
| `--config PATH` | (ubicación del YAML) | String | Usa un archivo de config distinto de `.mutaterb.yml` |
| `-h`, `--help` | — | — | Ayuda de uso |

Cualquier flag no reconocido o con valor de tipo inválido DEBE rechazarse antes de iniciar la
corrida, con un mensaje de error en stderr (FR-011) y el exit code de error operativo (ver
abajo) — nunca con un stack trace de Ruby sin capturar (Principio V).

## Exit codes (FR-013)

| Exit code | Significado |
|---|---|
| `0` | Corrida completa sin mutaciones "survived" (o `exit_on_survivors: false` sin errores operativos) |
| `1` | Corrida completa con al menos una mutación "survived" (comportamiento por defecto) |
| `2` | Error operativo de la herramienta: no se encontraron tests (edge case), config inválida, o falla no relacionada a una mutación puntual |

Nota: fallos puntuales de mutantes individuales (mutación inválida, test colgado) NO producen
exit code 2 — se capturan y reportan como `Mutant#status == :error`/`:killed` sin abortar la
corrida (FR-010, SC-005). Exit code 2 es solo para errores que impiden completar la corrida en
absoluto.

## stdout / stderr

- **stdout**: reporte legible por humanos al finalizar (resumen + lista de mutaciones
  "survived" con archivo/línea/test — FR-006), y progreso incremental opcional durante la
  corrida.
- **stderr**: errores de validación de config/flags, y advertencias (ej. tests base rotos,
  FR-012).

## Señales

- `SIGINT` (`Ctrl+C`): la CLI DEBE capturar la señal, restaurar cualquier archivo mutado en
  progreso a su estado original (FR-005), y terminar con exit code `130` (convención Unix:
  128 + SIGINT), marcando `MutationRun#interrupted = true` en el reporte parcial si se alcanzó
  a imprimir alguno.
