# Research: Verbose Flag and Run Progress Output

No quedaron marcadores `[NEEDS CLARIFICATION]` en el Technical Context — las dos ambigüedades
reales ya se resolvieron en `/speckit-clarify` (mecanismo de ticker en vivo, y que `--verbose`
reemplaza al contador por defecto durante el loop de mutantes). Este documento registra las
decisiones técnicas para llegar de ahí a un diseño concreto.

## 1. Mecanismo del ticker en vivo (FR-003a)

**Decision**: `ProgressReporter` corre un único `Thread` en segundo plano por fase (baseline,
y luego el loop de mutantes cuando no es verbose), que se despierta en un intervalo fijo
(`sleep tick_interval`) y redibuja la línea actual a partir de un estado compartido simple
(`phase`, `processed`, `total`, `phase_started_at`), protegido por un `Mutex` para las
lecturas/escrituras cruzadas entre el hilo principal (que actualiza `processed`) y el hilo del
ticker (que solo lee para dibujar). El cuerpo del hilo va envuelto en
`begin ... rescue StandardError ... end` (Principio V): si algo falla al dibujar, el ticker
deja de actualizarse pero la corrida real (que vive en el hilo principal) nunca se ve afectada.
El hilo se mata y se hace `join` explícito al terminar cada fase (`finish_baseline`,
`finish_mutants`), para no dejar hilos huérfanos corriendo después de que termina `mutaterb`.

