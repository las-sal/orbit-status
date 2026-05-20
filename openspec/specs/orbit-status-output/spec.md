# orbit-status-output Specification

## Purpose
TBD - created by archiving change bootstrap-orbit-status-cli. Update Purpose after archive.
## Requirements
### Requirement: Default human-readable status view

The `orbit-status` binary SHALL emit a default human-readable status view to stdout when invoked with no flags. The view is designed to fit approximately 24 terminal lines for typical projects (≤3 active threads + ≤5 recent archives). It MAY exceed this when many threads are active; orbit-status MUST NOT truncate output to enforce a hard line limit.

The default view MUST include:

- Project path and an `(orbit project)` tag when `project.is_orbit_project` is true
- A "you are here" sentence naming the primary change and its phase
- A summary line for the primary change covering task progress, attention counts, and last-touched relative time
- A `Next:` recommendation derived from the three-tier recommendation hierarchy
- Optional sections: "Other active" (secondary threads, one line each) and "Recently archived" (capped at 5 entries)

#### Scenario: Project with one active change in applying phase
- **WHEN** orbit-status runs in a project with one active change in `applying` phase
- **THEN** stdout includes the project header line, a "You are applying <name>" sentence, a single summary line for that change, and a `Next:` recommendation

#### Scenario: Project with no active changes
- **WHEN** orbit-status runs in a project with no active or exploring changes
- **THEN** stdout includes the project header line and the sentence "No active workflow. Use /opsx:explore to start one."

### Requirement: --json flag emits structured output

The `--json` flag SHALL emit a JSON document conforming to the documented schema to stdout, with no human-formatted text.

The top-level keys MUST include `project`, `focus`, `active`, `exploring`, `recent`, and `totals` — all six present in every emission.

#### Scenario: JSON output has all top-level keys
- **WHEN** orbit-status runs with `--json` in any project state
- **THEN** the output is valid JSON and contains all six top-level keys `project`, `focus`, `active`, `exploring`, `recent`, `totals`

### Requirement: --detail flag expands per-change rendering

The `--detail` flag SHALL include additional per-change fields in both human-readable and JSON output.

By default (no `--detail`), `ChangeRecord.review_history` SHALL emit two summary fields: `iterations_total` (count of all `review-*` and `address-reviews-*` JSONs in the change's `.orbit-runs/`) and `findings_resolved` (sum of `resolution_summary.resolved` across all `address-reviews-*` JSONs in the change's `.orbit-runs/`).

`--detail` MUST add: the full review-history breakdown by mode (proposal-internal/external, system-internal/external, per-mode address-reviews counts), full `text` for each attention entry, the `source` field inside `recommended_next`, and the `next_unchecked` task description inside `tasks`.

#### Scenario: --detail expands review history
- **WHEN** orbit-status runs with `--detail` against a change whose review history has multiple iterations
- **THEN** the output includes the per-mode counter breakdown that the default view omits

### Requirement: --change flag pins focus to a specific thread

The `--change <name>` flag SHALL set `focus.primary_change` to the named change and `focus.ranking_basis` to `"user_specified"`, overriding the default most-recently-touched ranking.

If the named change is not present as an active or exploring thread, orbit-status MUST exit with a non-zero status code and emit an error to stderr naming the missing change.

#### Scenario: --change pins focus to non-primary thread
- **WHEN** orbit-status runs with `--change add-json-output` in a project where `add-detail-flag` would otherwise be primary by mtime
- **THEN** `focus.primary_change` is `"add-json-output"` and `focus.ranking_basis` is `"user_specified"`

#### Scenario: --change on missing thread fails
- **WHEN** orbit-status runs with `--change does-not-exist` in a project that has no such change
- **THEN** orbit-status exits non-zero and stderr names the missing change

### Requirement: --limit flag caps recent[] length

The `--limit N` flag SHALL cap the number of entries in the `recent[]` array (archived changes) at `N`. The default cap when `--limit` is not provided is 5. `N` MUST be a non-negative integer.

The `recent[]` entries are ordered by `archived_at` descending — the most recently archived first.

#### Scenario: Default cap of 5
- **WHEN** orbit-status runs in a project with 10 archived changes and no `--limit` flag
- **THEN** `recent[]` contains exactly 5 entries, ordered by `archived_at` descending

