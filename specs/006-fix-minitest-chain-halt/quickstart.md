# Quickstart: Validar el fix del encadenamiento de Minitest

## Prerrequisitos

- Ruby 3.x, sin gemas adicionales.

## Escenario 1 — Un archivo falla, el siguiente igual debe correr

```bash
mkdir -p /tmp/mt-chain/lib /tmp/mt-chain/test
cat > /tmp/mt-chain/lib/a.rb <<'RUBY'
class A
  def self.broken = 1
end
RUBY
cat > /tmp/mt-chain/test/a_test.rb <<'RUBY'
require "minitest/autorun"
require_relative "../lib/a"
class ATest < Minitest::Test
  def test_fails_on_purpose
    assert_equal 2, A.broken
  end
end
RUBY
cat > /tmp/mt-chain/lib/b.rb <<'RUBY'
class B
  def self.big?(n) = n > 10
end
RUBY
cat > /tmp/mt-chain/test/b_test.rb <<'RUBY'
require "minitest/autorun"
require_relative "../lib/b"
class BTest < Minitest::Test
  def test_big
    assert B.big?(20)
  end
end
RUBY
echo 'source "https://rubygems.org"
gem "minitest"' > /tmp/mt-chain/Gemfile
cd /tmp/mt-chain && bundle install --quiet
```

Correr `mutaterb --dir /tmp/mt-chain --verbose`.

**Resultado esperado**:
- El baseline reporta `ATest#test_fails_on_purpose` como pre-roto (test que ya fallaba antes de
  mutar nada) — prueba que ese archivo SÍ se ejecutó.
- El mutante de `lib/b.rb:2` (`n > 10` → `n >= 10`) aparece clasificado con `tests: BTest#test_big`
  específicamente, no con una lista larga de tests no relacionados — prueba que `b_test.rb`
  también se ejecutó y sus resultados se usaron para la clasificación real, en vez de caer al
  fallback de "toda la suite".

**Antes del fix**: `b_test.rb` nunca corría (el shell cortaba en `a_test.rb`), así que el
mutante de `lib/b.rb` caía al fallback de "toda la suite" — que en los hechos era solo el test
roto de `a_test.rb` — y quedaba mal clasificado.

## Escenario 2 — Suite completamente verde (sin regresión)

Quitar el `assert_equal 2, A.broken` y dejar un assert que sí pase. Correr `mutaterb --dir
/tmp/mt-chain` de nuevo: debe comportarse exactamente igual que antes de este fix (ambos
archivos siempre corrieron cuando no había fallos, así que no hay cambio observable acá).

## Criterio de aceptación de la iteración

La feature se considera validada cuando ambos escenarios se comportan como se describe, y
`bundle exec rake spec` + `bundle exec rubocop` de MutateRB (el proyecto de la gema en sí)
siguen en verde sin regresiones (SC-003).
