# Research: Fix Minitest Baseline Truncated by an Early Test Failure

No quedaron marcadores `[NEEDS CLARIFICATION]` — el bug y su causa raíz ya se confirmaron con
una reproducción directa antes de escribir este spec. Este documento registra esa evidencia y
la decisión de fix.

## 1. Causa raíz confirmada por reproducción

**Decision**: Cambiar `.join(" && ")` por `.join(" ; ")` en
`MinitestAdapter.command_for` (`lib/mutaterb/test_adapters/minitest_adapter.rb`).

**Evidencia**: Se armó el comando exacto que genera `command_for` para dos archivos de test
(uno con un test que falla, otro con uno que pasa) y se ejecutó tal cual, replicando
`Process.spawn` de `TestRunner`. Con `&&`:

```text
$ sh -c 'echo MARK1 && ruby a_test.rb -v && echo MARK2 && ruby b_test.rb -v'
MARK1
... (output de a_test.rb, termina en failure) ...
$ echo $?
1
```

El marcador y el output de `b_test.rb` nunca aparecen — el shell corta la cadena en el primer
`&&` que sigue a un comando con exit code distinto de cero. Con `;` en su lugar, ambos archivos
corren y ambos marcadores/outputs aparecen, sin importar el resultado del primero.

**Rationale**: `ruby archivo.rb`/`bin/rails test archivo -v` devuelve exit code `1` (o más)
cada vez que hay al menos un test fallido o con error — es el estado normal de cualquier
proyecto real, no una excepción. Encadenar con `&&` trata ese exit code exactamente igual que
un error real de shell (comando no encontrado, permiso denegado, etc.), cuando en realidad es
información de negocio (un test falló) que `TestRunner`/`MinitestAdapter.parse` ya sabe
interpretar perfectamente a partir del texto de salida.

**Alternatives considered**:
- Usar `||true` después de cada comando para forzar exit 0 y poder seguir usando `&&` —
  funciona, pero es más ruido textual que simplemente usar el separador correcto (`;`), que ya
  significa exactamente "ejecutá el siguiente comando sin importar el resultado del anterior".
- Envolver cada archivo en su propio `Process.spawn` en vez de un solo comando de shell
  encadenado — se descarta: cambiaría el contrato de `TestRunner` (que asume un solo pid por
  llamada para el timeout/kill, research.md #3 de la feature 004) y es un cambio de arquitectura
  mucho mayor para resolver algo que un cambio de separador ya resuelve.

## 2. Por qué es seguro: nada lee el exit status del shell

**Decision**: Confirmar (vía `grep`) que ni `test_runner.rb` ni ningún adapter usan
`exitstatus`, `$?`, o `success?` en ningún punto — la única fuente de verdad para clasificar un
mutante es el texto parseado de `raw` (`TestRunner#read_and_wait` → `adapter.parse(raw, ...)`).

**Rationale**: Esto es lo que hace seguro cambiar `&&` por `;` sin ningún otro ajuste: no hay
ninguna rama de código que dependa de "el comando compuesto terminó con éxito" para decidir
nada — todo se basa en si aparece o no una línea reconocible (`ClassName#test = Ns = .`) por
archivo.

## 3. RSpec no está afectado (FR-004)

**Decision**: No tocar `RspecAdapter`.

**Rationale**: `RspecAdapter` (extraído en la feature 004) pasa todos los archivos en una sola
invocación de `rspec archivo1 archivo2 ...` — no arma una cadena de comandos por archivo, así
que este problema de encadenamiento con `&&` nunca existió para RSpec. Es una particularidad
de cómo Minitest solo sabe correr un archivo por proceso (research.md #4 de la feature 004).
