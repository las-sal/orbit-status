## ADDED Requirements

### Requirement: Three-tier recommendation hierarchy

orbit-status SHALL populate `focus.recommended_next` using a three-tier source hierarchy, with the first applicable tier winning:

- **Tier 1**: For the focal change, read the `next_recommended` field from the most recent `.orbit-runs/*.json`. The string is surfaced verbatim — orbit-status MUST NOT paraphrase or summarize it.
- **Tier 2**: When no `.orbit-runs/` exists for the focal change, synthesize a recommendation from artifact presence using the documented Tier-2 ruleset.
- **Tier 3**: When no active or exploring threads exist project-wide, emit the literal string `"No active workflow. Use /opsx:explore to start one."` as the recommendation.

The `recommended_next` object MUST include `command`, `args`, and `reason` fields. With `--detail`, it MUST also include a `source` field identifying the originating tier and (for tier 1) the JSON file path.

#### Scenario: Tier-1 surfaces orbit's recommendation verbatim
- **WHEN** the focal change has `.orbit-runs/address-reviews-<ts>.json` as its most recent file, with `next_recommended: "Continue applying tasks (4 of 7). Re-review when chunk complete."`
- **THEN** `focus.recommended_next.reason` contains the exact string `"Continue applying tasks (4 of 7). Re-review when chunk complete."` with no paraphrasing

#### Scenario: Tier-3 fires for empty project
- **WHEN** orbit-status runs against a project with `openspec/` but no active or exploring threads
- **THEN** `focus.recommended_next.command` is `/opsx:explore` and `focus.summary` includes the text `"No active workflow"`

### Requirement: Tier-2 synthesis ruleset

When tier 2 fires for a focal change, orbit-status SHALL apply the following rules in precedence order — first match wins:

1. Only `explore.md` exists in `openspec/explore/<name>/` (no change directory) → `/opsx:propose <name>`
2. `proposal.md` exists in `openspec/changes/<name>/`, `tasks.md` is absent → `/opsx:propose <name>` (continue artifact generation)
3. `tasks.md` exists with all checkboxes unchecked, no review JSON → `/opsx:review <name>`
4. `tasks.md` exists with partial completion, no review JSON newer than the most recent `tasks.md` mtime (file modification time) → `/opsx:apply <name>`
5. Review JSON exists, unresolved `@review:` markers in the change's artifacts → `/opsx:address-reviews <name>`

#### Scenario: Only explore.md triggers /opsx:propose
- **WHEN** the focal change has `openspec/explore/<name>/explore.md` and no `openspec/changes/<name>/` directory
- **THEN** `focus.recommended_next.command` is `/opsx:propose` and `args` is the change name

#### Scenario: Partial tasks without review triggers /opsx:apply
- **WHEN** the focal change has `tasks.md` with some `[x]` and some `[ ]` and no `.orbit-runs/review-*.json`
- **THEN** `focus.recommended_next.command` is `/opsx:apply`

### Requirement: Multi-change focus ranking

When more than one active + exploring thread exists, orbit-status SHALL pick `focus.primary_change` by `last_touched` mtime in descending order — most recently touched wins.

The `--change <name>` flag MUST override this ranking, setting `focus.ranking_basis` to `"user_specified"`.

Ranking SHALL merge across the `active` and `exploring` buckets. An exploration thread can be primary if it is more recently touched than any active change.

#### Scenario: Most recently touched active change wins
- **WHEN** the project has two active changes, `add-detail-flag` (touched 2 hours ago) and `add-json-output` (touched 6 hours ago)
- **THEN** `focus.primary_change` is `"add-detail-flag"` and `focus.ranking_basis` is `"most_recently_touched"`

#### Scenario: --change overrides mtime ranking
- **WHEN** orbit-status runs with `--change add-json-output` in the same project
- **THEN** `focus.primary_change` is `"add-json-output"` and `focus.ranking_basis` is `"user_specified"`

#### Scenario: Exploration can outrank active changes
- **WHEN** an exploration directory `openspec/explore/<name>/` has a more recent mtime than any active change directory
- **THEN** `focus.primary_change` is that exploration's name and `focus.primary_change_kind` is `"exploring"`

### Requirement: Focus block field shape

The `focus` block SHALL include the following fields whenever at least one thread is active or exploring:

- `summary`: a one-sentence rendering of the primary change's state
- `primary_change`: the name of the focal thread
- `primary_change_kind`: `"active"` or `"exploring"`
- `ranking_basis`: `"most_recently_touched"` or `"user_specified"`
- `recommended_next`: the structured recommendation object (per Requirement: Three-tier recommendation hierarchy)
- `secondary_threads`: an array of non-primary threads, each with `name`, `kind` (`"active"` or `"exploring"`), `phase`, and `summary` fields

When no threads are active or exploring (i.e., tier 3 applies), `primary_change`, `primary_change_kind`, `ranking_basis`, and `secondary_threads` MAY be omitted; `summary` and `recommended_next` remain required.

#### Scenario: Focus block fully populated for multi-thread project
- **WHEN** orbit-status runs against a project with three threads (two active, one exploring)
- **THEN** `focus.secondary_threads` contains exactly two entries (the non-primary threads), each with all four fields

#### Scenario: Focus block minimal for empty project
- **WHEN** orbit-status runs against a project with no active or exploring threads
- **THEN** `focus` contains `summary` and `recommended_next` only; `primary_change` and related fields are absent or null
