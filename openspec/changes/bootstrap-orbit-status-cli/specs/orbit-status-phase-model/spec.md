## ADDED Requirements

### Requirement: Phase enum is closed and fixed

Each change record's `phase` field SHALL be one of exactly six values: `exploring`, `proposed`, `applying`, `reviewing`, `verified`, `archived`.

orbit-status MUST NOT emit any other value in the `phase` field. Extending the enum is a schema-breaking change.

#### Scenario: Every emitted change has a valid phase
- **WHEN** orbit-status emits `--json` against a project with any number of changes across the `active`, `exploring`, and `recent` buckets
- **THEN** every change record's `phase` value is one of `exploring`, `proposed`, `applying`, `reviewing`, `verified`, `archived`

### Requirement: Phase inference uses precedence ordering

orbit-status SHALL infer a change's phase using the following precedence — first matching condition wins. **Change-directory precedence**: when `openspec/changes/<name>/` exists, rules 1–4 evaluate against its artifacts. Rule 5 (exploring) requires the absence of `openspec/changes/<name>/`, so the change directory always wins over a sibling `openspec/explore/<name>/` staging directory when both exist (e.g., during `/opsx:propose`).

1. Change directory is under `openspec/changes/archive/` → `archived`
2. The most recent JSON in the change's `.orbit-runs/` directory — ordered by the ISO-8601 timestamp embedded in each filename (e.g., `review-proposal-2026-05-18T01-47-44Z.json`), descending — determines phase, **provided the JSON's timestamp is newer than `tasks.md` mtime**. If the JSON predates the most recent `tasks.md` modification, rule 2 does not apply and inference falls through to rule 3 (so that a mid-apply edit to `tasks.md` correctly classifies as `applying` rather than being stuck at a stale `reviewing` from an older review JSON):
   - filename matches `archive-*.json` → `archived` (file move pending)
   - filename matches `review-*.json` or `address-reviews-*.json` → `reviewing`
3. `tasks.md` exists with at least one `[x]` and at least one `[ ]` checkbox → `applying`
4. `proposal.md` exists, and `tasks.md` is absent or contains no `[x]` → `proposed`
5. `explore.md` exists at `openspec/explore/<name>/explore.md`, no change directory at `openspec/changes/<name>/` → `exploring`
6. `verified` is reserved for future use when `/opsx:verify` emits run-summary JSONs

#### Scenario: Archived directory wins over all other signals
- **WHEN** a change exists under `openspec/changes/archive/<dated>-<name>/` with a populated `.orbit-runs/` directory
- **THEN** phase is `archived`, regardless of which JSON file is most recent in `.orbit-runs/`

#### Scenario: Most recent review JSON triggers reviewing
- **WHEN** an active change has `.orbit-runs/review-proposal-<ts>.json` as the most recent file by timestamp, and `tasks.md` is absent
- **THEN** phase is `reviewing`

#### Scenario: Partial tasks.md triggers applying
- **WHEN** an active change has `tasks.md` with some `[x]` and some `[ ]`, and no `.orbit-runs/*.json` newer than the most recent `tasks.md` modification time
- **THEN** phase is `applying`

#### Scenario: proposal-only triggers proposed
- **WHEN** an active change has `proposal.md` but no `tasks.md` and no `.orbit-runs/`
- **THEN** phase is `proposed`

#### Scenario: Explore-only triggers exploring
- **WHEN** `openspec/explore/<name>/explore.md` exists and `openspec/changes/<name>/` does not exist
- **THEN** phase is `exploring`

#### Scenario: Mid-promotion — both explore.md and changes/<name>/ exist
- **WHEN** both `openspec/explore/<name>/explore.md` and `openspec/changes/<name>/proposal.md` exist (e.g., immediately after `/opsx:propose` populates the change directory)
- **THEN** phase is inferred from the change directory (rules 1–4 evaluate against its artifacts); rule 5's "no change directory" condition fails, so phase is not `exploring`

### Requirement: Attention is a typed structured array

Each change record SHALL carry an `attention` field whose value is an array of objects. Each object MUST include a `type` field whose value is from a closed enum and a `location` field identifying the artifact path the attention signal originates from.

The closed enum of `type` values is: `unresolved_marker`, `stale_review`, `task_blocked`, `audit_divergence`.

Per-type field requirements:

- `unresolved_marker`: `location`, `text` (the marker text itself)
- `stale_review`: `location`, `since` (timestamp of the artifact modification)
- `task_blocked`: `location` (the `tasks.md` line reference), `text` (the blocker note)
- `audit_divergence`: `location` (the audit JSON path), `count` (number of findings in the most recent `audit-drift-*.json` — v1 does NOT cross-reference against subsequent `address-reviews-*.json` runs; every finding in the audit JSON counts until a fresh audit-drift run replaces it. "Unresolved" here means "present in the latest audit," not "absent from any subsequent address-reviews resolution log")

#### Scenario: Unresolved marker emits an attention entry
- **WHEN** a change's `design.md` contains the text `@review: validation order doesn't match contract in §3`
- **THEN** the change's `attention` array contains an entry with `type: "unresolved_marker"`, `location: "design.md"`, and `text` matching the marker line

#### Scenario: Stale review emits an attention entry
- **WHEN** the change's `design.md` mtime is newer than the most recent `.orbit-runs/review-*.json` mtime
- **THEN** the change's `attention` array contains an entry with `type: "stale_review"`, `location: "design.md"`, and `since` set to the design.md mtime

#### Scenario: Closed enum cannot be extended at runtime
- **WHEN** orbit-status encounters a state it cannot classify into one of the four `type` values
- **THEN** orbit-status MUST NOT invent a new `type` value; the state is either omitted from `attention` or surfaced under an existing type
