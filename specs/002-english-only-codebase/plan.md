# Implementation Plan: English-Only Codebase & Repository Docs

**Branch**: `002-english-only-codebase` | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-english-only-codebase/spec.md`

## Summary

Translate all Spanish text (comments, CLI strings, error messages, RSpec descriptions, README) to English across `lib/`, `exe/`, `spec/`, and repo-root dev docs. Spec Kit files (`specs/**`, `.specify/memory/constitution.md`) remain in Spanish. No structural or behavioral changes — pure textual migration.

## Technical Context

**Language/Version**: Ruby 3 (target: `>= 3.0` per gemspec)

**Primary Dependencies**: None runtime. Dev: `rake ~> 13`, `rspec ~> 3.13`, `rubocop ~> 1.65`

**Storage**: N/A — text content policy, no data model

**Testing**: RSpec 3.13 (~35 tests across 8 spec files) + RuboCop 1.91

**Target Platform**: Cross-platform Ruby gem (CLI tool)

**Project Type**: CLI gem (library + executable)

**Performance Goals**: N/A — no runtime behavior changes

**Constraints**: Must not modify files under `specs/**` or `.specify/memory/constitution.md` (FR-006). Must preserve Ruby identifiers already in English (FR-007). RSpec/RuboCop suites must pass after changes (SC-003).

**Scale/Scope**: ~19 files under `lib/`, 1 under `exe/`, 9 under `spec/`, 1 `README.md`. Of these, 4 lib files + 8 spec files + 1 README = 13 files require translation.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Purpose | ✅ PASS | This feature supports adoption (English ecosystem convention) without changing the tool's mutation-testing purpose |
| II. Stack | ✅ PASS | Pure Ruby 3 — no new languages introduced |
| III. Domain Rules | ✅ PASS | No changes to core detection, config file, or CLI flags behavior |
| IV. Code Style | ✅ PASS | Flat structure maintained; RuboCop enforced; no new patterns |
| V. Error Handling | ✅ PASS | No new error paths; existing begin/rescue blocks unchanged |
| AI Rules | ✅ PASS | Spec is the source of truth; no shadow features added |

**Gate result**: PASS — no violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/002-english-only-codebase/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (N/A — text policy)
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A — no external interfaces)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
mutation-rb/
├── lib/
│   ├── mutaterb.rb                  # Entry point (clean)
│   └── mutaterb/
│       ├── cli.rb                   # NEEDS TRANSLATION (error strings)
│       ├── mutator.rb               # NEEDS TRANSLATION (error strings + comments)
│       ├── reporter.rb              # NEEDS TRANSLATION (console output)
│       ├── flag_parser.rb           # NEEDS TRANSLATION (--help descriptions)
│       ├── config.rb                # Clean
│       ├── version.rb               # Clean
│       ├── errors.rb                # Clean
│       ├── mutant.rb                # Clean
│       ├── test_case.rb             # Clean
│       ├── test_suite.rb            # Clean
│       ├── project_detector.rb      # Clean
│       ├── mutation_run.rb          # Clean
│       ├── test_runner.rb           # Clean
│       └── mutation_operators/      # Clean (4 operator files)
├── exe/
│   └── mutaterb                     # Clean
├── spec/
│   ├── spec_helper.rb               # Clean
│   └── mutaterb/
│       ├── cli_spec.rb              # NEEDS TRANSLATION (describe/it strings)
│       ├── config_spec.rb           # NEEDS TRANSLATION
│       ├── mutator_spec.rb          # NEEDS TRANSLATION
│       ├── mutation_run_spec.rb     # NEEDS TRANSLATION
│       ├── project_detector_spec.rb # NEEDS TRANSLATION
│       ├── reporter_spec.rb         # NEEDS TRANSLATION
│       ├── test_runner_spec.rb      # NEEDS TRANSLATION
│       └── mutation_operators/
│           └── operators_spec.rb    # NEEDS TRANSLATION
├── README.md                        # NEEDS TRANSLATION (full rewrite)
├── mutaterb.gemspec                 # Clean (already English)
├── Gemfile                          # Clean
├── Rakefile                         # Clean
├── .rubocop.yml                     # Clean
└── .github/workflows/               # Clean (CI already English)
```

**Structure Decision**: Single flat gem project. No structural changes needed — this feature is purely textual content translation within the existing layout.

## Complexity Tracking

> No Constitution Check violations — section left empty.
