# Quickstart: Validar soporte de Minitest

## Prerrequisitos

- Ruby 3.x. No hace falta instalar `minitest-reporters` ni ninguna gem adicional en los
  proyectos de prueba (FR-009).

## Escenario 1 — Proyecto Ruby puro con Minitest

```bash
mkdir -p /tmp/mt-sample/lib /tmp/mt-sample/test
cat > /tmp/mt-sample/lib/calc.rb <<'RUBY'
class Calc
  def add(a, b) = a + b
end
RUBY
cat > /tmp/mt-sample/test/calc_test.rb <<'RUBY'
require "minitest/autorun"
require_relative "../lib/calc"

class CalcTest < Minitest::Test
  def test_add
    assert_equal 5, Calc.new.add(2, 3)
  end
end
RUBY
cat > /tmp/mt-sample/Gemfile <<'RUBY'
source "https://rubygems.org"
RUBY
cd /tmp/mt-sample && bundle install --quiet
```

Correr `mutaterb --dir /tmp/mt-sample`.

**Resultado esperado**: detecta Minitest automáticamente (no hay `spec/`), muta `calc.rb`, y
la mutación sobre `a + b` queda "killed" (el test sí verifica el resultado).

## Escenario 2 — Ambos frameworks presentes

Agregar a ese mismo proyecto un `spec/calc_spec.rb` con RSpec. Correr `mutaterb` sin flags:
debe imprimir que detectó ambos y que usó RSpec (contracts/framework-detection.md). Correr
`mutaterb --framework minitest`: debe forzar Minitest a pesar de que RSpec también esté
presente.

## Escenario 3 — Proyecto Rails con Minitest

Usar un fixture Rails mínimo (o el mismo patrón que ya usa
`spec/mutaterb/project_detector_spec.rb` para simular Rails: `config/application.rb`
presente) con `test/models/*_test.rb` en vez de `spec/`. Confirmar que corre vía
`bin/rails test` y no vía `ruby` directo.

## Escenario 4 — Test individual débil en Minitest

Igual que el Escenario 2 de quickstart.md de la feature 001, pero con Minitest: un método con
un test que verifica el resultado (killed) y otro con un test que solo llama al método sin
assert (survived) — confirmar que el reporte nombra el test Minitest exacto que sobrevivió,
no solo el archivo (FR-009: granularidad por test).

## Criterio de aceptación de la iteración

La feature se considera validada cuando los 4 escenarios se comportan como se describe, y la
suite completa de MutateRB (incluyendo los tests de RSpec ya existentes de la feature 001)
sigue pasando sin cambios (SC-002: cero regresión para proyectos RSpec-only).
