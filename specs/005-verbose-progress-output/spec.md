# Feature Specification: Verbose Flag and Run Progress Output

**Feature Branch**: `005-verbose-progress-output`

**Created**: 2026-09-14

**Status**: Draft

**Input**: User description: "agrega una feature para un flag --verbose y una librería de cli
para mostrar el progreso al ejecutar el comando" (add a --verbose flag and a way to show
progress while the command runs).

## Clarifications

### Session 2026-09-14

- Q: ¿El indicador de progreso debe "tickear" en vivo (spinner o tiempo transcurrido) mientras
  se espera a que termine el baseline o un mutante lento, o alcanza con actualizaciones
  discretas solo cuando cada fase/mutante termina? → A: Ticker en vivo (Option B): además de
  las actualizaciones discretas al terminar cada mutante/fase, se muestra un indicador que
  avanza solo por tiempo (spinner o segundos transcurridos) mientras una fase está en curso,
  para no dejar silencios largos en baseline o mutantes lentos.
- Q: Cuando se usa `--verbose`, ¿las líneas detalladas por mutante reemplazan al
  contador/ticker por defecto, o ambos se muestran juntos? → A: Reemplaza (Option A):
  en modo verbose solo se ven las líneas por mutante; el contador/ticker por defecto no se
  muestra además, para no mezclar dos formatos de línea distintos.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See that the run is actually working (Priority: P1)

As a developer running `mutaterb` against a real project, I want to see some kind of
ongoing activity in my terminal while the run is in progress, so I know the tool is
working and not stuck, and I don't need to check running processes myself to find out.

**Why this priority**: Today the CLI produces zero output from the moment it starts until
the very end, on runs that can take anywhere from seconds to hours. This is the core pain
point driving the feature and delivers value on its own, without needing `--verbose`.

**Independent Test**: Run `mutaterb` on a project with more than one source file / mutant.
Confirm that new terminal output appears repeatedly while the baseline test suite runs and
while mutants are being processed, before the final summary is printed.

**Acceptance Scenarios**:

1. **Given** a project with mutants left to process, **When** `mutaterb` runs without any
   extra flags, **Then** the terminal shows a running indicator of mutants processed so far
   out of the total, updated as each mutant finishes.
2. **Given** a project whose baseline test suite takes noticeable time to run, **When**
   `mutaterb` starts, **Then** the terminal shows that the baseline suite is running before
   the first mutant is processed, and a live ticker (e.g. elapsed time or a spinner) keeps
   advancing on its own while the baseline is still running.
3. **Given** a run with zero mutants to process (e.g. all source files excluded), **When**
   `mutaterb` runs, **Then** it immediately reports that there is nothing to mutate instead
   of showing an empty or misleading progress display.
4. **Given** a single mutant whose related tests take noticeably longer than others to run,
   **When** that mutant is still being evaluated, **Then** the live ticker keeps advancing so
   the terminal never sits with no changing output for an extended period.

---

### User Story 2 - Inspect what happened to each mutant as it happens (Priority: P2)

As a developer investigating a mutation run (e.g. to understand which files are slow or
why a mutation survived), I want an opt-in `--verbose` flag that prints one line per mutant
as it is evaluated, so I can follow along in detail without waiting for the final report.

**Why this priority**: This builds directly on User Story 1's progress display and serves a
narrower, diagnostic use case; the tool is already usable and non-silent without it.

**Independent Test**: Run `mutaterb --verbose` on a project with several mutants. Confirm
that, for every mutant processed, one line is printed identifying the source file, line
number, mutation type applied, and the resulting classification (killed/survived/error/
timeout), in the order mutants are processed.

**Acceptance Scenarios**:

1. **Given** `--verbose` is passed, **When** a mutant finishes evaluation, **Then** a line
   is printed showing at minimum its file, line number, mutation type, and result.
2. **Given** `--verbose` is not passed, **When** mutants are evaluated, **Then** no
   per-mutant detail lines are printed — only the User Story 1 progress indicator.
3. **Given** `--verbose` is combined with other existing flags (`--strictness`,
   `--framework`, `--exit-zero`, `--json-output`, `--include`, `--exclude`,
   `--mutation-types`), **When** `mutaterb` runs, **Then** every flag keeps its current
   behavior unchanged.
4. **Given** `--verbose` is passed, **When** mutants are being processed, **Then** the
   per-mutant lines replace the default bare counter/ticker for that loop — no separate
   "processed X/Y" line is interleaved with them. The baseline phase message and live
   ticker (User Story 1) still appear before the first mutant either way, since verbose
   only changes how the mutant loop itself is reported.

---

### User Story 3 - Keep logs clean in non-interactive environments (Priority: P3)

As a developer running `mutaterb` in CI or redirecting its output to a log file, I want the
progress output to remain plain, sequential text rather than a terminal-only redrawing
indicator, so captured logs stay readable and don't contain control characters or
overlapping lines.

**Why this priority**: Refinement of Stories 1 and 2 for a secondary environment; the
feature already delivers its core value interactively without this.

**Independent Test**: Run `mutaterb` with stdout redirected to a file (or in a CI job with
no attached terminal). Confirm the resulting log contains one progress update per line,
with no partial/overwritten lines or stray control characters.

