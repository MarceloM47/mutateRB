# Feature Specification: MutateRB — Mutation Testing para Ruby/Rails (MVP)

**Feature Branch**: `001-mutation-testing-mvp`

**Created**: 2026-09-13

**Status**: Draft

**Input**: User description: "MutateRB: herramienta CLI en Ruby 3 para mutation testing sobre
proyectos Ruby y Ruby on Rails ya existentes. Detecta automáticamente los tests del proyecto,
aplica mutaciones al código fuente para verificar si los tests existentes las detectan (si un
test mutado no falla, el test original queda marcado como débil), soporta un archivo de
configuración para fijar carpeta objetivo y configuraciones generales, y expone flags CLI para
nivel de estricticidad, carpetas a incluir/excluir y tipos de mutación a aplicar."

## Clarifications

### Session 2026-09-13

- Q: ¿Qué código de salida (exit code) debe devolver la CLI cuando la corrida termina
  correctamente pero encontró mutaciones "survived" (tests débiles)? → A: Por defecto, exit
  code ≠ 0 si queda al menos una mutación "survived" (0 solo si todas fueron "killed"); este
  comportamiento es configurable vía flag de CLI y archivo de configuración.
- Q: ¿Cuánto tiempo debe esperar la herramienta antes de declarar "timeout" a un test que
  quedó colgado tras una mutación? → A: El doble del tiempo que ese mismo test tardó en la
  corrida base (sin mutar), con un piso mínimo de 5 segundos.
- Q: ¿El export de resultados a un archivo de texto/JSON plano es un requisito real del MVP,
  o solo una posibilidad futura? → A: Sí es un requisito del MVP: la CLI debe poder exportar
  los resultados a un archivo JSON plano además de mostrarlos en consola, vía flag.
- Q: ¿Se debe crear un `README.md` para publicar en RubyGems, o se publica sin él? → A: Sí,
  crear un `README.md` mínimo (instalación, uso, flags principales) — es un entregable
  necesario para la publicación, no una documentación superflua.
- Q: ¿Qué nombre y contacto va en la metadata pública de la gema (autor del gemspec y
  titular del copyright en LICENSE)? → A: Autor "MarceloM47", email
  marcelo.esteche@proton.me.
- Q: ¿El repo debe tener un workflow de GitHub Actions que publique automáticamente a
  RubyGems al pushear un tag `v*`, o solo documentar el proceso manual? → A: Sí, agregar CI
  (tests + rubocop en cada push/PR) y un workflow de release que publica a RubyGems al
  pushear un tag `v*` (vía trusted publisher/OIDC, sin API key en secrets).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Correr mutation testing sin configuración previa (Priority: P1)

Como desarrollador Ruby, quiero ejecutar la herramienta contra mi proyecto (Ruby puro o Rails)
sin tener que indicarle manualmente dónde están mis tests, para obtener una primera evaluación
de la calidad de mi suite con el mínimo esfuerzo.

**Why this priority**: Es el flujo que justifica la existencia de la herramienta (Principio I
de la constitución). Sin detección automática de tests, no hay producto.

**Independent Test**: Se puede probar de forma aislada corriendo la CLI dentro de un proyecto
Ruby de ejemplo (con RSpec) sin ningún archivo de configuración, y verificando que encuentra
los tests y produce un resultado.

**Acceptance Scenarios**:

1. **Given** un proyecto Ruby puro con specs en `spec/`, **When** el usuario ejecuta la CLI sin
   flags ni config, **Then** la herramienta localiza los archivos de test automáticamente y
   corre el análisis de mutación sobre el código cubierto por ellos.
2. **Given** un proyecto Ruby on Rails con specs en `spec/models`, `spec/requests`, etc.,
   **When** el usuario ejecuta la CLI, **Then** la herramienta reconoce la estructura de Rails
   y ejecuta los tests con el entorno de test correspondiente (`RAILS_ENV=test`).
3. **Given** un directorio sin ningún archivo de test reconocible, **When** el usuario ejecuta
   la CLI, **Then** la herramienta termina con un mensaje claro indicando que no encontró tests,
   sin lanzar un error no controlado.

---

### User Story 2 - Identificar tests débiles (Priority: P1)

Como desarrollador, quiero que la herramienta me diga exactamente qué tests no detectaron una
mutación (test débil) y cuáles sí (test fuerte), para poder priorizar qué partes de mi suite
reforzar.

