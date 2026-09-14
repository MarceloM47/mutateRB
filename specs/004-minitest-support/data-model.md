# Data Model: Minitest Support

Extiende las entidades de la feature 001 (`Config`, `TestSuite`); no se agregan entidades
nuevas — `test_adapters/` son clases de comportamiento (estrategia de comando/parseo), no
datos.

## Config (extendido)

| Campo nuevo | Tipo | Default | Validación |
|---|---|---|---|
| `test_framework` | Symbol | `:auto` | Debe ser uno de `:auto`, `:rspec`, `:minitest` |

**Reglas**:
- `:auto` → `ProjectDetector` decide según research.md #1.
- `:rspec`/`:minitest` → fuerza ese framework; si el proyecto no tiene archivos de ese tipo,
  se comporta igual que hoy cuando no hay tests (`no tests found`), no un error distinto.

## TestSuite (extendido)

| Campo | Cambio |
|---|---|
| `framework` | Deja de estar hardcodeado a `:rspec` en el constructor; ahora se recibe como
parámetro (`:rspec` o `:minitest`), fijado por `ProjectDetector` al construir la detección. |

`TestSuite::VALID_PROJECT_TYPES` no cambia (`:ruby`/`:rails` sigue siendo ortogonal a
`framework`); se agrega una constante equivalente para el framework:
`VALID_FRAMEWORKS = %i[rspec minitest]`.

## ProjectDetector::Detection (extendido)

| Campo | Cambio |
|---|---|
| `test_framework` | Campo nuevo en el `Struct` (antes solo `project_type`, `spec_files`). |
| `spec_files` | Se renombra conceptualmente a "archivos de test detectados" — sigue siendo
una lista de rutas, ahora pueden ser `*_spec.rb` o `*_test.rb` según `test_framework`. |

## TestCase / Mutant

Sin cambios de forma — ambos ya son agnósticos de framework (`id`, `description`,
`file_path`, `baseline_status`, `baseline_duration_seconds` para `TestCase`; el resto de
`Mutant` no toca nada relacionado a cómo se corrieron los tests). El único cambio de
comportamiento es que Minitest puede producir un `TestCase` con `baseline_status` derivado de
un "skip" (`S`), que se trata igual que un test excluido (ver research.md #2), no como un
tercer valor de `baseline_status` — `VALID_BASELINE_STATUSES` sigue siendo `%i[passed
failed]`; un test "skipped" simplemente no se agrega a la lista de `TestCase` de esa corrida.
