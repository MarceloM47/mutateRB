# MutateRB

A mutation testing tool for Ruby and Ruby on Rails projects: it modifies code covered
by your test suite and checks whether it catches the change. If a mutated test does not
fail, that test is identified as weak. Supports both RSpec and Minitest.

## Installation

```bash
gem install mutaterb
```

Or add it to your `Gemfile`:

```ruby
gem "mutaterb", group: :development
```

## Usage

Run the command from your project root (where your `Gemfile` is):

```bash
mutaterb
```

Without flags, it automatically detects whether the project is pure Ruby or Rails,
which test framework it uses (RSpec if there's a `spec/` folder, Minitest if there's a
`test/` folder — RSpec wins if both are present), applies mutations to covered code,
and displays a summary: how many mutations were "killed" (caught by a test) and how
many "survived" (no test caught them — weak tests), with file, line, and related
test(s) for each survivor.

### Main flags

| Flag | Description |
|---|---|
| `--dir PATH` | Target folder to analyze |
| `--include PATHS` | Restrict analysis to these paths (comma-separated) |
| `--exclude PATHS` | Exclude these paths (comma-separated) |
| `--strictness LEVEL` | `low`, `default`, or `high` |
| `--framework FRAMEWORK` | `auto`, `rspec`, or `minitest` — forces the test framework instead of auto-detecting it |
| `--mutation-types TYPES` | Mutation types to apply, comma-separated |
| `--exit-zero` | Do not fail (exit 0) even if "survived" mutations exist |
| `--json-output PATH` | Export the results summary to a JSON file |
| `--config PATH` | Use a config file other than `.mutaterb.yml` |

You can also set these options in a `.mutaterb.yml` file at the project root; CLI
flags take precedence over the file when both define the same option.

## License

MIT — see [LICENSE.txt](LICENSE.txt).
