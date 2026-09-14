# Research: Fix Flaky CI Tests in TestRunner's Fixture Setup

No quedaron marcadores `[NEEDS CLARIFICATION]` en el Technical Context. La causa raíz ya
estaba diagnosticada con alta confianza en el spec (Assumptions); este documento confirma la
decisión de fix concreta.

## 1. Aislar el `bundle install` del fixture (FR-001)

**Decision**: Envolver la línea `Dir.chdir(@dir) { system("bundle install --quiet", ...) }`
de `spec/mutaterb/test_runner_spec.rb#before(:all)` en `Bundler.with_unbundled_env`, igual que
ya hace `lib/mutaterb/test_runner.rb#spawn_rspec` (tarea T041 de la feature 001).

**Rationale**: Es exactamente el mismo problema (env de Bundler del proceso externo
filtrándose a un `bundle`/`bundle install`/`bundle exec` anidado) en un lugar distinto —
reutilizar el mismo mecanismo ya validado evita inventar una segunda forma de resolverlo.

**Alternatives considered**:
- Instalar `rspec` en el fixture manualmente con `gem install --install-dir` en vez de
  `bundle install` — evita Bundler por completo, pero pierde el objetivo del fixture (probar
  que `TestRunner` invoca `bundle exec rspec` del proyecto objetivo, no `rspec` a secas).
- Correr el `bundle install` del fixture en un proceso completamente separado (`Process.spawn`
  con `unsetenv_others: true`) — funciona, pero es más invasivo que `with_unbundled_env`, que
  ya es la API pensada por Bundler exactamente para este caso.

## 2. Alcance del fix (FR-002, FR-003)

**Decision**: Tocar únicamente `spec/mutaterb/test_runner_spec.rb`. No se toca `ci.yml` (la
matriz de versiones se mantiene) ni `lib/mutaterb/test_runner.rb` (ya está aislado desde T041).

**Rationale**: El síntoma es 100% atribuible al setup de test, no al código de producción ni a
la configuración de CI — reducir la matriz o tocar producción sería resolver el síntoma
equivocado.
