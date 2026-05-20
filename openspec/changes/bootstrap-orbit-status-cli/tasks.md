## 1. Skill scaffolding

- [ ] 1.1 Create `.claude/skills/openspec-status/` directory
- [ ] 1.2 Write `.claude/skills/openspec-status/SKILL.md` with frontmatter (name, description, license, metadata) and surface description
- [ ] 1.3 Create `.claude/skills/openspec-status/bin/` directory
- [ ] 1.4 Create `.claude/commands/opsx/status.md` with slash command body

## 2. CLI binary scaffolding

- [ ] 2.1 Create `bin/opsx-status` executable bash script (shebang + `set -euo pipefail`)
- [ ] 2.2 Implement `--help` output documenting flags and JSON schema
- [ ] 2.3 Argument parsing: `--detail`, `--json`, `--change <name>`, `--limit N`
- [ ] 2.4 Locate the project root by walking up from cwd looking for `openspec/`
- [ ] 2.5 Verify `jq` is available; emit a clear error to stderr and exit non-zero if missing

## 3. Project detection (`is_orbit_project`)

- [ ] 3.1 Implement `is_orbit_project` detection (overlay marker `.claude/skills/openspec-review/` OR any `.orbit-runs/` under `openspec/changes/`)
- [ ] 3.2 Emit `project` block with `path`, `name` (basename of project root), `is_orbit_project`

## 4. Filesystem walk: changes inventory

- [ ] 4.1 Enumerate active changes under `openspec/changes/` (excluding `archive/`)
- [ ] 4.2 Enumerate explorations under `openspec/explore/`
- [ ] 4.3 Enumerate archived changes under `openspec/changes/archive/`
- [ ] 4.4 For each change/exploration, collect `artifacts_present` list (proposal, design, tasks, specs, explore, sketches) and `last_touched` mtime

## 5. `tasks.md` parsing

- [ ] 5.1 Count `[x]` and `[ ]` checkboxes per change's `tasks.md`
- [ ] 5.2 Extract the first unchecked task description as `next_unchecked` (surfaced under `--detail`)

## 6. JSON ingestion from `.orbit-runs/`

- [ ] 6.1 List `.orbit-runs/*.json` per change and sort by embedded timestamp
- [ ] 6.2 Identify most recent JSON's command type (review, address-reviews, audit-drift, archive)
- [ ] 6.3 Extract `iteration`, `findings_summary`, `next_recommended`, `final_assessment` from the most recent JSON
- [ ] 6.4 Sum review and address-reviews counters across all JSONs for `iterations_total` and `findings_resolved` (default view)
- [ ] 6.5 Build per-mode breakdown counters (proposal-internal/external, system-internal/external, address-reviews-proposal/system) for `--detail`

## 7. Phase inference

- [ ] 7.1 Implement precedence rule 1: under `openspec/changes/archive/` → `archived`
- [ ] 7.2 Implement rule 2: most recent `.orbit-runs/*.json` command type → `reviewing` (review/address-reviews) or `archived` (archive)
- [ ] 7.3 Implement rule 3: `tasks.md` with partial completion (some `[x]`, some `[ ]`) → `applying`
- [ ] 7.4 Implement rule 4: `proposal.md` exists, no completed tasks → `proposed`
- [ ] 7.5 Implement rule 5: only `explore.md` exists in `openspec/explore/<name>/` → `exploring`

## 8. Attention signal detection

- [ ] 8.1 Scan artifacts for `@review:` markers; emit `unresolved_marker` entries with `location` and `text`
- [ ] 8.2 Compare artifact mtimes against the latest review JSON mtime; emit `stale_review` entries with `location` and `since`
- [ ] 8.3 Parse `.orbit-runs/audit-drift-*.json` for unresolved findings; emit `audit_divergence` entries with `location` and `count`
- [ ] 8.4 (Deferred to v2 — no `task_blocked` convention exists upstream yet; leave the enum slot defined in spec but emit nothing)

## 9. Recommendation engine

- [ ] 9.1 Tier 1: surface `next_recommended` from most recent change JSON verbatim
- [ ] 9.2 Tier 2: implement synthesis ruleset (5 precedence-ordered rules from spec)
- [ ] 9.3 Tier 3: project-level fallback `"No active workflow. Use /opsx:explore to start one."`
- [ ] 9.4 Assemble `recommended_next` object: `command`, `args`, `reason`
- [ ] 9.5 With `--detail`, add `source` field (tier 1 JSON path or tier 2 rule name)

## 10. Multi-change focus ranking

