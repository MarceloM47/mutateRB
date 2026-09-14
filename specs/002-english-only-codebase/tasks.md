# Tasks: English-Only Codebase & Repository Docs

**Input**: Design documents from `/specs/002-english-only-codebase/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, quickstart.md

**Tests**: Not explicitly requested in the feature specification. Validation is via the existing RSpec + RuboCop suites and Spanish-detection scripts (SC-001, SC-003).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Capture baseline state before any changes

- [X] T001 Capture current RSpec test count and RuboCop offense count as baseline for SC-003 validation

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Ensure validation tooling is ready before translation work begins

- [X] T002 Verify ripgrep is available and Spanish diacritic detection script works against current codebase (expected: matches found since code is currently Spanish)

---

## Phase 3: User Story 1 - Read the source code in English (Priority: P1) 🎯 MVP

**Goal**: Every comment, error message, warning, and CLI output string under `lib/` and `exe/` is in English. Every RSpec `describe`/`context`/`it` string under `spec/` is in English.

**Independent Test**: `rg '[áéíóúñüÁÉÍÓÚÑÜ]' lib/ exe/ spec/` returns zero results.

### Implementation for User Story 1

- [X] T003 [P] [US1] Translate Spanish error strings and comments in `lib/mutaterb/cli.rb` — replace "Constitution Principio V" with "Constitution Principle V", "error inesperado" with "unexpected error", "no se encontraron tests" with "no tests found"
- [X] T004 [P] [US1] Translate Spanish error strings and comments in `lib/mutaterb/mutator.rb` — replace "no se pudo leer" with "could not read", "mutacion produjo codigo invalido" with "mutation produced invalid code", "sin tests relacionados" with "no related tests", "fallo al ejecutar los tests" with "failed to run tests", translate all Spanish comments
- [X] T005 [P] [US1] Translate Spanish console output strings in `lib/mutaterb/reporter.rb` — replace "mutaciones" with "mutations", "errores" with "errors", "Tests ya rotos antes de mutar" with "Pre-broken tests before mutation", "Mutaciones survived (tests debiles)" with "Survived mutations (weak tests)"
- [X] T006 [P] [US1] Translate Spanish flag descriptions in `lib/mutaterb/flag_parser.rb` — replace "Carpeta objetivo" with "Target folder", "Subcarpetas/archivos a incluir" with "Subdirectories/files to include", "Subcarpetas/archivos a excluir" with "Subdirectories/files to exclude", "Tipos de mutacion a aplicar" with "Mutation types to apply", "No fallar si hay tests ya rotos" with "Do not fail if pre-broken tests exist", "Exporta el resumen a un archivo JSON" with "Export summary to a JSON file", "Muestra esta ayuda" with "Show this help"
- [X] T007 [P] [US1] Translate RSpec descriptions in `spec/mutaterb/cli_spec.rb` — replace all Spanish `describe`/`context`/`it` strings with English equivalents
- [X] T008 [P] [US1] Translate RSpec descriptions in `spec/mutaterb/config_spec.rb` — replace all Spanish `describe`/`context`/`it` strings with English equivalents
- [X] T009 [P] [US1] Translate RSpec descriptions in `spec/mutaterb/mutator_spec.rb` — replace all Spanish `describe`/`context`/`it` strings with English equivalents
- [X] T010 [P] [US1] Translate RSpec descriptions in `spec/mutaterb/mutation_run_spec.rb` — replace all Spanish `describe`/`context`/`it` strings with English equivalents
- [X] T011 [P] [US1] Translate RSpec descriptions in `spec/mutaterb/project_detector_spec.rb` — replace all Spanish `describe`/`context`/`it` strings with English equivalents
- [X] T012 [P] [US1] Translate RSpec descriptions in `spec/mutaterb/reporter_spec.rb` — replace all Spanish `describe`/`context`/`it` strings with English equivalents
- [X] T013 [P] [US1] Translate RSpec descriptions in `spec/mutaterb/test_runner_spec.rb` — replace all Spanish `describe`/`context`/`it` strings with English equivalents
- [X] T014 [P] [US1] Translate RSpec descriptions in `spec/mutaterb/mutation_operators/operators_spec.rb` — replace all Spanish `describe`/`context`/`it` strings with English equivalents
- [X] T015 [US1] Run `rg '[áéíóúñüÁÉÍÓÚÑÜ]' lib/ exe/ spec/` to verify zero Spanish diacritics remain in source code

**Checkpoint**: All source code comments, CLI strings, error messages, and RSpec descriptions are in English. `rg` scan returns zero matches.

---

## Phase 4: User Story 2 - Read repository docs in English (Priority: P1)

**Goal**: `README.md` is entirely in English, reading like a standard English-language open-source Ruby gem.

**Independent Test**: Read `README.md` end to end — no Spanish sentences remain.

### Implementation for User Story 2

- [X] T016 [US2] Translate `README.md` from Spanish to English — preserve all structural elements (headings, code blocks, flags table, links, license section); replace installation instructions, usage examples, flag descriptions, and license text with English equivalents
- [X] T017 [US2] Run `rg '[áéíóúñüÁÉÍÓÚÑÜ]' README.md` to verify zero Spanish diacritics remain

**Checkpoint**: README.md is fully English. No Spanish text remains in repo-root dev docs.

---

## Phase 5: User Story 3 - Keep the Spec Kit trail in its working language (Priority: P1)

**Goal**: All Spec Kit artifacts (`specs/**`, `.specify/memory/constitution.md`) remain byte-for-byte identical after the English-only changes.

**Independent Test**: `git diff --name-only -- specs/ .specify/memory/constitution.md` returns zero results.

### Implementation for User Story 3

- [X] T018 [US3] Run `git diff --name-only -- specs/ .specify/memory/constitution.md` to verify no Spec Kit files were modified
- [X] T019 [US3] Run `git diff -- .claude/skills/` to verify no Spec Kit skill definitions were modified

**Checkpoint**: Spec Kit trail is untouched. No files under `specs/` or `.specify/` were changed.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across all user stories

- [X] T020 Run full RSpec suite (`bundle exec rspec`) and verify same test count as baseline from T001 — SC-003
- [X] T021 Run RuboCop (`bundle exec rubocop`) and verify no new offenses — SC-003
- [X] T022 Run `bundle exec exe/mutaterb --help` and confirm all flag descriptions are in English — SC-001
- [X] T023 Run full Spanish diacritic scan: `rg '[áéíóúñüÁÉÍÓÚÑÜ]' lib/ exe/ spec/ README.md` — SC-001
- [X] T024 Run common Spanish word scan: `rg -i '\b(el|la|los|las|un|una|del|por|para|con|sin|sobre|entre|que|como|pero|este|esta|fue|ser|tiene|hace|todo|muy|mas|tambien|puede|desde|hasta)\b' lib/ exe/ README.md` — extra safety check

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion
- **US1 (Phase 3)**: Depends on Foundational completion
- **US2 (Phase 4)**: Depends on Foundational completion — can run in parallel with US1
- **US3 (Phase 5)**: Depends on US1 and US2 completion (verification after changes)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational (Phase 2) — No dependencies on other stories
- **US2 (P1)**: Can start after Foundational (Phase 2) — Independent of US1
- **US3 (P1)**: Depends on US1 and US2 — verification task, runs after translations complete

### Within Each User Story

- US1: lib/ translations (T003-T006) are independent of spec/ translations (T007-T014) — all can run in parallel
- US2: Single file translation (T016), then verification (T017)
- US3: Verification only (T018-T019), depends on US1+US2 complete

### Parallel Opportunities

- T003, T004, T005, T006 (all lib/ files) can run in parallel
- T007, T008, T009, T010, T011, T012, T013, T014 (all spec/ files) can run in parallel
- T003-T006 and T007-T014 can all run in parallel (different directories)
- US1 (Phase 3) and US2 (Phase 4) can run in parallel once Phase 2 completes

---

## Parallel Example: User Story 1

```bash
# Launch all lib/ translations together (different files, no conflicts):
Task: "Translate lib/mutaterb/cli.rb"
Task: "Translate lib/mutaterb/mutator.rb"
Task: "Translate lib/mutaterb/reporter.rb"
Task: "Translate lib/mutaterb/flag_parser.rb"

# Launch all spec/ translations together (different files, no conflicts):
Task: "Translate spec/mutaterb/cli_spec.rb"
Task: "Translate spec/mutaterb/config_spec.rb"
Task: "Translate spec/mutaterb/mutator_spec.rb"
Task: "Translate spec/mutaterb/mutation_run_spec.rb"
Task: "Translate spec/mutaterb/project_detector_spec.rb"
Task: "Translate spec/mutaterb/reporter_spec.rb"
Task: "Translate spec/mutaterb/test_runner_spec.rb"
Task: "Translate spec/mutaterb/mutation_operators/operators_spec.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (capture baseline)
2. Complete Phase 2: Foundational (verify tooling)
3. Complete Phase 3: User Story 1 (translate all source code)
4. **STOP and VALIDATE**: Run `rg` scan + RSpec suite
5. Source code is now English-only — core value delivered

### Incremental Delivery

1. Setup + Foundational → Baseline captured
2. US1 → All source code translated → Validate with `rg` + RSpec → Deploy
3. US2 → README translated → Validate → Deploy
4. US3 → Verify Spec Kit untouched → Final validation → Done

### Parallel Team Strategy

With multiple developers:

1. Complete Setup + Foundational together
2. Once Foundational is done:
   - Developer A: US1 — translate lib/ files (T003-T006)
   - Developer B: US1 — translate spec/ files (T007-T014)
   - Developer C: US2 — translate README (T016)
3. All merge → US3 verification → Polish → Done

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- No new code is written — only string literals and comments are modified
- FR-006 (Spec Kit exemption) and FR-007 (identifier preservation) are enforced by verification tasks T018-T019
- Commit after each task or logical group (e.g., all lib/ translations, all spec/ translations)
