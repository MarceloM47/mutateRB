# Research: Minitest Support

No quedaron marcadores `[NEEDS CLARIFICATION]` en el Technical Context (la única ambigüedad
real ya se resolvió en `/speckit-clarify`: granularidad por test individual, sin agregar
dependencias). Este documento registra las decisiones técnicas para llegar de ahí a un diseño
concreto.

## 1. Detección del framework de test (FR-001, FR-002, FR-003)

**Decision**: `ProjectDetector` pasa a devolver también `test_framework` en su
`Detection` (struct extendida: `project_type`, `test_framework`, `test_files`). Regla:
- Si `config.test_framework` es `:rspec` o `:minitest` (fijado por flag/config), se usa ese,
  sin auto-detección.
- Si es `:auto` (default): existe `spec/**/*_spec.rb` → candidato RSpec; existe
  `test/**/*_test.rb` → candidato Minitest. Si solo uno de los dos tiene archivos, se usa ese.
  Si ambos tienen archivos, gana RSpec (Assumption del spec) y se imprime una línea
  informativa indicando que se detectaron ambos y cuál se usó (FR-002/SC-003).

**Rationale**: Es la extensión mínima y simétrica de la detección Ruby/Rails que ya existe
(misma idea: mirar qué hay en el filesystem, sin pedirle nada al usuario).

**Alternatives considered**: Inspeccionar el `Gemfile.lock` en busca de `rspec-rails`/`minitest`
como señal — se descarta porque un `Gemfile.lock` puede listar ambas gems (p. ej. Rails trae
`minitest` siempre como dependencia transitiva) sin que el proyecto realmente tenga tests
escritos en ambos frameworks; mirar los archivos de test reales es una señal más directa y
confiable.

## 2. Parseo de resultados de Minitest sin dependencias nuevas (FR-009)

**Decision**: Ejecutar Minitest con el flag `-v`/`--verbose` (soportado nativamente por
`minitest/autorun` desde hace muchas versiones, sin configuración adicional) y parsear cada
línea con la forma:

```text
ClassName#test_method_name = 0.0123 s = .
```

donde el último carácter es `.` (passed), `F` (failure) o `E` (error); las líneas de tests
"skipped" (`S`) se descartan de `related_tests` en vez de contarlas como passed/failed —mismo
tratamiento que ya reciben los tests con `baseline_status: :failed` (se excluyen, no se
inventan datos).

**Rationale**: Este formato es parte del reporter por defecto de Minitest (no de una gem
externa) y es estable desde hace muchas versiones — es la única vía para lograr granularidad
por test sin pedirle al proyecto objetivo que agregue `minitest-reporters` u otra gem
(decisión explícita de `/speckit-clarify`).

**Alternatives considered**: `minitest-reporters` con un reporter JSON/JUnit — descartado por
requerir una dependencia nueva en el proyecto objetivo, contra lo que pide FR-009. Parsear la
salida no-verbose (solo el resumen final `N runs, N assertions...`) — descartado porque no da
granularidad por test, exactamente lo que `/speckit-clarify` pidió evitar.

## 3. Arquitectura: adapters por framework, sin tocar el motor de spawn/timeout

**Decision**: Extraer de `test_runner.rb` los dos métodos que hoy son 100% específicos de
RSpec (`rspec_command`, `parse_output`) a una clase `RspecAdapter` en
`lib/mutaterb/test_adapters/rspec_adapter.rb`, y crear `MinitestAdapter` como su par para
Minitest. `TestRunner` pasa a recibir el adapter correspondiente (elegido por un hash
`ADAPTERS = { rspec: RspecAdapter, minitest: MinitestAdapter }`, igual patrón que
`Mutator::OPERATORS`) y sigue siendo el único dueño de `Process.spawn`,
`Bundler.with_unbundled_env`, `Timeout.timeout` y `kill` — nada de eso cambia por framework.

**Rationale**: Aísla lo que realmente varía (cómo se arma el comando y cómo se lee su salida)
sin duplicar la lógica de aislamiento de entorno/timeout/kill ya validada y testeada para
RSpec — reduce el riesgo de reintroducir el bug de la feature 003 en el camino nuevo de
Minitest.

## 4. Comando de ejecución de Minitest: Rails vs. Ruby puro

**Decision**:
- Proyecto Rails (`project_type == :rails`): `bin/rails test <archivo(s)> -v` — Rails soporta
  pasar varios archivos en una sola invocación, igual que RSpec.
- Proyecto Ruby puro: `ruby -Itest -Ilib <archivo> -v`, **un proceso por archivo** cuando
  `related_tests` abarca más de un archivo (a diferencia de RSpec, que sí acepta múltiples
  archivos en un solo comando). `TestRunner` arma un único comando de shell uniendo cada
  invocación con `&&` para seguir spawneando un solo proceso hijo desde su punto de vista
  (sin tocar la lógica de timeout/kill, que sigue operando sobre un solo pid).

**Rationale**: `ruby archivo.rb` con `minitest/autorun` solo sabe correr el archivo que se le
pasa directamente; no hay una forma estándar de pedirle "corré estos 3 archivos" sin un
loader propio (que sería más código y más superficie de fallo que encadenar invocaciones).
Como `related_tests` normalmente ya es 1-2 archivos (mapeo por convención), el costo de
procesos adicionales es marginal.

**Alternatives considered**: Escribir un pequeño script loader inline (`ruby -e "ARGV.each
{ |f| require File.expand_path(f) }" -- archivo1 archivo2 -v`) — descartado por ahora: la
mezcla de flags propios de Ruby (`-e`) con los que Minitest espera parsear de `ARGV` (`-v`)
es frágil y no aporta beneficio real dado que ya migramos el problema de "varios archivos" al
caso poco común (Ruby puro, no Rails, con más de un archivo relacionado).

## 5. Mapeo de archivo fuente → archivo de test para Minitest

**Decision**: Mismo mecanismo de convención que ya existe en `Mutator#mapped_spec_file`
(`lib|app/foo.rb` → `<carpeta>/foo_<sufijo>.rb`), parametrizado por el framework detectado:
`spec/` + `_spec.rb` para RSpec (sin cambios), `test/` + `_test.rb` para Minitest.

**Rationale**: Es la misma convención que ya usan `rails generate` y la comunidad Minitest —
consistente con lo ya asumido para RSpec, sin inventar una convención nueva.
