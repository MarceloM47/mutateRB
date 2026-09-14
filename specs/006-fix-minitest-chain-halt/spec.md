# Feature Specification: Fix Minitest Baseline Truncated by an Early Test Failure

**Feature Branch**: `006-fix-minitest-chain-halt`

**Created**: 2026-09-14

**Status**: Draft

**Input**: User description: "arreglar que MinitestAdapter corta la ejecución de los archivos
de test siguientes cuando un archivo anterior tiene un test que falla, porque los comandos se
encadenan con && y ruby/bin rails test devuelve exit code distinto de cero ante cualquier
fallo" (fix MinitestAdapter stopping execution of later test files when an earlier one has a
failing test, because commands are chained with && and ruby/bin rails test exit non-zero on
any failure).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reliable results on a Minitest project with any failing test (Priority: P1)

As a developer running `mutaterb` on a Minitest project made up of more than one test file, I
want the baseline and every per-mutant test run to actually execute all of the relevant test
files — even when an earlier file in that run has a test that fails or errors — so my
mutation results reflect my project's real test suite instead of a partial, silently
truncated one.

**Why this priority**: This is a correctness bug, not a UX issue. A tool whose entire purpose
is measuring whether tests catch bugs (see project constitution, Principio I) cannot be
trusted if its own baseline silently drops most of the project the moment any test fails —
which is the ordinary state of a real, actively-developed test suite, not an edge case.

**Independent Test**: Run `mutaterb` against a Minitest project with at least two test files,
where a file that is not the last one (in whatever order `mutaterb` processes files) contains
a failing or erroring test. Confirm that test results from every file — including every file
after the failing one — are present in the baseline, and that mutants mapped to those later
files are classified using their own related tests, not an unrelated fallback set.

**Acceptance Scenarios**:

1. **Given** a Minitest project with two test files where the first one has a failing test,
   **When** `mutaterb` runs its baseline, **Then** the baseline includes results from both
   files, not only the first.
2. **Given** a mutant whose related test lives in a file that comes after a failing file,
   **When** that mutant is evaluated, **Then** it is classified using its own related test's
   actual result (killed/survived), not misclassified due to missing baseline data.
3. **Given** a Minitest project where every test currently passes, **When** `mutaterb` runs,
   **Then** behavior is unchanged from before this fix (no regression for the all-green case).

### Edge Cases

- The very first test file processed has a failing or erroring test: previously this dropped
  every other file in that run entirely; now every subsequent file must still run.
- A single mutant's related tests span more than one test file, and one of those files fails:
  the other related file(s) must still contribute to that mutant's classification.
- A test file that fails so badly it exits non-zero without printing any parseable line (e.g.
  a load error): later files must still run; that file's own lack of parseable output is
  handled the same way it already is today (no examples parsed for it).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST execute every test file scheduled for a given baseline or
  per-mutant run, regardless of whether an earlier file in that same run failed, errored, or
  exited with a non-zero status.
- **FR-002**: A failing or erroring test in one file MUST NOT prevent test results from later
  files in the same run from being captured and used for classification.
- **FR-003**: This fix MUST NOT change observed behavior for a run where every test file
  passes — no regression for the existing, common all-green case.
- **FR-004**: This fix applies to Minitest projects; RSpec-based projects, which already run
  all files through a single RSpec invocation rather than chaining per-file commands, are
  unaffected and MUST continue to behave exactly as before.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a project where one non-final test file fails, 100% of test files still
  contribute results to the baseline (previously: 0% of files after the first failure).
- **SC-002**: Mutation classification (killed/survived) for source files whose related tests
  live outside the first failing file matches what it would be if that file had been run in
  isolation, instead of falling back to an unrelated, partial set of tests.
- **SC-003**: Projects whose test suite passes in full show no behavioral change after this
  fix (zero regressions on the existing passing-suite path).

## Assumptions

- The affected code path is specific to Minitest's per-file process chaining; RSpec projects
  are out of scope since they already run every file in one invocation (FR-004).
- This is an internal execution-robustness fix: it does not add, remove, or change any public
  flag, config option, or output format — existing contracts (`contracts/cli.md`,
  `contracts/progress-output.md`) are unaffected.
- No new dependency or interface is required; the fix only changes how already-planned test
  file commands are sequenced.
