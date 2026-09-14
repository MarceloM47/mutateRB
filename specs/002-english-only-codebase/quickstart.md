# Quickstart Validation: English-Only Codebase & Repository Docs

**Feature**: `002-english-only-codebase`

## Prerequisites

- Ruby >= 3.0 installed
- Bundler installed (`gem install bundler`)
- Repository cloned and on branch `002-english-only-codebase`

## Setup

```bash
bundle install
```

## Validation Scenarios

### V1: No Spanish diacritics in source code

```bash
rg '[áéíóúñüÁÉÍÓÚÑÜ]' lib/ exe/ spec/ README.md
```

**Expected**: Zero output (no matches). If any matches appear, those files still contain Spanish diacritics.

### V2: No common Spanish words in source code

```bash
rg -i '\b(el|la|los|las|un|una|del|por|para|con|sin|sobre|entre|que|como|pero|este|esta|fue|ser|tiene|hace|todo|muy|mas|tambien|puede|desde|hasta)\b' lib/ exe/ README.md
```

**Expected**: Zero output. Note: domain terms like "RSpec", "Rails", "mutant" are not Spanish words and should not match.

### V3: Spec Kit files unchanged

```bash
git diff --name-only -- specs/ .specify/memory/constitution.md
```

**Expected**: Zero output (no files modified in exempt paths).

### V4: RSpec suite passes

```bash
bundle exec rspec
```

**Expected**: All tests pass (same count as before the changes).

### V5: RuboCop passes

```bash
bundle exec rubocop
```

**Expected**: No new offenses (existing TODO offenses are allowed).

### V6: CLI help text is English

```bash
bundle exec exe/mutaterb --help
```

**Expected**: All flag descriptions displayed in English.

### V7: README is English

Open `README.md` and confirm all sentences are in English with no Spanish text remaining.