**Rationale**: Es la única forma de cumplir SC-001 ("output nuevo al menos cada pocos
segundos") cuando el trabajo real ocurre dentro de un subproceso opaco cuyo output solo se lee
completo al terminar (`TestRunner#read_and_wait`, que hace `stdout_read.read` bloqueante) — no
hay forma de "engancharse" al progreso interno de RSpec/Minitest sin agregarles una dependencia
al proyecto objetivo, algo que la Constitution y features anteriores (004, research.md #2)
explícitamente evitan.

**Alternatives considered**: Actualizar el indicador solo cuando cada mutante/baseline termina
(sin hilo aparte) — es lo que decidió NO usar `/speckit-clarify` (Option A rechazada),
justamente porque un mutante lento o un baseline largo volvían a dejar la terminal en silencio
por decenas de segundos, el problema original que motiva la feature.

## 2. Interactivo (TTY) vs. no interactivo (FR-007, SC-005)

**Decision**: `$stdout.tty?` decide el modo de dibujo:
- **TTY**: el ticker redibuja la misma línea con `\r` (sin `\n`) en un intervalo corto
  (por defecto 0.3s) — da sensación de spinner/contador vivo sin acumular líneas.
- **No TTY** (pipe, archivo, CI): el ticker imprime una línea nueva (`\n`, sin `\r`) en un
  intervalo más espaciado (por defecto 5s) — un "heartbeat" legible en logs, sin inundarlos ni
  dejar caracteres de control sueltos (SC-005). Cualquier actualización síncrona (ej. el mensaje
  de inicio de baseline) también se imprime como línea completa en ambos modos.

**Rationale**: `IO#tty?` es stdlib, ya usado implícitamente por herramientas como RSpec/Rubocop
para la misma decisión; separar el intervalo por modo evita que un log de CI se llene de líneas
casi idénticas cada 0.3s sin sacrificar la "sensación de vida" en una terminal interactiva.

**Alternatives considered**: Un único intervalo para ambos modos — descartado porque 0.3s en un
log de archivo produce ruido (miles de líneas en una corrida de minutos) y 5s en una terminal
interactiva se siente "colgado" igual que hoy durante los primeros segundos de cada fase.

## 3. Contar el total de mutantes por adelantado, sin correr tests (FR-002)

**Decision**: `Mutator` memoiza la lista completa de mutantes candidatos (recorrido de
`source_files` + `candidates_for(file)` para cada uno, exactamente el mismo cómputo que ya hace
`each_mutant`, pero materializado una sola vez en un array cacheado) y expone
`total_mutants` (`= candidates.size`). `each_mutant` pasa a iterar sobre esa lista cacheada en
vez de recalcularla. La CLI llama `mutator.total_mutants` antes de arrancar el loop para
inicializar `ProgressReporter#start_mutants(total)`; si es `0`, imprime el mensaje de FR-008 y
salta directamente al resumen final sin instanciar ningún ticker.

**Rationale**: Descubrir candidatos es puro parseo (AST/regex sobre archivos fuente vía los
`MutationOperators`), sin efectos secundarios ni ejecución de tests — materializarlo una vez no
cambia el comportamiento observable de `each_mutant`, solo evita que sea un generador
"ciego" al total. Es el cambio mínimo necesario para que el contador "X/Y" de FR-002 tenga
sentido.

**Alternatives considered**: Mostrar solo un conteo incremental sin total conocido (ej. "12
mutantes procesados" sin "de cuántos") — descartado porque no cumple FR-002 ("cuántos
procesados **versus el total**"), que fue precisamente lo que pidió la User Story 1 original.

## 4. Plomería de `--verbose`: mismo patrón que los flags existentes (FR-009, FR-010)

**Decision**: `--verbose` se agrega exactamente con el mismo patrón que `--exit-zero` y
`--framework`:
- `FlagParser`: `opts.on("--verbose", "Print one line per mutant as it runs") { flags[:verbose] = true }`
  (flag booleano, sin argumento — igual que `--exit-zero`).
- `Config`: nuevo `attr_accessor :verbose`, default `false` en el constructor,
  `attributes_from_yaml` reconoce la key `"verbose"` (`raw.fetch("verbose", false)`) y se agrega
  a `known_keys`, `validate!` exige `[true, false].include?(verbose)` (mismo chequeo que ya
  existe para `exit_on_survivors`).
- `Reporter#config_h` (JSON export) agrega `verbose: c.verbose`, siguiendo el mismo precedente
  que ya sentaron `exit_on_survivors`, `test_framework`, etc. — cada campo de `Config` aparece
  ahí; esto no viola FR-006 (que prohíbe que el *progreso en vivo* se filtre al reporte final,
  no que un nuevo campo de configuración aparezca junto a los demás).

**Rationale**: Cero patrones nuevos — reutiliza exactamente la misma ruta ya validada por
`exit_on_survivors`/`test_framework` en las features 001 y 004 (Principio IV: no reinventar por
cada flag).

## 5. `ProgressReporter` como colaborador inyectado, no acoplado al motor (Principio IV)

**Decision**: `ProgressReporter` vive en `lib/mutaterb/progress_reporter.rb`, hermano de
`Reporter`. Lo instancia y posee `CLI#execute`; se pasa como parámetro a los métodos que ya
hacen las llamadas bloqueantes (`build_test_suite`, `run_mutations`), que lo envuelven así:

```text
progress.start_baseline
examples = test_runner.run_baseline(files)
progress.finish_baseline

total = mutator.total_mutants
progress.start_mutants(total)  # o progress.nothing_to_mutate! si total == 0
mutator.each_mutant do |mutant|
  run.add_mutant(mutant)
  progress.mutant_finished(mutant)
  break if yield
end
progress.finish_mutants
```

`TestRunner` y `Mutator` no reciben ninguna referencia a `ProgressReporter` ni saben que existe
— siguen siendo puro motor de mutación/ejecución, testeable sin ningún mock de presentación.

**Rationale**: Mantiene la separación que ya pedía la Constitution (Principio IV: estructura
plana, sin acoplar responsabilidades) y evita que `TestRunner`/`Mutator` (que ya tienen specs
completos y estables) necesiten cambiar solo porque cambia cómo se muestra el progreso.

**Alternatives considered**: Pasarle un callback/bloque a `TestRunner#run_baseline` y
`Mutator#each_mutant` para que "avisen" del progreso desde adentro — descartado porque
obligaría a `TestRunner` a saber de fases/ticks aunque su única responsabilidad sea spawnear y
matar procesos; la envoltura desde `CLI` ya tiene toda la información necesaria (cuándo empieza
y termina cada llamada) sin tocar esas clases.

## 6. Sin gemas nuevas (Principio II)

**Decision**: Todo se implementa con stdlib de Ruby 3: `Thread`, `Mutex`, `Time`, `$stdout`,
`IO#tty?`, `String` (para el spinner, ej. ciclar por `%w[| / - \\]`). No se agrega
`ruby-progressbar`, `tty-progressbar`, `tty-spinner` ni ninguna gem de CLI.

**Rationale**: El requerimiento real (un contador, un mensaje de fase, un spinner/tiempo
transcurrido, y una línea por mutante en verbose) es tan simple que cualquier gema de progreso
sería una dependencia nueva para resolver algo que la stdlib ya cubre — exactamente el tipo de
sobre-ingeniería que el Principio IV y el Principio II (Ruby puro salvo que no alcance) piden
evitar. Además, como la propia gema es la que corre dentro del proyecto objetivo del usuario
(no como dependencia de desarrollo), cada gema nueva es una gema más que instalar en el entorno
del usuario final.

**Alternatives considered**: `tty-spinner`/`tty-progressbar` (gemas de la suite `tty-*`) —
ofrecen spinners más pulidos, pero agregan una dependencia de runtime nueva para un problema
que un `Thread` + 4 caracteres de spinner resuelven en un puñado de líneas.

## 7. Testabilidad del ticker (evitar specs lentos o flaky)

**Decision**: `ProgressReporter.new` acepta `tick_interval:` (con default sensato por modo,
ver research.md #2) e `io:` (default `$stdout`) como parámetros inyectables. Los specs unitarios
de mensajes/formato instancian con un `io` tipo `StringIO` y, cuando necesitan probar el
comportamiento del ticker en sí, un `tick_interval` mínimo (ej. `0.01`) en vez de depender de
los defaults reales — nunca se hace `sleep` con los intervalos de producción (0.3s/5s) dentro
de la suite de specs.

**Rationale**: Mismo criterio que ya sigue el resto de la suite de MutateRB (`TestRunner`
recibe sus dependencias por parámetro, nunca las hardcodea) — permite verificar el
comportamiento real del hilo sin que la suite se vuelva lenta o dependiente de timing de
sistema operativo.
