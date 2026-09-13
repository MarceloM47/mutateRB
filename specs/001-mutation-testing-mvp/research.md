# Research: MutateRB — Mutation Testing para Ruby/Rails (MVP)

No quedaron marcadores `[NEEDS CLARIFICATION]` en el Technical Context (las ambigüedades de
negocio ya se resolvieron en `/speckit-clarify`). Este documento registra las decisiones
técnicas necesarias para pasar de Technical Context a un diseño concreto (Phase 1).

## 1. Cómo parsear y mutar código Ruby

**Decision**: Usar `RubyVM::AbstractSyntaxTree.parse_file` (stdlib, disponible desde Ruby 2.6)
para obtener nodos con su rango de líneas/columnas, y aplicar cada mutación como un reemplazo
de texto quirúrgico sobre el string fuente original (sin reserializar el archivo completo desde
el AST).

**Rationale**: Preserva formato, comentarios y todo lo que no es el nodo mutado sin esfuerzo
adicional. Es stdlib puro — no agrega dependencias, coherente con el Principio II (Ruby nativo)
y IV (evitar sobreingeniería) de la constitución. Para el set de operadores del MVP
(condicionales, literales booleanos/nil, aritméticos/comparación — ver Assumptions del spec),
la información de posición de `RubyVM::AbstractSyntaxTree` alcanza para ubicar el token exacto
a reemplazar.

**Alternatives considered**: El gem `parser` + `unparser` (usado por herramientas de mutation
testing más maduras como `mutant`) da un AST más rico y portable entre versiones de Ruby, y
`Parser::Source::Rewriter` resuelve el mismo problema de reemplazo quirúrgico de forma más
robusta. Se descarta para el MVP por ser una dependencia externa adicional que el conjunto
acotado de operadores no justifica todavía; queda como camino de escalamiento si el catálogo de
mutaciones crece o si `RubyVM::AbstractSyntaxTree` resulta insuficiente en la práctica.

## 2. Cómo ejecutar los tests del proyecto objetivo

**Decision**: Invocar `bundle exec rspec <archivo_o_ejemplo>` como subproceso vía
`Process.spawn` (redirigiendo stdout/stderr), dentro del directorio del proyecto objetivo,
propagando `RAILS_ENV=test` cuando `ProjectDetector` identifica un proyecto Rails.

**Rationale**: El proyecto objetivo trae su propia versión de RSpec vía su `Gemfile.lock`; no
tiene sentido ni es seguro que MutateRB embeba su propia versión de RSpec como dependencia de
runtime — evita conflictos de versión y respeta la configuración (`.rspec`, `spec_helper.rb`)
que el usuario ya tiene.

**Alternatives considered**: Cargar RSpec in-process (`require "rspec/core"` dentro del mismo
proceso Ruby de MutateRB) sería más rápido (sin overhead de fork/exec por mutante), pero
acoplaría la versión de RSpec de MutateRB con la del proyecto objetivo y complicaría aislar
efectos secundarios de una mutación que cuelga o corrompe el proceso. Se descarta para el MVP.

## 3. Cómo aplicar el timeout por mutación (FR-014)

**Decision**: Medir la duración de cada test en una corrida base (sin mutar) usando el propio
reporte de RSpec (formato `json` de RSpec, vía `--format json`, parseado con `JSON.parse`
stdlib). Para cada mutación, lanzar el subproceso con `Process.spawn`, esperar con
`Process.wait2` dentro de un `Timeout.timeout(2 * duracion_base, piso: 5s)`, y si expira, matar
el proceso explícitamente con `Process.kill("TERM", pid)` (con `Process.kill("KILL", pid)` de
respaldo si no termina) antes de re-lanzar el estado como "killed by timeout".

**Rationale**: `Timeout.timeout` por sí solo no mata el proceso hijo que generó — solo
interrumpe el hilo Ruby que espera; sin matar el proceso explícitamente, un test colgado con un
`sleep` largo o un loop infinito seguiría corriendo en background y consumiendo recursos. Matar
el proceso explícitamente es necesario para cumplir FR-005 (no dejar residuos) y SC-005 (que un
fallo puntual no degrade el resto de la corrida).

**Alternatives considered**: Confiar únicamente en `Timeout.timeout` alrededor de una llamada
bloqueante (`Open3.capture3`) — rechazado porque no garantiza la terminación del proceso hijo.

## 4. Formato y descubrimiento del archivo de configuración (FR-007)

**Decision**: YAML en `.mutaterb.yml` en la raíz del proyecto objetivo, cargado con
`YAML.safe_load` (stdlib `Psych`, modo seguro sin ejecución de código arbitrario).

**Rationale**: Sigue la convención de otras herramientas del ecosistema Ruby (`.rspec`,
`.rubocop.yml`); YAML es trivial de validar campo por campo (FR-011) sin superficie de ataque
de un DSL en Ruby evaluado con `eval`/`instance_eval`.

**Alternatives considered**: Config como Ruby DSL (`mutaterb.config.rb` ejecutado con
`instance_eval`) — más flexible pero introduce riesgo de ejecución de código arbitrario y
complica la validación de tipos exigida por FR-011. Descartado para el MVP.

## 5. Precedencia flags vs. config (FR-009)

**Decision**: `Config` se construye en dos pasos: (1) cargar y validar el YAML si existe, (2)
sobrescribir campo por campo con cualquier flag de CLI presente (parseado con `OptionParser`
stdlib). El resultado final es el único objeto `Config` que usa el resto del sistema.

**Rationale**: Un solo punto de merge evita que distintas partes del código lean config y flags
por separado y diverjan en la precedencia.

## 6. Detección de tipo de proyecto y specs (FR-001, FR-002)

**Decision**: `ProjectDetector` considera un proyecto "Rails" si existe `config/application.rb`
o `bin/rails`; en cualquier otro caso con un `Gemfile`/`spec/` presente, lo trata como "Ruby
puro". Los archivos de test se descubren con `Dir.glob("spec/**/*_spec.rb")` relativo a la raíz
detectada.

**Rationale**: Son las señales estándar y de menor costo para distinguir ambos tipos de
proyecto sin depender de gems de introspección adicionales.

## 7. Política de exit code (FR-013)

**Decision**: El `CLI` calcula el exit code a partir de `MutationRun#survived?` — si hay al
menos un mutante `:survived`, exit 1, salvo que `Config#exit_on_survivors` sea `false` (flag
`--exit-zero` o clave `exit_on_survivors: false` en el YAML), en cuyo caso exit 0 siempre que no
haya habido errores técnicos no relacionados a mutaciones (en cuyo caso exit ≥ 2, reservado
para fallos operativos de la propia herramienta, no de mutaciones).

**Rationale**: Reserva un exit code distinto para "la herramienta falló" vs. "la herramienta
corrió bien pero encontró tests débiles", permitiendo diferenciarlos en un pipeline de CI.

## 8. Export a JSON (FR-015)

**Decision**: El mismo hash de resumen que arma el reporte de consola se serializa con
`JSON.generate` (stdlib) al path indicado por `--json-output PATH`; ver
`contracts/json-report-schema.md` para el esquema exacto.

**Rationale**: Reutilizar la misma estructura de datos para ambas salidas evita mantener dos
fuentes de verdad del resultado de una corrida.