**Why this priority**: Es el resultado central que el usuario viene a buscar; sin esto, correr
mutaciones no aporta valor accionable.

**Independent Test**: Se puede probar introduciendo un test intencionalmente débil (que no
verifica un valor de retorno) y uno fuerte sobre el mismo método, y confirmando que el reporte
distingue a ambos correctamente.

**Acceptance Scenarios**:

1. **Given** un método con un test que sí verifica su comportamiento, **When** se aplica una
   mutación a ese método, **Then** el test falla y la mutación se reporta como "killed"
   (detectada).
2. **Given** un método con un test que no verifica un caso relevante, **When** se aplica una
   mutación a ese caso, **Then** el test sigue pasando y la mutación se reporta como
   "survived", marcando ese test como débil.
3. **Given** una corrida completa, **When** finaliza, **Then** el usuario recibe un resumen con
   el total de mutaciones generadas, cuántas fueron "killed" y cuántas "survived", junto al
   archivo/línea/test asociado a cada mutación sobrevivida.
4. **Given** el usuario pasó el flag de export, **When** la corrida finaliza, **Then** el
   mismo resumen de resultados queda disponible en un archivo JSON plano, además de mostrarse
   en consola.

---

### User Story 3 - Configurar alcance y estricticidad (Priority: P2)

Como desarrollador, quiero fijar carpeta objetivo, nivel de estricticidad y tipos de mutación
vía archivo de configuración y/o flags CLI, para adaptar la herramienta a distintos proyectos y
pipelines sin tocar código.

**Why this priority**: Es una regla de dominio inmutable (Principio III de la constitución),
pero depende de que la detección y ejecución de mutaciones (US1/US2) ya funcionen.

**Independent Test**: Se puede probar corriendo la CLI dos veces sobre el mismo proyecto —una
con config/flags por defecto y otra limitando la carpeta objetivo y el tipo de mutación— y
verificando que la segunda corrida solo mutó lo indicado.

**Acceptance Scenarios**:

1. **Given** un archivo de configuración con una carpeta objetivo específica, **When** se
   ejecuta la CLI sin flags adicionales, **Then** solo se analiza esa carpeta.
2. **Given** un flag de estricticidad alta, **When** se ejecuta la CLI, **Then** se aplican más
   tipos de mutación y/o criterios de "test fuerte" más exigentes que en el nivel por defecto.
3. **Given** un flag que excluye una carpeta, **When** se ejecuta la CLI, **Then** ningún
   archivo de esa carpeta es mutado, aunque el archivo de configuración la incluyera.
4. **Given** flags de CLI y archivo de configuración con valores distintos para la misma
   opción, **When** se ejecuta la CLI, **Then** el flag de CLI tiene prioridad sobre el archivo
   de configuración.
5. **Given** una corrida que finaliza con al menos una mutación "survived", **When** no se usó
   ningún flag ni configuración relacionados al código de salida, **Then** el proceso termina
   con un exit code distinto de cero; **Given** el usuario fijó explícitamente lo contrario vía
   flag o archivo de configuración, **Then** el exit code respeta esa configuración.

---

### Edge Cases

- ¿Qué pasa si un test ya fallaba antes de aplicar cualquier mutación (suite rota de entrada)?
  La herramienta debe detectarlo, excluirlo del conteo de "killed/survived" y reportarlo aparte
  como "test roto previo a la mutación".
- ¿Qué pasa si una mutación genera código Ruby que no parsea o rompe la carga del archivo? Esa
  mutación se descarta como inválida (se reporta como "error", no como "survived") y la corrida
  continúa con el resto.
- ¿Qué pasa si un test queda colgado (loop infinito) tras una mutación? Debe aplicarse un
  timeout por test/mutación —el doble del tiempo que ese test tardó en la corrida base sin
  mutar, con un piso mínimo de 5 segundos—; al vencerse, la mutación se marca como "killed by
  timeout" y la corrida continúa.
- ¿Qué pasa si el proceso se interrumpe (Ctrl+C) a mitad de la corrida? El código fuente
  mutado en ese momento debe restaurarse a su estado original antes de salir.
