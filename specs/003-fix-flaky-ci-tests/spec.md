# Feature Specification: Fix Flaky CI Tests in TestRunner's Fixture Setup

**Feature Branch**: `003-fix-flaky-ci-tests`

**Created**: 2026-09-14

**Status**: Draft

**Input**: User description: reporte de una corrida de CI (`rake spec` en GitHub Actions,
Ruby 3.3.12) donde fallan 2 ejemplos de `spec/mutaterb/test_runner_spec.rb` que pasan en
local: "kills the hung process when the timeout expires" (esperaba `:timeout`, obtuvo
`:error`) y "runs the baseline and reports per-example duration" (esperaba `[:passed]`,
obtuvo `[]`), más una pregunta sobre por qué corren varios jobs de "diferentes versiones".

## User Scenarios & Testing *(mandatory)*

### User Story 1 - CI pasa de forma confiable en toda la matriz de Ruby (Priority: P1)

Como mantenedor, quiero que `rake spec` pase en GitHub Actions igual que pasa en local, en
cada versión de Ruby de la matriz de CI, para que un CI en verde sea una señal confiable antes
de pushear un tag de release.

**Why this priority**: `release.yml` solo dispara con un tag `v*`; si no se puede confiar en
CI, no hay ningún gate real antes de publicar en RubyGems.

**Independent Test**: pushear a una rama y confirmar que el job `test` (las 4 versiones de la
matriz) y el job `lint` terminan en verde.

**Acceptance Scenarios**:

1. **Given** la suite de tests actual, **When** `rake spec` corre dentro de un job de CI
   invocado vía `bundle exec` (es decir, anidado dentro de otro contexto de Bundler), **Then**
   produce el mismo resultado de pass/fail que correrlo directamente en local.
2. **Given** que la propia suite de `TestRunner` levanta un `bundle install` +
   `bundle exec rspec` anidado contra un proyecto de fixture temporal, **When** esa llamada
   anidada corre dentro de un proceso ya bundleado (como en CI), **Then** no se ve afectada
   por el `BUNDLE_GEMFILE`/`BUNDLE_PATH`/`RUBYOPT` del proceso externo.

---

### Edge Cases

- ¿Qué pasa si `bundle install` del fixture temporal falla o apunta al Gemfile equivocado por
  herencia de entorno? Debe quedar aislado (mismo mecanismo que ya protege el código de
  producción) en vez de dejar el fixture sin `rspec` instalado y fallando en silencio.
- Diferencia de comportamiento local vs. CI: en local no se reprodujo la falla (el bundler del
  sistema resolvía igual sin importar el `BUNDLE_GEMFILE` heredado); en CI sí, porque
  `bundler-cache: true` dispone un entorno de Bundler más estricto para el proceso externo
  (`bundle exec rake spec`) que termina filtrándose al `bundle install` anidado del fixture.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El `bundle install` que arma el proyecto de fixture de
  `spec/mutaterb/test_runner_spec.rb` DEBE ejecutarse aislado del entorno de Bundler del
  proceso que corre la propia suite de MutateRB — el mismo problema que ya se resolvió para
  el código de producción (research.md #2 / tarea T041 de la feature 001), pero en el setup
  del test, no en `lib/`.
- **FR-002**: La suite de tests DEBE pasar de forma idéntica sin importar si se invoca como
  `bundle exec rspec`, `bundle exec rake spec`, o `rspec` directo, en cualquier versión de
  Ruby soportada (3.0 a 3.3).
- **FR-003**: El workflow de CI (`ci.yml`) DEBE seguir corriendo la matriz completa de
  versiones de Ruby ya declarada (3.0, 3.1, 3.2, 3.3) más el job de `lint`, sin reducir
  cobertura de versiones como forma de "arreglar" el síntoma.

### Key Entities

No aplica — este es un fix de aislamiento de test, no una feature de datos.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El workflow `ci.yml` termina en verde (los 4 jobs del matrix `test` + el job
  `lint`) en la próxima corrida sobre la rama.
- **SC-002**: La suite completa sigue pasando en local (`bundle exec rake spec`), sin
  regresiones, con el mismo conteo de ejemplos que antes del fix.

## Out of Scope (Non-Goals) para esta iteración

- Cambiar la matriz de versiones de Ruby soportadas por CI.
- Cualquier cambio de comportamiento de producción de MutateRB — esto es exclusivamente sobre
  el aislamiento del entorno del fixture de test, no sobre `lib/mutaterb/test_runner.rb` en
  sí (que ya quedó aislado en la feature 001, tarea T041).
- Relajar la configuración de `bundler-cache`/modo deployment del job de CI.

## Assumptions

- La causa raíz es la misma clase de problema que ya se resolvió con `Bundler.with_unbundled_env`
  en `lib/mutaterb/test_runner.rb` (T041), pero replicada en
  `spec/mutaterb/test_runner_spec.rb#before(:all)`, que arma su propio fixture con un
  `bundle install` anidado sin ese mismo aislamiento.
- Los "3 (o 4) jobs que corren con versiones distintas" que preguntó el usuario son el matrix
  de CI (`ruby: ["3.0", "3.1", "3.2", "3.3"]`) — corridas paralelas de la misma suite contra
  cada versión de Ruby soportada, para detectar incompatibilidades específicas de versión;
  esto es intencional y no es en sí mismo el bug a resolver.
