The 18 task groups below break naturally into 5 implementation chunks. `/opsx:apply` can pause at chunk boundaries for review:

1. **Scaffold + project detection** — groups 1–3 (skill dirs, CLI binary skeleton + arg parsing, `is_orbit_project` detection)
2. **Inventory + parsing** — groups 4–6 (filesystem walk of changes/explorations/archive, `tasks.md` checkbox parsing, JSON ingestion from `.orbit-runs/`)
3. **Phase + attention + recommendation engine** — groups 7–10 (phase inference precedence, attention signal detection, 3-tier recommendation hierarchy, multi-change focus ranking)
4. **Output + degradation** — groups 11–13 (JSON emission, human-readable rendering, plain-openspec graceful degradation)
5. **Integration + docs + validation** — groups 14–18 (slash command wrapper, skill documentation, bats/shell tests, README, manual validation against real projects)

## 1. Skill scaffolding

- [x] 1.1 Create `.claude/skills/openspec-status/` directory
- [x] 1.2 Write `.claude/skills/openspec-status/SKILL.md` with frontmatter (name, description, license, metadata) and surface description
- [x] 1.3 Create `.claude/skills/openspec-status/bin/` directory
- [x] 1.4 Create `.claude/commands/opsx/status.md` with slash command body

## 2. CLI binary scaffolding

- [x] 2.1 Create `bin/opsx-status` executable bash script (shebang + `set -euo pipefail`)
- [x] 2.2 Implement `--help` output documenting flags and JSON schema
- [x] 2.3 Argument parsing: `--detail`, `--json`, `--change <name>`, `--limit N`
- [x] 2.4 Locate the project root by walking up from cwd looking for `openspec/`
- [x] 2.5 Verify `jq` is available; emit a clear error to stderr and exit non-zero if missing

## 3. Project detection (`is_orbit_project`)

- [x] 3.1 Implement `is_orbit_project` detection (overlay marker `.claude/skills/openspec-review/` OR any `.orbit-runs/` under `openspec/changes/`)
- [x] 3.2 Emit `project` block with `path`, `name` (basename of project root), `is_orbit_project`

## 4. Filesystem walk: changes inventory

- [x] 4.1 Enumerate active changes under `openspec/changes/` (excluding `archive/`)
- [x] 4.2 Enumerate explorations under `openspec/explore/`
- [x] 4.3 Enumerate archived changes under `openspec/changes/archive/`
- [x] 4.4 For each change/exploration, collect `artifacts_present` list (proposal, design, tasks, specs, explore, sketches) and `last_touched` mtime
- [x] 4.5 For each archived change in `recent[]`, compute `archived_at` per the 3-tier priority: (1) `timestamp` field from any `.orbit-runs/archive-<TS>.json`; (2) parse `<YYYY-MM-DD>-` prefix from the archived directory name, interpret as UTC midnight; (3) directory mtime as last resort. Emit as ISO-8601.

## 5. `tasks.md` parsing

- [x] 5.1 Count `[x]` and `[ ]` checkboxes per change's `tasks.md`
- [x] 5.2 Extract the first unchecked task description as `next_unchecked` (surfaced under `--detail`)

## 6. JSON ingestion from `.orbit-runs/`

- [x] 6.1 List `.orbit-runs/*.json` per change and sort by embedded timestamp
- [x] 6.2 Identify most recent JSON's command type (review, address-reviews, audit-drift, archive)
- [x] 6.3 Extract `iteration`, `findings_summary`, `next_recommended`, `final_assessment` from the most recent JSON (helpers in place; consumed in chunk 3 by the recommendation engine + phase inference)
- [x] 6.4 Sum review and address-reviews counters across all JSONs for `iterations_total` and `findings_resolved` (default view)
- [x] 6.5 Build per-mode breakdown counters (proposal-internal/external, system-internal/external, address-reviews-proposal/system) for `--detail` (helpers in place; full breakdown emitted under `--detail` in chunk 3)
- [x] 6.6 Handle JSON parse failures gracefully: when `jq` fails to parse a `.orbit-runs/*.json` file, log a warning to stderr naming the file, treat that file's data as absent, and continue the run (do not fail the whole invocation; satisfies the Error handling requirement in `orbit-status-output` spec)

## 7. Phase inference

- [x] 7.1 Implement precedence rule 1: under `openspec/changes/archive/` → `archived`
- [x] 7.2 Implement rule 2: most recent `.orbit-runs/*.json` command type → `reviewing` (review/address-reviews) or `archived` (archive), **provided the JSON's filename timestamp is newer than `tasks.md` mtime**; if not, fall through to rule 3
- [x] 7.3 Implement rule 3: `tasks.md` with partial completion (some `[x]`, some `[ ]`) → `applying`
- [x] 7.4 Implement rule 4: `proposal.md` exists, no completed tasks → `proposed`
- [x] 7.5 Implement rule 5: only `explore.md` exists in `openspec/explore/<name>/` → `exploring`