- [ ] 10.1 Rank active + exploring threads by `last_touched` mtime descending
- [ ] 10.2 Pick `primary_change` from the top of the ranking; set `primary_change_kind` to `"active"` or `"exploring"`
- [ ] 10.3 Build `secondary_threads[]` with `name`, `kind`, `phase`, `summary` for each non-primary thread
- [ ] 10.4 Honor `--change <name>`: override `primary_change`; set `ranking_basis` to `"user_specified"`
- [ ] 10.5 Validate `--change` argument names an existing thread; exit non-zero with stderr error if not

## 11. JSON output (`--json`)

- [ ] 11.1 Assemble top-level keys: `project`, `focus`, `active`, `exploring`, `recent`, `totals`
- [ ] 11.2 Cap `recent[]` at `--limit N` (default 5), ordered by `archived_at` descending
- [ ] 11.3 Emit valid JSON to stdout via `jq` for formatting
- [ ] 11.4 Suppress all human-formatted text when `--json` is set

## 12. Human-readable rendering

- [ ] 12.1 Render project header line with optional `(orbit project)` tag
- [ ] 12.2 Render focus block: "You are <phase>-ing <name>" sentence + summary line (tasks, attention counts, last-touched)
- [ ] 12.3 Render `Next:` line with `command args` plus a quoted `reason`
- [ ] 12.4 Render "Other active" section (one line per secondary thread)
- [ ] 12.5 Render "Recently archived" section (one line per archive, capped)
- [ ] 12.6 Handle no-active-work case: emit project header + "No active workflow. Use /opsx:explore to start one."

## 13. Plain-openspec graceful degradation

- [ ] 13.1 When `is_orbit_project: false`, omit `review_history` from every `ChangeRecord`
- [ ] 13.2 When `is_orbit_project: false`, suppress `audit_divergence` attention type
- [ ] 13.3 When `is_orbit_project: false`, omit `source` from `recommended_next`
- [ ] 13.4 When `is_orbit_project: false`, drop the `(orbit project)` tag and per-change review-history line from human view
- [ ] 13.5 Verify `unresolved_marker` and `stale_review` still emit on plain-openspec

## 14. Slash command (`/opsx:status`)

- [ ] 14.1 Write `.claude/commands/opsx/status.md` body (orbit-style frontmatter + content)
- [ ] 14.2 Shell out to `opsx-status --json` from a path relative to the skill directory
- [ ] 14.3 Document interpretation rules: surface focus + attention + next-steps with conversational context

## 15. Skill documentation

- [ ] 15.1 Document flag surface (`--detail`, `--json`, `--change`, `--limit`) in `SKILL.md`
- [ ] 15.2 Document the JSON schema shape (top-level keys + `ChangeRecord` fields) in `SKILL.md`
- [ ] 15.3 Document interpretation guidance for the slash command (when to expand attention, how to surface tier-2 vs tier-1 recommendations)

## 16. Tests

- [ ] 16.1 Create test fixtures: an archived-bootstrap-like change, a mid-apply change, a plain-openspec project, an exploration-only directory
- [ ] 16.2 Bats or shell-based test: each scenario in `specs/orbit-status-output/spec.md`
- [ ] 16.3 Bats or shell-based test: each scenario in `specs/orbit-status-phase-model/spec.md`
- [ ] 16.4 Bats or shell-based test: each scenario in `specs/orbit-status-recommendation/spec.md`
- [ ] 16.5 Bats or shell-based test: each scenario in `specs/orbit-status-distribution/spec.md`
- [ ] 16.6 Schema-validation test: `--json` output validates against the documented schema

## 17. Project documentation

- [ ] 17.1 Update top-level `README.md`: what orbit-status is, what problem it solves, the JSON-first contract
- [ ] 17.2 Document install path (assumes `openspec-orbit#6` overlay-scope fix is merged): `openspec init` → `openspec config profile` → `openspec update` → overlay orbit
- [ ] 17.3 Document `jq` dependency with install instructions per platform
- [ ] 17.4 Document the three example invocations (State A archived, State B mid-explore, State C mid-apply) with sample output

## 18. Manual validation (deferred — user-driven)

- [ ] 18.1 Run `opsx-status` against `~/code/openspec-review/` and verify output matches State A from explore.md (archived bootstrap surfaced; `No active workflow` recommendation)
- [ ] 18.2 Run against `~/code/orbit-status/` itself and verify State B (exploring view of `bootstrap-orbit-status-cli`)
- [ ] 18.3 Run against a plain-openspec project (any `~/code/OpenSpec/`-style tree without orbit overlay) and verify graceful degradation
- [ ] 18.4 Construct a real mid-apply scenario in a sandbox and verify State C output (tier-1 recommendation surfaced from a real address-reviews JSON)