**Acceptance Scenarios**:

1. **Given** stdout is not an interactive terminal, **When** `mutaterb` runs, **Then**
   progress updates are printed as separate lines instead of overwriting the same line.
2. **Given** stdout is redirected, **When** the run finishes, **Then** the existing
   end-of-run console summary and any `--json-output` file are unchanged in format.

### Edge Cases

- Run interrupted with Ctrl+C mid-run: progress output stops cleanly and the existing
  final summary (including "interrupted" status) still prints as it does today.
- A single mutant whose related test run times out: this must still be reflected in the
  progress count and, under `--verbose`, reported with a `timeout` result.
- Very large number of mutants (e.g. thousands): the default (non-verbose) progress
  indicator must stay a single, low-noise line/counter rather than one line per mutant, to
  avoid flooding the terminal.
- A single mutant or the baseline run stalls well past its expected duration: the live
  ticker keeps advancing regardless, since it is driven by elapsed time, not by the
  subprocess finishing — it does not by itself prove the run will complete.
- `--verbose` on a run with zero mutants: behaves like User Story 1's "nothing to mutate"
  message; there is nothing to print per-mutant.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display an ongoing progress indicator while the mutation run is
  in progress (covering both the baseline test run and the per-mutant loop), visible by
  default without any extra flag.
- **FR-002**: The default progress indicator MUST show, at minimum, how many mutants have
  been processed so far versus the total, updated as each mutant finishes.
- **FR-003**: System MUST show a distinct message while the baseline test suite is running,
  since it can take significant time before any mutant is processed.
- **FR-003a**: While waiting for the baseline suite or an individual mutant's test run to
  finish, the system MUST show a live ticker (e.g. a spinner or elapsed-time counter) that
  advances on its own on a timer, independent of when that subprocess actually completes,
  so no phase of the run goes without changing output for an extended period.
- **FR-004**: CLI MUST support a `--verbose` flag. When passed, the system MUST print one
  line per mutant as it finishes, including at minimum: source file, line number, mutation
  type applied, and result (killed/survived/error/timeout).
- **FR-005**: When `--verbose` is not passed, per-mutant detail lines MUST NOT be printed;
  only the default progress indicator from FR-001/FR-002 is shown. When `--verbose` IS
  passed, its per-mutant lines REPLACE the default bare counter/ticker for the mutant loop
  (they are not shown interleaved together); the baseline phase message and ticker
  (FR-003/FR-003a) are unaffected by `--verbose` either way, since they precede any mutant.
- **FR-006**: System MUST NOT change the existing end-of-run console summary or the
  `--json-output` file format; progress/verbose output is additive and only appears while
  the run is in progress.
- **FR-007**: When standard output is not an interactive terminal, the system MUST emit
  progress as discrete sequential lines instead of overwriting the same line in place.
- **FR-008**: If there are zero mutants to process, the system MUST report that
  immediately instead of displaying an empty or misleading progress indicator.
- **FR-009**: The `--verbose` flag MUST be combinable with every existing flag
  (`--dir`, `--include`, `--exclude`, `--strictness`, `--framework`, `--mutation-types`,
  `--exit-zero`, `--json-output`, `--config`) without changing any of their current
  behavior.
- **FR-010**: `--verbose` MUST follow the same configuration pattern as the other run
  flags: settable both via the CLI flag and via the `.mutaterb.yml` config file, with the
  CLI flag taking precedence when both are present.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On any run expected to take longer than a few seconds — including while a
  single slow mutant or the baseline suite is still running — a user sees new terminal
  output at least every few seconds, without needing to inspect running processes to
  confirm the tool is active.
- **SC-002**: At any point during a run, a user can tell how many mutants have been
  processed and how many remain within 5 seconds, without reading past output.
- **SC-003**: With `--verbose`, a user can identify the specific mutant (file and line)
  currently being evaluated at any point during the run.
- **SC-004**: Existing automated consumers of the JSON report and the final console
  summary observe no change in format after this feature ships.
- **SC-005**: Logs captured from a non-interactive run (CI, redirected output) contain no
  garbled, overlapping, or control-character-corrupted lines.

## Assumptions

- Progress and verbose output are written to the same stream the final summary already
  uses (`stdout`); operational warnings keep using `stderr` as they do today.
- The default progress indicator is intentionally low-detail (a counter, not a full
  per-mutant log) — full detail is opt-in via `--verbose` specifically to stay readable on
  projects with many mutants.
- A visually animated/percentage progress bar is not required to satisfy this feature; a
  simple counter plus a lightweight live ticker (spinner or elapsed-time) for the phase
  currently in progress is sufficient. The exact presentation mechanism (e.g. a timer
  thread) is a technical decision for `/speckit-plan`, consistent with the project
  constitution's preference for Ruby 3 stdlib solutions unless they prove insufficient.
- This feature only adds visibility into the existing sequential baseline-then-mutant-loop
  execution; it does not change execution order, add parallelism, or alter how mutants are
  selected or classified.
- Ctrl+C / interrupt handling behavior is out of scope for this feature and is not
  expected to change.