- ¿Qué pasa si el archivo de configuración es inválido o tiene tipos de dato incorrectos? La
  herramienta debe rechazarlo con un mensaje de validación claro y no arrancar la corrida.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE detectar automáticamente si el proyecto objetivo es Ruby puro o
  Ruby on Rails, sin requerir que el usuario lo indique explícitamente.
- **FR-002**: El sistema DEBE localizar los archivos de test del proyecto (RSpec) sin que el
  usuario tenga que listar rutas manualmente.
- **FR-003**: El sistema DEBE aplicar mutaciones al código fuente cubierto por los tests
  detectados, uno a la vez, ejecutando la suite (o el subconjunto relevante) después de cada
  mutación.
- **FR-004**: El sistema DEBE clasificar cada mutación aplicada como "killed" (algún test
  falló), "survived" (ningún test falló) o "error" (la mutación no pudo ejecutarse, p. ej. por
  código inválido o timeout).
- **FR-005**: El sistema DEBE restaurar el código fuente original después de cada mutación,
  incluso si la ejecución de tests falla de forma inesperada o el proceso se interrumpe.
- **FR-006**: El sistema DEBE generar, al finalizar la corrida, un reporte que liste las
  mutaciones "survived" con su archivo, línea y el/los test(s) que deberían haberlas detectado.
- **FR-007**: El sistema DEBE soportar un archivo de configuración que permita fijar la carpeta
  objetivo y configuraciones generales de ejecución.
- **FR-008**: El sistema DEBE exponer flags de CLI para nivel de estricticidad, carpetas a
  incluir/excluir y tipos de mutación a aplicar.
- **FR-009**: Cuando un flag de CLI y el archivo de configuración definen la misma opción con
  valores distintos, el sistema DEBE priorizar el valor del flag de CLI.
- **FR-010**: El sistema DEBE capturar cualquier error durante la detección de tests, la
  aplicación de mutaciones o la ejecución de la suite, sin abortar el resto de la corrida por
  un fallo puntual.
- **FR-011**: El sistema DEBE validar el tipo de dato y la estructura de las opciones recibidas
  (archivo de config y flags) antes de iniciar la corrida, rechazando configuraciones
  inválidas con un mensaje de error claro.
- **FR-012**: El sistema DEBE identificar y reportar por separado los tests que ya fallaban
  antes de aplicar cualquier mutación, para no contarlos como evidencia de fortaleza o
  debilidad.
- **FR-013**: El sistema DEBE finalizar con un exit code distinto de cero cuando la corrida
  detecta al menos una mutación "survived", salvo que el usuario configure explícitamente lo
  contrario vía flag de CLI o archivo de configuración.
- **FR-014**: El sistema DEBE medir, en una corrida base sin mutaciones, el tiempo de
  ejecución de cada test, y usar el doble de ese tiempo (con un piso mínimo de 5 segundos)
  como timeout al ejecutar ese test contra una mutación.
- **FR-015**: El sistema DEBE poder exportar el resumen de resultados de una corrida a un
  archivo JSON plano (además de mostrarlo en consola), activable vía flag de CLI.
- **FR-016**: El repositorio DEBE incluir un `README.md` con instrucciones de instalación
  (`gem install`) y uso básico de la CLI (comando por defecto y flags principales), como
  entregable necesario para publicar la gema en RubyGems.
- **FR-017**: El gemspec DEBE declarar autor ("MarceloM47") y email
  (marcelo.esteche@proton.me), y el repositorio DEBE incluir un archivo `LICENSE.txt` (MIT)
  con ese mismo nombre como titular del copyright.
- **FR-018**: El repositorio DEBE tener un workflow de CI (GitHub Actions) que corra la
  suite de RSpec y Rubocop en cada push y pull request.
- **FR-019**: El repositorio DEBE tener un workflow de release (GitHub Actions) que publique
  la gema a RubyGems automáticamente al pushear un tag `v*`, usando autenticación por
  trusted publisher (OIDC) en vez de una API key almacenada como secret.

### Key Entities

- **MutationRun**: una ejecución completa de la herramienta sobre un proyecto; agrupa la
  configuración usada (carpeta, estricticidad, tipos de mutación) y el resumen de resultados.
- **Mutant**: una mutación individual aplicada a una ubicación específica del código fuente;
  tiene un tipo de operador, una ubicación (archivo/línea) y un estado (killed, survived,
  error).
