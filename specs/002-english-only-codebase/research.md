# Research: English-Only Codebase & Repository Docs

**Feature**: `002-english-only-codebase`

## R1: How to detect remaining Spanish text programmatically

**Decision**: Use `ripgrep` (rg) with Unicode-aware regex to scan for Spanish diacritics and common Spanish words.

**Rationale**: SC-001 requires zero Spanish words/diacritics in target directories. A manual search is unreliable; a scripted approach ensures repeatability and can be integrated into CI.

**Approach**:
1. Scan for Spanish diacritics: `[áéíóúñüÁÉÍÓÚÑÜ]`
2. Scan for common Spanish stop words that are unambiguous: `("el ", "la ", "los ", "las ", "un ", "una ", "del ", "al ", "por ", "para ", "con ", "sin ", "sobre ", "entre ")`
3. Exclude exempt paths: `specs/**`, `.specify/memory/constitution.md`, `.claude/skills/**`

**Alternatives considered**:
- `grep -r` with locale: works but ripgrep is faster and already in the ecosystem
- Manual review only: rejected — SC-001 demands deterministic verification

## R2: Translation strategy for CLI strings in flag_parser.rb

**Decision**: Translate flag descriptions in-place, preserving the exact OptionParser DSL structure.

**Rationale**: The flag descriptions are user-facing `--help` text. Translating them directly in the OptionParser block is the simplest approach — no i18n framework needed (per Out of Scope).

**Key translations** (from `lib/mutaterb/flag_parser.rb`):
| Spanish | English |
|---|---|
| `Carpeta objetivo` | `Target folder` |
| `Subcarpetas/archivos a incluir` | `Subdirectories/files to include` |
| `Subcarpetas/archivos a excluir` | `Subdirectories/files to exclude` |
| `Tipos de mutacion a aplicar` | `Mutation types to apply` |
| `No fallar si hay tests ya rotos` | `Do not fail if pre-broken tests exist` |
| `Exporta el resumen a un archivo JSON` | `Export summary to a JSON file` |
| `Muestra esta ayuda` | `Show this help` |

## R3: Translation strategy for error/console strings

**Decision**: Translate all user-facing strings in `cli.rb`, `mutator.rb`, and `reporter.rb` in-place.

**Rationale**: These are the 3 files with Spanish error messages and console output. The translations must preserve the same interpolation variables and error semantics.

**Key translations** (from exploration):
| File | Spanish | English |
|---|---|---|
| `cli.rb` | `"Constitution Principio V..."` | `"Constitution Principle V..."` |
| `cli.rb` | `"error inesperado"` | `"unexpected error"` |
| `cli.rb` | `"no se encontraron tests"` | `"no tests found"` |
| `mutator.rb` | `"no se pudo leer"` | `"could not read"` |
| `mutator.rb` | `"mutacion produjo codigo invalido"` | `"mutation produced invalid code"` |
| `mutator.rb` | `"sin tests relacionados"` | `"no related tests"` |
| `mutator.rb` | `"fallo al ejecutar los tests"` | `"failed to run tests"` |
| `reporter.rb` | `"mutaciones"` | `"mutations"` |
| `reporter.rb` | `"errores"` | `"errors"` |
| `reporter.rb` | `"Tests ya rotos antes de mutar"` | `"Pre-broken tests before mutation"` |
| `reporter.rb` | `"Mutaciones survived (tests debiles)"` | `"Survived mutations (weak tests)"` |

## R4: RSpec description translation approach

**Decision**: Translate all `describe`, `context`, and `it` block strings from Spanish to English in all 8 spec files.

**Rationale**: FR-003 requires RSpec descriptions under `spec/` to be in English. These are source code (not Spec Kit artifacts), so the English-only policy applies.

**Files**: `cli_spec.rb`, `config_spec.rb`, `mutator_spec.rb`, `mutation_run_spec.rb`, `project_detector_spec.rb`, `reporter_spec.rb`, `test_runner_spec.rb`, `operators_spec.rb`

## R5: README.md translation approach

**Decision**: Full rewrite of README.md from Spanish to English, preserving all structural elements (headings, code blocks, tables, links).

**Rationale**: FR-004 requires README.md to be entirely in English. The current README is ~50 lines, entirely in Spanish, covering installation, usage, flags table, and license.

## R6: Validation approach

**Decision**: After all translations, run the existing test suite (RSpec + RuboCop) to verify no behavioral changes.

**Rationale**: SC-003 requires tests to pass after changes. Translating strings should not affect behavior since no logic changes.

**Commands**:
```bash
bundle exec rspec          # All tests pass
bundle exec rubocop        # No style violations
rg '[áéíóúñüÁÉÍÓÚÑÜ]' lib/ exe/ spec/ README.md  # Zero results
```
