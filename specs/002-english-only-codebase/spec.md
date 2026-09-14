# Feature Specification: English-Only Codebase & Repository Docs

**Feature Branch**: `002-english-only-codebase`

**Created**: 2026-09-14

**Status**: Draft

**Input**: User description: "todo el código debe estar en idioma inglés, incluyendo archivos
como claude.md o readme.md menos los spec, constitution y demás archivos del speckit" (all
code must be in English, including files like CLAUDE.md or README.md, except spec,
constitution and other Spec Kit files).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read the source code in English (Priority: P1)

As a Ruby developer evaluating or contributing to MutateRB, I want every comment and every
piece of text the CLI can print (console output, `--help`, error/warning messages) written in
English, so I can understand and use the tool without needing to read Spanish.

**Why this priority**: RubyGems' ecosystem convention is English; a public gem with
Spanish-only CLI output or comments is a real adoption barrier for the tool's actual audience.

**Independent Test**: Search `lib/` and `exe/` for Spanish words/diacritics; none should
remain.

**Acceptance Scenarios**:

1. **Given** any file under `lib/` or `exe/`, **When** inspected, **Then** every comment,
   error message, warning, and console/CLI output string is in English.
2. **Given** the CLI is run with `--help` or with invalid input, **When** it prints
   usage/error text, **Then** that text is in English.

---

### User Story 2 - Read repository docs in English (Priority: P1)

As someone finding this gem on GitHub or RubyGems.org, I want `README.md` (and any other
repository-root developer doc, such as `CLAUDE.md` or `CONTRIBUTING.md`) written in English, so
the project reads like a normal English-language open-source Ruby gem.

**Why this priority**: `README.md` is the first thing a prospective user reads — it matters as
much as the code itself for adoption.

**Independent Test**: Read `README.md` end to end and confirm no Spanish sentences remain.

**Acceptance Scenarios**:

1. **Given** `README.md`, **When** read by an English-only speaker, **Then** every sentence is
   understandable without translation.
2. **Given** a `CLAUDE.md` or `CONTRIBUTING.md` is added to the repo root in the future,
   **When** it is written, **Then** it is authored in English from the start.

---

### User Story 3 - Keep the Spec Kit trail in its working language (Priority: P1)

As the maintainer who runs the SDD workflow in Spanish, I want `spec.md`, `plan.md`,
`tasks.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`, `checklists/`, and
the project constitution to keep their current language, so the planning trail I actually work
in day to day isn't disrupted by this policy.

**Why this priority**: this is the explicit boundary the user set for this feature — without
it, "all code" could be misread as also demanding a translation of the SDD paper trail, which
was never the intent and would be pure churn.

**Independent Test**: After applying the English-only change, diff every file under `specs/`
and `.specify/memory/constitution.md` — none should have changed.

**Acceptance Scenarios**:

1. **Given** the Spec Kit artifacts already written in Spanish, **When** the English-only
   change is applied to the rest of the repo, **Then** none of these files are modified.
2. **Given** a new spec is created in the future via `/speckit-specify`, **When** it is
   written, **Then** it may continue to be written in Spanish, unaffected by this policy.

---

### Edge Cases

- ¿Qué pasa con las descripciones de ejemplos de RSpec (`it "..."`, `describe "..."`)? Son
  código fuente (bajo `spec/`), no artefactos de Spec Kit, así que también deben quedar en
  inglés.
- ¿Qué pasa con `summary`/`description` del gemspec? Ya están en inglés — sin cambios
  necesarios.
- ¿Qué pasa con mensajes de commits de git ya hechos en español antes de esta política? Fuera
  de alcance — no se reescribe el historial (ver Non-Goals).
- ¿Qué pasa con términos de dominio que son iguales en ambos idiomas (p. ej. "RSpec", "Rails",
  "mutant")? No son palabras en español a traducir — no requieren ninguna acción.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Todo comentario en archivos Ruby bajo `lib/` y `exe/` DEBE estar en inglés.
- **FR-002**: Todo string que la CLI pueda imprimir (resúmenes de consola, salida de
  `--help`, descripciones de flags, warnings, mensajes de error) DEBE estar en inglés.
- **FR-003**: Toda descripción de ejemplo/grupo de RSpec (`describe`, `context`, `it`) bajo
  `spec/` DEBE estar en inglés.
- **FR-004**: `README.md` DEBE estar escrito enteramente en inglés.
- **FR-005**: Cualquier archivo Markdown de la raíz del repositorio orientado a
  desarrolladores que no sea un artefacto de Spec Kit (p. ej. un futuro `CLAUDE.md` o
  `CONTRIBUTING.md`) DEBE estar en inglés.
- **FR-006**: Los siguientes archivos quedan explícitamente exentos de FR-001 a FR-005 y
  DEBEN mantenerse en su idioma actual: todo archivo bajo `specs/**` (`spec.md`, `plan.md`,
  `tasks.md`, `research.md`, `data-model.md`, `contracts/**`, `quickstart.md`,
  `checklists/**`), y `.specify/memory/constitution.md`.
- **FR-007**: Los identificadores Ruby (nombres de clases/métodos/variables) que ya están en
  inglés DEBEN quedar sin cambios — esta feature es sobre strings y comentarios, no un
  renombrado de identificadores ya conformes.

### Key Entities

No aplica — esta es una política de contenido textual, no una feature de datos.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Una búsqueda de palabras/diacríticos en español en `lib/`, `exe/`, `spec/` y
  `README.md` devuelve cero resultados, fuera de los archivos exentos por FR-006.
- **SC-002**: Todo archivo bajo `specs/**` y `.specify/memory/constitution.md` queda
  byte-a-byte idéntico después de esta feature.
- **SC-003**: La suite completa de RSpec y Rubocop siguen pasando después de todos los
  cambios de texto (traducir strings no debe cambiar el comportamiento).

## Out of Scope (Non-Goals) para esta iteración

- **Reescritura de historial de git**: no se modifican mensajes de commits pasados.
- **Traducción del rastro de Spec Kit**: `spec.md`, `plan.md`, `tasks.md`, `research.md`,
  `data-model.md`, `contracts/`, `quickstart.md`, `checklists/` y la constitución quedan
  explícitamente en español (FR-006).
- **Infraestructura de i18n/l10n en la CLI**: no se agrega un flag `--locale` ni catálogos de
  mensajes traducidos; esta feature estandariza en inglés únicamente, no agrega soporte
  multi-idioma.
- **Renombrar identificadores ya en inglés** por razones de estilo.

## Assumptions

- "Código" en el pedido del usuario se interpreta incluyendo comentarios y cualquier string
  literal que el programa emite (salida de consola, ayuda de CLI, mensajes de error) y las
  descripciones de RSpec — no solo identificadores, ya que los identificadores ya están en
  inglés.
- "Archivos del speckit" se interpreta como: todo bajo `specs/` de cualquier feature, más
  `.specify/memory/constitution.md`. La carpeta `.claude/skills/` (las definiciones de las
  skills de Spec Kit en sí) también queda implícitamente exenta — es tooling de Spec Kit, no
  código o documentación propia de este proyecto.
- Actualmente no existe un `CLAUDE.md` dentro de este repositorio (solo el global del usuario,
  fuera del repo); FR-005 se redacta para cubrir uno si se agrega más adelante, sin requerir
  crear uno ahora.
