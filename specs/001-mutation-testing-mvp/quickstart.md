# Quickstart: Validar MutateRB de punta a punta

Guía para comprobar manualmente que el MVP cumple las User Stories del spec, una vez
implementado. No incluye código de implementación — ver `data-model.md` y `contracts/` para el
diseño, y `tasks.md` (una vez generado por `/speckit-tasks`) para el desglose de trabajo.

## Prerrequisitos

- Ruby 3.x instalado.
- Un proyecto Ruby de ejemplo con RSpec ya configurado (puede ser el propio repo de MutateRB
  usado como "proyecto objetivo" de prueba, o un proyecto Rails pequeño aparte).
- MutateRB instalado localmente: `bundle exec rake install` (o `gem build` + `gem install`)
  desde este repo.

## Escenario 1 — Detección automática sin config (User Story 1)

```bash
cd /ruta/al/proyecto-ruby-de-ejemplo
mutaterb
```

**Resultado esperado**: MutateRB encuentra los specs en `spec/**/*_spec.rb` sin flags, corre el
análisis, e imprime un resumen en consola. Si se corre sobre un proyecto Rails, reconoce
`config/application.rb` y ejecuta los tests con `RAILS_ENV=test` (ver
`contracts/cli.md` y FR-001/FR-002).

Repetir en un directorio vacío sin tests → debe terminar con un mensaje claro (no un stack
trace) y exit code `2` (ver contracts/cli.md).

## Escenario 2 — Identificar tests débiles (User Story 2)

1. En el proyecto de ejemplo, agregar un método simple con dos tests: uno que verifica el
   resultado (test fuerte) y otro que solo llama al método sin verificar nada (test débil).
2. Correr `mutaterb`.

**Resultado esperado**: el resumen final muestra el método del test fuerte como "killed" y el
del test débil como "survived", con archivo/línea/test listados (FR-006, SC-002). Confirmar
también:

```bash
mutaterb --json-output /tmp/mutaterb-report.json
cat /tmp/mutaterb-report.json   # debe matchear contracts/json-report-schema.md
```

## Escenario 3 — Config y estricticidad (User Story 3)

```bash
cat > .mutaterb.yml <<'YAML'
include_paths:
  - "app/models"
strictness: high
YAML

mutaterb                              # usa el YAML
mutaterb --exclude app/models/user.rb # el flag gana sobre include_paths del YAML para ese archivo
```

**Resultado esperado**: la segunda corrida no genera mutantes sobre `user.rb` aunque el YAML lo
incluya (FR-009). Verificar el exit code de ambas corridas:

```bash
mutaterb; echo "exit code: $?"          # 1 si hubo "survived", 0 si no
mutaterb --exit-zero; echo "exit code: $?"  # siempre 0 salvo error operativo
```

## Escenario 4 — Resiliencia (Edge Cases / SC-004, SC-005)

1. Introducir intencionalmente un test con un loop infinito para forzar un timeout.
2. Correr `mutaterb` y confirmar que: (a) esa mutación se reporta como "killed by timeout", (b)
   la corrida continúa y termina con un resumen completo, (c) el archivo fuente queda idéntico
   al original al finalizar (`git diff` vacío sobre el proyecto objetivo).
3. Repetir la corrida e interrumpirla a mitad de camino con `Ctrl+C` → el archivo fuente
   también debe quedar sin cambios (`git diff` vacío).

## Escenario 5 — Lista para publicar en RubyGems (FR-016 a FR-019, SC-006)

```bash
gem build mutaterb.gemspec        # debe generar mutaterb-X.Y.Z.gem sin warnings de metadata
gem install ./mutaterb-*.gem      # instalación local, simula `gem install mutaterb`
mutaterb --help                   # confirma que el binario instalado funciona
rake spec                         # mismo comando que corre CI
bundle exec rubocop
```

**Resultado esperado**: `gem build` no advierte sobre `homepage`/`license`/autor faltantes;
`README.md` y `LICENSE.txt` existen en la raíz; `rake spec` y `rubocop` terminan igual que en
local que en CI. Para probar el workflow de release en sí (`.github/workflows/release.yml`) no
hace falta pushear un tag real: alcanza con revisar que el YAML dispare en `tags: ["v*"]` y use
`rubygems/release-gem`; la publicación real requiere que el mantenedor haya configurado
"trusted publisher" en RubyGems.org apuntando a este repo (paso manual, fuera del alcance del
código).

## Criterio de aceptación de la iteración

El MVP se considera validado cuando los 5 escenarios anteriores se comportan como se describe,
sin intervención manual para restaurar archivos y sin que ningún fallo puntual tumbe el proceso
completo.
