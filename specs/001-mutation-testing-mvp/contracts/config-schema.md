# Contract: Esquema de `.mutaterb.yml`

Archivo YAML opcional en la raíz del proyecto objetivo. Todas las claves son opcionales; los
valores ausentes toman el default de `Config` (ver data-model.md). Cualquier flag de CLI
equivalente sobrescribe el valor de este archivo (FR-009).

```yaml
# .mutaterb.yml (todas las claves son opcionales)

target_dir: "."               # String

include_paths:                # Array<String>
  - "app/models"

exclude_paths:                 # Array<String>
  - "app/models/legacy_thing.rb"

strictness: default            # "low" | "default" | "high"

mutation_types:                # Array<String>, subconjunto de los operadores registrados
  - conditional_boundary
  - boolean_literal
  - nil_literal
  - arithmetic_comparison

exit_on_survivors: true        # Boolean

json_output_path: null         # String | null
```

## Validación (FR-011)

Al cargar el archivo, MutateRB DEBE:

1. Rechazar el archivo si no es un mapping YAML válido de nivel superior (ej. si es una lista o
   un escalar) → `MutateRB::ConfigError`.
2. Rechazar claves con tipo incorrecto (ej. `strictness: 5` en vez de un string) →
   `MutateRB::ConfigError` con el nombre de la clave y el tipo esperado.
3. Rechazar valores de `strictness` fuera de `{low, default, high}`.
4. Rechazar valores de `mutation_types` que no correspondan a un operador registrado.
5. Ignorar (sin fallar) claves desconocidas, mostrando una advertencia en stderr — permite
   evolucionar el esquema sin romper archivos existentes de versiones futuras (compatible hacia
   adelante, no hacia atrás).

Ningún error de validación debe propagarse como excepción sin capturar; siempre se convierte en
un mensaje de error humano-legible antes de terminar el proceso (Principio V).
