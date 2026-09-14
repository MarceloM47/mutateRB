# Feature Specification: Minitest Support

**Feature Branch**: `004-minitest-support`

**Created**: 2026-09-14

**Status**: Draft

**Input**: User description: "necesito ahora soporte para minitest también, será una nueva
versión de la gema" (need Minitest support now too, will be a new version of the gem).

## Clarifications

### Session 2026-09-14

- Q: ¿MutateRB necesita saber qué test individual de Minitest falló, o alcanza con saber si
  el archivo de test completo pasó o no? → A: Por test individual, sin agregar dependencias:
  MutateRB parsea la salida verbose nativa de Minitest (`--verbose`) para identificar cada
  test por nombre y duración, con el mismo nivel de precisión que ya tiene con RSpec, sin
  requerir que el proyecto objetivo agregue ninguna gem (p. ej. `minitest-reporters`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run mutation testing on a Minitest project (Priority: P1)

Como desarrollador cuyo proyecto Ruby o Rails usa Minitest en vez de RSpec, quiero que
MutateRB detecte mi suite de Minitest y corra mutation testing sobre ella, para encontrar
tests débiles sin tener que migrar de framework de testing.

**Why this priority**: es el motivo de ser de esta feature — sin esto, MutateRB simplemente no
funciona para gran parte de los proyectos Rails, ya que Rails usa Minitest por defecto.

**Independent Test**: correr `mutaterb` dentro de un proyecto de ejemplo con
`test/**/*_test.rb` y sin carpeta `spec/`; confirmar que detecta y analiza esos tests.

**Acceptance Scenarios**:

1. **Given** un proyecto con `test/**/*_test.rb` y sin RSpec, **When** se corre `mutaterb` sin
   flags, **Then** detecta Minitest automáticamente y produce un reporte de killed/survived
   igual que lo hace hoy para RSpec.
2. **Given** un proyecto Rails que usa Minitest, **When** corre `mutaterb`, **Then** ejecuta la
   suite de la misma forma en que la correría el propio proyecto (respetando
   `RAILS_ENV=test`/carga de entorno de Rails).
3. **Given** un proyecto Ruby puro (sin Rails) que usa Minitest, **When** corre `mutaterb`,
   **Then** carga y corre `test/**/*_test.rb` correctamente sin requerir Rails.

---

### User Story 2 - Proyectos con RSpec y Minitest presentes a la vez (Priority: P2)

Como desarrollador cuyo proyecto tiene tests legacy en Minitest conviviendo con tests nuevos
en RSpec (o viceversa), quiero poder elegir qué framework usa MutateRB (o tener un default
razonable), para que un repo con ambos frameworks no se analice de forma ambigua o
silenciosa.

**Why this priority**: los repos reales migran de framework gradualmente; es un escenario real
pero secundario frente a "que Minitest funcione, punto".

**Independent Test**: correr `mutaterb` contra un fixture con `spec/` y `test/` presentes a la
vez, con y sin un flag explícito de framework.

**Acceptance Scenarios**:

1. **Given** que existen tanto `spec/` como `test/`, **When** se corre `mutaterb` sin
   especificar framework, **Then** elige uno de forma determinística e informa en la salida
   cuál usó y por qué.
2. **Given** que ambos frameworks existen, **When** el usuario pasa un flag o config explícito
   para elegir el framework, **Then** esa elección tiene prioridad sobre la auto-detección.

---

### Edge Cases

- ¿Qué pasa si el proyecto no tiene ni `spec/` ni `test/`? Igual que hoy: mensaje claro de "no
  se encontraron tests", sin importar el framework.
- ¿Qué pasa si el proyecto usa el DSL `minitest/spec` (estilo `describe`/`it` dentro de
  Minitest)? Se sigue tratando como Minitest a nivel de motor de ejecución (sigue siendo
  Ruby/Minitest real, no RSpec), aunque la sintaxis se parezca a RSpec.
- ¿Qué pasa con tests Rails generados por `bin/rails generate` (`ActiveSupport::TestCase`)?
  Deben poder ejecutarse igual que cualquier otro test de Minitest.
- ¿Qué pasa si el formato de la salida `--verbose` de Minitest cambia entre versiones y el
  parseo deja de reconocer una línea? Esa corrida debe reportarse como "error" para ese test
  puntual (mismo tratamiento que un fallo de ejecución hoy, FR-010 de la feature 001), nunca
  como un crash de toda la corrida.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE detectar automáticamente si el proyecto usa RSpec, Minitest, o
  ambos, basándose en la presencia de `spec/**/*_spec.rb` y/o `test/**/*_test.rb`.
- **FR-002**: Cuando ambos frameworks están presentes y el usuario no especificó ninguno, el
  sistema DEBE elegir uno de forma determinística y comunicar en la salida cuál usó.
- **FR-003**: El sistema DEBE exponer una forma de fijar explícitamente el framework a usar
  (flag de CLI y/o archivo de configuración), con prioridad sobre la auto-detección.
- **FR-004**: El sistema DEBE ejecutar los tests de Minitest de la forma en que el propio
  proyecto los correría (usando las herramientas del proyecto, no una reimplementación propia
  del test runner), igual que ya hace con RSpec.
- **FR-005**: El sistema DEBE clasificar cada mutación como "killed"/"survived"/"error" para
  proyectos Minitest con exactamente el mismo significado que para RSpec (FR-004 de la feature
  001).
- **FR-006**: El sistema DEBE aplicar el mismo mecanismo de timeout (FR-014 de la feature 001)
  a los tests de Minitest.
- **FR-007**: El sistema DEBE reportar (consola y export JSON) los resultados de un proyecto
  Minitest en el mismo formato que ya usa para RSpec, sin un esquema separado por framework.
- **FR-008**: La versión de la gema DEBE incrementarse siguiendo versionado semántico para
  reflejar esta nueva capacidad (funcionalidad nueva, no rompe compatibilidad con proyectos
  RSpec existentes → incremento MINOR).
- **FR-009**: El sistema DEBE obtener el resultado (pass/fail) y la duración de cada test
  individual de Minitest parseando la salida verbose nativa de Minitest (`--verbose`), sin
  requerir que el proyecto objetivo agregue ninguna gem adicional (p. ej.
  `minitest-reporters`) para lograrlo.

### Key Entities

- **TestSuite** (existente, extendida): su atributo `framework` deja de estar fijo en
  `:rspec` — ahora puede ser `:rspec` o `:minitest` según lo que se detecte o configure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un desarrollador con un proyecto Rails o Ruby que usa Minitest puede correr
  `mutaterb` sin flags y obtener un resultado de killed/survived, igual que ya podía un
  usuario de RSpec.
- **SC-002**: Los proyectos existentes que usan RSpec siguen funcionando exactamente igual que
  antes de esta feature — cero cambios de comportamiento observable para el caso RSpec-only.
- **SC-003**: Un proyecto con ambos frameworks presentes produce un resultado consistente y
  explicado (el usuario sabe qué framework se usó), nunca un comportamiento ambiguo o
  silencioso.

## Out of Scope (Non-Goals) para esta iteración

- **Otros frameworks de test**: Test::Unit standalone (fuera de Minitest) y Cucumber siguen
  fuera de alcance.
- **Correr ambos frameworks en la misma corrida**: se elige uno por corrida (FR-002/FR-003),
  nunca se corren y combinan resultados de RSpec y Minitest a la vez.
- **Migración de tests entre frameworks**: MutateRB no convierte tests de un framework a otro.

## Assumptions

- Cuando ambos frameworks están presentes y no se especifica ninguno, el default
  determinístico es RSpec — mantiene el comportamiento ya existente para proyectos que ya
  confiaban en eso desde la feature 001.
- Para proyectos Rails con Minitest, se asume que existe `bin/rails` y que los tests se
  pueden ejecutar de forma compatible con `bin/rails test`; para Ruby puro con Minitest, se
  asume que los tests se pueden cargar sin pasos de setup adicionales no estándar más allá de
  `Bundler.require`.
- El mapeo de archivo fuente → archivo de test por convención para Minitest sigue el mismo
  patrón que ya existe para RSpec, pero con `test/` y sufijo `_test.rb` en vez de `spec/` y
  `_spec.rb`.
- Esta feature es aditiva: ningún requisito de la feature 001 se elimina ni se contradice,
  solo se generaliza "RSpec" a "RSpec y/o Minitest" donde correspondía.