#### Scenario: Custom cap
- **WHEN** orbit-status runs with `--limit 2` in the same project
- **THEN** `recent[]` contains exactly 2 entries, the two most recently archived

#### Scenario: --limit 0 yields empty recent[]
- **WHEN** orbit-status runs with `--limit 0`
- **THEN** `recent[]` is an empty array (no archived changes surfaced); orbit-status exits zero

#### Scenario: --limit with negative argument fails
- **WHEN** orbit-status runs with `--limit -1` (or any negative integer)
- **THEN** orbit-status exits non-zero and stderr names the invalid argument

### Requirement: Error handling

orbit-status SHALL handle the three classes of runtime failure deterministically: missing project context (no `openspec/`), missing dependencies (`jq`), and corrupted orbit emissions (malformed `.orbit-runs/` JSONs).

#### Scenario: openspec/ not found
- **WHEN** orbit-status runs in a directory with no `openspec/` directory in cwd or any ancestor
- **THEN** orbit-status exits non-zero and stderr names the failure ("no openspec/ project found")

#### Scenario: jq missing
- **WHEN** `jq` is not on `PATH` at invocation
- **THEN** orbit-status exits non-zero with stderr install guidance (platform-appropriate install hint)

#### Scenario: malformed JSON in .orbit-runs/
- **WHEN** a `.orbit-runs/*.json` file fails to parse as JSON
- **THEN** orbit-status logs a warning to stderr naming the file and continues the run, treating that file's data as absent (does not fail the whole invocation)

### Requirement: archived_at field on archived ChangeRecords

Each `ChangeRecord` in the `recent[]` array SHALL include an `archived_at` field carrying an ISO-8601 timestamp of when the change was archived. The source SHALL be resolved in the following priority order — first available wins:

1. The `timestamp` field from a `.orbit-runs/archive-<TS>.json` file within the archived change directory (most precise; emitted by `/opsx:archive`).
2. The date parsed from the change's archived directory name (`openspec/changes/archive/<YYYY-MM-DD>-<name>/`) interpreted as `<YYYY-MM-DD>T00:00:00Z` (day precision; UTC midnight).
3. The archived directory's filesystem `mtime` as ISO-8601 (least reliable; final fallback).

#### Scenario: archive JSON timestamp wins when present
- **WHEN** an archived change has `.orbit-runs/archive-<TS>.json` inside the archived directory
- **THEN** `archived_at` is set to that JSON's `timestamp` field value

#### Scenario: dated directory name when archive JSON is absent
- **WHEN** an archived change has no `archive-*.json`, but its directory is named `openspec/changes/archive/<YYYY-MM-DD>-<name>/`
- **THEN** `archived_at` is set to `<YYYY-MM-DD>T00:00:00Z` (UTC midnight on that date)

#### Scenario: directory mtime as last resort
- **WHEN** neither an `archive-*.json` nor a parseable `<YYYY-MM-DD>-` prefix on the directory name is available
- **THEN** `archived_at` is set to the directory's mtime, formatted as ISO-8601

### Requirement: next_unchecked extraction rule

When `--detail` is set, `ChangeRecord.tasks.next_unchecked` SHALL be the description text of the first line in the change's `tasks.md` matching the regex `^- \[ \] [0-9]+\.[0-9]+ (.+)$` (i.e., an unchecked checkbox prefixed with an `N.M` task-number). Lines that don't match (malformed checkboxes, nested sub-bullets, free-form prose between groups) SHALL be skipped.

If no matching line exists in `tasks.md`, `next_unchecked` is null.

#### Scenario: next_unchecked is the first matching unchecked line
- **WHEN** `--detail` is set and `tasks.md` has lines `- [x] 1.1 Done thing`, `- [ ] 1.2 Pending thing`, `- [ ] 1.3 Later thing`
- **THEN** `tasks.next_unchecked` is `"Pending thing"`

#### Scenario: malformed lines are skipped
- **WHEN** `tasks.md` has `- [ ] Foo` (no `N.M` prefix), then `- [ ] 2.1 Real task`
- **THEN** `tasks.next_unchecked` is `"Real task"` (the unprefixed `Foo` is skipped)

