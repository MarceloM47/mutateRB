# Quickstart: Validar el fix de aislamiento del fixture de TestRunner

## Prerrequisitos

- Ruby 3.x, Bundler instalado (ya lo usa el resto del proyecto).

## Escenario 1 — Reproducir el síntoma original (antes del fix)

El síntoma solo aparece cuando el proceso externo también corre bajo `bundle exec` con un
entorno de Bundler "cargado" (como lo deja `bundler-cache: true` en CI). Para simular algo
parecido en local:

```bash
cd /home/marcelo/Documentos/mutation-rb
BUNDLE_GEMFILE="$(pwd)/Gemfile" bundle exec rspec spec/mutaterb/test_runner_spec.rb
```

Sin el fix, esto puede reproducir (dependiendo de qué tan estricta esté la config de Bundler
del entorno) alguno de los dos síntomas: `:error` en vez de `:timeout`, o `examples: []` en
vez de `[:passed]`.

## Escenario 2 — Confirmar el fix en local

```bash
bundle exec rake spec
```

**Resultado esperado**: 35/35 ejemplos en verde, incluyendo los dos de
`spec/mutaterb/test_runner_spec.rb`, sin importar si se invoca `rspec` directo,
`bundle exec rspec`, o `bundle exec rake spec` (Acceptance Scenario 1 de User Story 1).

## Escenario 3 — Confirmar en CI

1. Pushear el fix a una rama.
2. Verificar en la pestaña Actions que el job `test` termina en verde en las 4 versiones de
   la matriz (`3.0`, `3.1`, `3.2`, `3.3`) y que el job `lint` también pasa (SC-001).

## Criterio de aceptación de la iteración

El fix se considera validado cuando el Escenario 2 pasa en local y el Escenario 3 pasa en la
próxima corrida real de CI, sin haber tocado `ci.yml` ni `lib/mutaterb/test_runner.rb`.