## 8. Attention signal detection

- [x] 8.1 Scan artifacts for `@review:` markers; emit `unresolved_marker` entries with `location` and `text`
- [x] 8.2 Compare artifact mtimes against the latest review JSON mtime; emit `stale_review` entries with `location` and `since`
- [x] 8.3 Parse `.orbit-runs/audit-drift-*.json` for unresolved findings; emit `audit_divergence` entries with `location` and `count`
- [x] 8.4 (Deferred to v2 — no `task_blocked` convention exists upstream yet; leave the enum slot defined in spec but emit nothing) — code comment in `collect_attention()` documents the NOOP per spec

## 9. Recommendation engine

- [x] 9.1 Tier 1: surface `next_recommended` from most recent change JSON; preserve full string verbatim in `reason`; best-effort parse for leading `/opsx:<verb> [args]` token to populate `command`/`args` (null on failure)
- [x] 9.1a Tier 1 marker override: when unresolved `@review:` markers exist in the change's artifacts (i.e., `attention[]` contains `unresolved_marker` entries), override the JSON's recommendation to `{ command: "/opsx:address-reviews", args: "<change-name>", reason: "<N> unresolved @review: markers..." }`
- [x] 9.2 Tier 2: implement synthesis ruleset (4 precedence-ordered rules from spec; the 5th marker-handling rule was moved to tier 1's override per the iter-2 address-reviews resolution)
- [x] 9.3 Tier 3: project-level fallback `"No active workflow. Use /opsx:explore to start one."`
- [x] 9.4 Assemble `recommended_next` object: `command`, `args`, `reason`
- [x] 9.5 With `--detail`, add `source` field (tier 1 JSON path or tier 2 rule name)

## 10. Multi-change focus ranking

- [x] 10.1 Rank active + exploring threads by `last_touched` mtime descending; on equal mtimes, tie-break by lexicographic order of change name (ascending) for full determinism
- [x] 10.2 Pick `primary_change` from the top of the ranking; set `primary_change_kind` to `"active"` or `"exploring"`
- [x] 10.3 Build `secondary_threads[]` with `name`, `kind`, `phase`, `summary` for each non-primary thread
- [x] 10.4 Honor `--change <name>`: override `primary_change`; set `ranking_basis` to `"user_specified"`
- [x] 10.5 Validate `--change` argument names an existing thread; exit non-zero with stderr error if not

## 11. JSON output (`--json`)

- [x] 11.1 Assemble top-level keys: `project`, `focus`, `active`, `exploring`, `recent`, `totals`
- [x] 11.2 Cap `recent[]` at `--limit N` (default 5), ordered by `archived_at` descending
- [x] 11.3 Emit valid JSON to stdout via `jq` for formatting
- [x] 11.4 Suppress all human-formatted text when `--json` is set

## 12. Human-readable rendering

- [x] 12.1 Render project header line with optional `(orbit project)` tag
- [x] 12.2 Render focus block: phase-aware summary sentence + primary state line (tasks · attention); under `--detail` adds `next:` task, expanded `attention:` block, and `review history:` breakdown
- [x] 12.3 Render `Next:` line with `command args` plus a quoted `reason`; `(source: ...)` under `--detail` on orbit projects
- [x] 12.4 Render "Other active" section (one line per secondary thread)
- [x] 12.5 Render "Recently archived" section (one line per archive, capped)
- [x] 12.6 Handle no-active-work case: emit project header + "No active workflow. Use /opsx:explore to start one."

## 13. Plain-openspec graceful degradation

- [x] 13.1 When `is_orbit_project: false`, omit `review_history` from every `ChangeRecord` (jq `del(.review_history)` after construction)
- [x] 13.2 When `is_orbit_project: false`, suppress `audit_divergence` attention type (`collect_attention` already gates on `IS_ORBIT_PROJECT`)
- [x] 13.3 When `is_orbit_project: false`, omit `source` from `recommended_next` (the `--detail` branch in `compute_recommended_next` checks both `$DETAIL && [[ IS_ORBIT_PROJECT == true ]]`)
- [x] 13.4 When `is_orbit_project: false`, drop the `(orbit project)` tag (header-line emission already conditional) and skip the review-history block in `--detail` human view (block only renders when `review_history != null`, which is omitted on plain-openspec per 13.1)
- [x] 13.5 Verify `unresolved_marker` and `stale_review` still emit on plain-openspec — `collect_attention` only gates `audit_divergence` on `IS_ORBIT_PROJECT`; the other two attention types run unconditionally (stale_review needs a review JSON baseline which doesn't exist on plain-openspec, so it vacuously emits nothing — correct behavior)

## 14. Slash command (`/opsx:status`)

- [x] 14.1 Write `.claude/commands/opsx/status.md` body (orbit-style frontmatter + content)
- [x] 14.2 Shell out to `opsx-status --json` from a path relative to the skill directory
- [x] 14.3 Document interpretation rules: surface focus + attention + next-steps with conversational context

## 15. Skill documentation

- [x] 15.1 Document flag surface (`--detail`, `--json`, `--change`, `--limit`) in `SKILL.md`
- [x] 15.2 Document the JSON schema shape (top-level keys + `ChangeRecord` fields) in `SKILL.md`
- [x] 15.3 Document interpretation guidance for the slash command (when to expand attention, how to surface tier-2 vs tier-1 recommendations)

## 16. Tests

- [x] 16.1 Create test fixtures: ephemeral fixture builders in `tests/run.sh` produce `empty-orbit`, `plain-openspec`, `exploring-only`, `mid-apply`, `with-archive`, `with-marker` under `mktemp` per run
- [x] 16.2 Bats or shell-based test: key scenarios in `specs/orbit-status-output/spec.md` (10 tests covering --json shape, --limit edge cases, --change override + error, --help/--version, no-openspec error path)
- [x] 16.3 Bats or shell-based test: key scenarios in `specs/orbit-status-phase-model/spec.md` (5 tests covering rules 3/4/5/archive + closed enum + unresolved marker emission)
- [x] 16.4 Bats or shell-based test: key scenarios in `specs/orbit-status-recommendation/spec.md` (6 tests covering tier-1 marker override, tier-2 rules 1+4, tier-3 fallback, focus block fields)
- [x] 16.5 Bats or shell-based test: key scenarios in `specs/orbit-status-distribution/spec.md` (8 tests covering is_orbit_project detection both directions, plain-openspec field omissions, four-surface presence)
- [x] 16.6 Schema-validation test: `--json` output validates against the documented schema (42 assertions across 6 fixture shapes: 6 top-level keys + array typing + totals number typing)

## 17. Project documentation

- [x] 17.1 Update top-level `README.md`: what orbit-status is, what problem it solves, the JSON-first contract
- [x] 17.2 Document install path (assumes `openspec-orbit#6` overlay-scope fix is merged): `openspec init` → `openspec config profile` → `openspec update` → overlay orbit
- [x] 17.3 Document `jq` dependency with install instructions per platform
- [x] 17.4 Document the three example invocations (State A archived, State B mid-explore, State C mid-apply) with sample output

## 18. Manual validation (deferred — user-driven)

- [x] 18.1 Run `opsx-status` against `~/code/openspec-review/` and verify output matches State A from explore.md (archived bootstrap surfaced; `No active workflow` recommendation) — **VERIFIED 2026-05-20**: output exactly matches State A: `No active workflow. Use /opsx:explore to start one.` + `Recently archived: 1 total — bootstrap-openspec-orbit · archived 2026-05-18`
- [x] 18.2 Run against `~/code/orbit-status/` itself — historical State B (mid-explore) no longer applies since the project has progressed through propose/apply/review; the binary correctly reflects the current reviewing-phase state with primary_change populated, `most_recently_touched` ranking, 1 stale_review attention, and a tier-1-sourced recommendation. Spec adherence verified end-to-end against real project data.
- [x] 18.3 Run against a plain-openspec project (used `~/code/OpenSpec/` — upstream openspec source with 10 active + 77 archived) and verify graceful degradation — **VERIFIED 2026-05-20**: `is_orbit_project: false`; `(orbit project)` tag dropped; `review_history` absent from every ChangeRecord; `source` absent from `recommended_next` even under `--detail`; multi-thread ranking + tier-2 synthesis + recent[] archive listing all work at scale.
- [x] 18.4 Verified two ways: (a) real-data tier-1 sourcing from orbit-status's own `.orbit-runs/` shows source = `tier-1 (.orbit-runs/address-reviews-2026-05-20T16-17-15Z.json)` with verbatim reason from the actual JSON's `next_recommended` field; review_history breakdown matches the real 10-iteration arc (3 proposal-internal + 1 proposal-external + 1 system-internal + 1 system-external + 2 address-reviews-proposal + 2 address-reviews-system). (b) synthetic mid-apply fixture at `/tmp/state-c-demo` verifies phase resolves to `applying` (rule 3, since the stale JSON's filename-ts is older than tasks.md mtime — W2 fix in action) and tier-1 still sources from the JSON's next_recommended (`/opsx:apply work` parsed cleanly).
