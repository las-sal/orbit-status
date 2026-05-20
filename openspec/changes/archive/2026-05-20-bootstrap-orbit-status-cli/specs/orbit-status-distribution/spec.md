## ADDED Requirements

### Requirement: Binary install location

The orbit-status binary SHALL be installed at `.claude/skills/openspec-status/bin/opsx-status` within an orbit-overlay-installed project.

The `/opsx:status` slash command MUST shell out to this binary using a path relative to its own skill directory.

#### Scenario: Binary present after overlay install
- **WHEN** the orbit overlay is installed at a project's `.claude/`
- **THEN** the file `.claude/skills/openspec-status/bin/opsx-status` exists and is marked executable

### Requirement: is_orbit_project detection

`project.is_orbit_project` SHALL be set to `true` when either of the following holds:

1. Any directory under `openspec/changes/` (active or under `archive/`) contains a `.orbit-runs/` subdirectory.
2. The path `.claude/skills/openspec-review/` exists (the orbit overlay marker).

Otherwise, `project.is_orbit_project` is `false`.

#### Scenario: Plain openspec project
- **WHEN** orbit-status runs against a project that has `openspec/` but no `.orbit-runs/` subdirectories anywhere under `openspec/changes/`, and no `.claude/skills/openspec-review/`
- **THEN** `project.is_orbit_project` is `false`

#### Scenario: Orbit project with overlay but no review runs yet
- **WHEN** orbit-status runs against a fresh project where the orbit overlay is installed (`.claude/skills/openspec-review/` exists) but no change has been reviewed yet (no `.orbit-runs/` anywhere)
- **THEN** `project.is_orbit_project` is `true`

#### Scenario: Orbit project with review runs
- **WHEN** orbit-status runs against a project where at least one change directory contains a `.orbit-runs/` subdirectory
- **THEN** `project.is_orbit_project` is `true`

### Requirement: Graceful degradation on plain-openspec projects

When `project.is_orbit_project` is `false`, orbit-status SHALL omit the following orbit-specific keys from its JSON output:

- `review_history` is omitted from each `ChangeRecord`
- Attention entries of type `audit_divergence` are not emitted (no audit JSONs to read)
- The `source` field inside `recommended_next` is omitted (tier 1 is unreachable)
- The human-readable view omits the `(orbit project)` tag from the project header and the per-change review-history summary line

Attention types `unresolved_marker` and `stale_review` (which depend only on artifact filesystem state, not on orbit's emissions) SHALL continue to emit on plain-openspec projects.

#### Scenario: Plain-openspec JSON omits review_history
- **WHEN** orbit-status runs with `--json` against a project where `is_orbit_project` is `false`, with at least one active change
- **THEN** no `ChangeRecord` in `active[]`, `exploring[]`, or `recent[]` contains a `review_history` field

#### Scenario: Plain-openspec human view omits orbit tag
- **WHEN** orbit-status runs without flags against a project where `is_orbit_project` is `false`
- **THEN** the project header line shows the path without the `(orbit project)` suffix

#### Scenario: Unresolved markers still emit on plain-openspec
- **WHEN** orbit-status runs against a plain-openspec project whose `design.md` contains `@review: validation order doesn't match contract`
- **THEN** the change's `attention` array contains an entry with `type: "unresolved_marker"`

### Requirement: Four-surface naming

The orbit-status feature SHALL be present on four named surfaces, each following its own naming convention:

- Project repository: `orbit-status`
- Skill directory: `.claude/skills/openspec-status/`
- Slash command: `/opsx:status` (file at `.claude/commands/opsx/status.md`)
- Binary: `opsx-status` (at `.claude/skills/openspec-status/bin/opsx-status`)

The skill directory uses the `openspec-` prefix for consistency with other orbit skills (`openspec-review`, `openspec-explore`, etc.). The binary uses the `opsx-` prefix to match the `/opsx:` slash-command namespace. The project repository uses `orbit-` as a sibling to `openspec-orbit`.

#### Scenario: Overlay contains all four surfaces
- **WHEN** an orbit overlay version is built that includes orbit-status
- **THEN** the overlay contains all of: `.claude/skills/openspec-status/SKILL.md`, `.claude/commands/opsx/status.md`, and an executable at `.claude/skills/openspec-status/bin/opsx-status`
