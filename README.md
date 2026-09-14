# MutateRB

Herramienta de mutation testing para proyectos Ruby y Ruby on Rails: modifica código cubierto
por tus tests RSpec y verifica si la suite detecta el cambio. Si un test mutado no falla, ese
test queda identificado como débil.

## Instalación

```bash
gem install mutaterb
```

O agregala a tu `Gemfile`:

```ruby
gem "mutaterb", group: :development
```

## Uso

Corré el comando desde la raíz de tu proyecto (donde está tu `Gemfile`):

```bash
mutaterb
```

Sin flags, detecta automáticamente si el proyecto es Ruby puro o Rails, ubica los specs en
`spec/`, aplica mutaciones al código cubierto y muestra un resumen: cuántas mutaciones fueron
"killed" (detectadas por algún test) y cuántas "survived" (ningún test las detectó — tests
débiles), con archivo, línea y test(s) relacionados para cada una que sobrevivió.

### Flags principales

| Flag | Descripción |
|---|---|
| `--dir PATH` | Carpeta objetivo a analizar |
| `--include PATHS` | Restringe el análisis a estas rutas (separadas por coma) |
| `--exclude PATHS` | Excluye estas rutas (separadas por coma) |
| `--strictness LEVEL` | `low`, `default` o `high` |
| `--mutation-types TYPES` | Tipos de mutación a aplicar, separados por coma |
| `--exit-zero` | No fallar (exit 0) aunque haya mutaciones "survived" |
| `--json-output PATH` | Exporta el resumen de resultados a un archivo JSON |
| `--config PATH` | Usa un archivo de config distinto de `.mutaterb.yml` |

También podés fijar estas opciones en un archivo `.mutaterb.yml` en la raíz del proyecto; los
flags de CLI tienen prioridad sobre el archivo cuando ambos definen la misma opción.

## Licencia

MIT — ver [LICENSE.txt](LICENSE.txt).