- **TestSuite**: la colección de archivos de test detectados para el proyecto objetivo,
  asociada al framework identificado (RSpec) y al tipo de proyecto (Ruby puro / Rails).
- **Config**: el conjunto de opciones resueltas para una corrida (carpeta objetivo,
  estricticidad, tipos de mutación, exclusiones, política de exit code), combinando archivo de
  configuración y flags de CLI.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un desarrollador puede obtener un primer resultado de mutation testing sobre un
  proyecto Ruby o Rails sin escribir ninguna configuración, usando solo el comando por
  defecto.
- **SC-002**: El reporte final identifica el 100% de las mutaciones "survived" generadas en la
  corrida, con archivo, línea y test(s) relacionados, sin intervención manual adicional.
- **SC-003**: Un desarrollador puede limitar el análisis a una carpeta específica o excluir
  otra usando solo flags o el archivo de configuración, sin modificar el código de la
  herramienta.
- **SC-004**: Al finalizar cualquier corrida (exitosa, con errores, o interrumpida por el
  usuario), el código fuente del proyecto analizado queda idéntico al estado previo a la
  ejecución.
- **SC-005**: Ningún error individual (mutación inválida, test colgado, fallo de ejecución)
  detiene la corrida completa; el reporte final siempre se genera con los resultados
  disponibles hasta ese punto.
- **SC-006**: Un desarrollador externo puede instalar la gema con `gem install mutaterb` y
  encontrar instrucciones de uso sin salir de la página del gem en RubyGems.org.

## Out of Scope (Non-Goals) para esta iteración

- **Frameworks de test fuera de RSpec**: soporte para Minitest, Test::Unit o Cucumber queda
  fuera del MVP; se evalúa en una iteración futura.
- **Mutación de vistas/templates**: no se mutan ERB, HAML, Slim ni assets de frontend, solo
  código Ruby (`.rb`).
- **Integración empaquetada con CI/CD**: no se construyen plugins o pasos nativos para GitHub
  Actions, GitLab CI, etc. La CLI puede invocarse desde cualquier script, pero eso es
  responsabilidad del usuario, no un entregable de esta iteración.
- **Reportes visuales**: no se genera reporte HTML, dashboard ni gráficos; el MVP entrega
  salida por consola y, opcionalmente vía flag, un archivo JSON plano (ver FR-015).
- **Ejecución distribuida o en paralelo**: no se implementa paralelización de mutaciones ni
  ejecución multi-máquina en esta iteración; la corrida es secuencial.
- **Mutación de dependencias externas**: solo se muta el código propio del proyecto objetivo,
  nunca gemas instaladas (`vendor/`, `bundle`, etc.).
- **Corrección automática de tests débiles**: la herramienta detecta y reporta tests débiles,
  pero no sugiere ni aplica cambios para arreglarlos.
- **Interfaz gráfica o plugin de editor/IDE**: la única interfaz de esta iteración es la CLI.
- **Historial entre corridas**: cada ejecución es independiente; no se persiste ni compara
  contra corridas anteriores.

## Assumptions

- El framework de test soportado en esta iteración es **RSpec** (el más común en proyectos
  Ruby/Rails); Minitest queda explícitamente fuera de alcance (ver Non-Goals).
- El conjunto inicial de tipos de mutación cubre operadores comunes (condicionales, literales
  booleanos/nil, operadores aritméticos y de comparación); el catálogo completo de operadores
  se expande en iteraciones futuras según el flag de "tipos de mutación".
- El usuario ejecuta la herramienta desde la raíz del proyecto objetivo, con las dependencias
  del proyecto (Bundler) ya instaladas.
- Para proyectos Rails, existe una base de datos de test ya configurada y accesible
  (`RAILS_ENV=test`); la herramienta no provisiona infraestructura de base de datos.
- "Nivel de estricticidad" controla, como mínimo, qué tipos de mutación se aplican y/o qué tan
  exigente es el criterio para considerar un test como fuerte; el detalle fino de los niveles
  se define en el plan de implementación.
- El nombre de gem "mutaterb" está disponible en RubyGems.org (verificado, no publicado por
  terceros).
- El repositorio ya tiene un remoto real de GitHub configurado
  (`github.com/MarceloM47/mutateRB`); ese es el `homepage`/`source_code_uri` a usar en el
  gemspec y en el workflow de release (FR-017, FR-019).
