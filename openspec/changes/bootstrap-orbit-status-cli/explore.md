> **Status**: exploring. Promoted to proposal/design/specs via /opsx:propose when decisions firm up.

# Exploration: bootstrap-orbit-status-cli

## Premise

Design and bootstrap **orbit-status**, the first non-markdown executable orbit ships — a CLI that walks an `openspec/` tree (plus orbit's `.orbit-runs/` when present) and surfaces, in one screen: what's active, what phase each change is in, what needs attention.

orbit-status doubles as a real-world test of orbit's overlay-as-distribution model. Decisions about install, structure, and consumption inside `~/code/orbit-status/` validate orbit's "downstream consumer" story honestly (cf. `las-sal/openspec-orbit#6`).

Scope is intentionally narrow for v1: status read-only, no mutations. The CLI is the data-extraction layer; a slash command (`/opsx:status`) wraps it as the interpretation/recommendation layer.

## Decisions

- **2026-05-19** — **Separate repo, not a subfolder of openspec-orbit.** orbit-status lives at `~/code/orbit-status/` with its own git history and (eventually) GitHub remote. Rationale: testing the overlay-as-distribution model honestly requires consuming orbit as a downstream project would. Subfolder approach was considered and rejected — see Considered & out.

- **2026-05-19** — **CLI-first, implemented as a bash script.** Not a TypeScript/npm package. The CLI is the data layer; can fit in ~150–300 lines of bash for v1. Rationale: zero build/distribution overhead, runnable in CI, ~10ms latency. Future port to a real package is possible if adoption demands it; this is a known throwaway path that proves the design first.

- **2026-05-19** — **Slash command wraps the CLI, doesn't re-extract.** `/opsx:status` invokes `opsx-status --json` and interprets the output. Rationale: the two surfaces (CLI + slash command) can never drift because one delegates to the other; AI's value-add becomes interpretation and recommendation, not boring data work.

- **2026-05-19** — **Default output is a one-screen status view, with `--detail` and `--json` flags.** `--json` is the machine-readable contract; `--detail` expands per-change view; the default human view is the one-glance summary. Rationale: optimizes for the most common need (quick "where are we?") while preserving access to depth and automation.

- **2026-05-19** — **Project name is `orbit-status`, path is `~/code/orbit-status/`.** Binary name TBD (likely `orbit-status` or `opsx-status` — see Open questions). Rationale: matches the `/opsx:status` slash command surface; reads cleanly in shell; sibling to `~/code/openspec-orbit/` convention.

- **2026-05-19** — **orbit-status states where the developer is in the workflow.** Not just per-change state listing — a synthesized "you are here" indicator: what phase the developer is currently operating in, on which change(s), and what comes next. Rationale: state without orientation is just `openspec list` with extra fields. orbit-status's value over the upstream CLI is interpretation — telling the developer where they stand and what to do next. The CLI emits raw data via `--json` AND a rendered "you are here" view in the default human output; the slash command elaborates on the recommendation in chat.

- **2026-05-19** — **`focus.recommended_next` is a single recommended action, not a menu.** `--json` shape: `{ "command": "/opsx:<name>", "args": "<args>", "reason": "..." }`. Human view collapses to one line: "No active workflow. Use /opsx:explore to start one." For active work: "You are applying X — continue with /opsx:apply." Rationale: a single recommendation is decisive and lower-friction than a menu; the developer can always pick something else, but orbit-status taking a position is more useful than listing options.

- **2026-05-19** — **`review_history` defaults to summary; per-mode breakdown requires `--detail`.** Default surfaces `iterations_total` and `findings_resolved`; the 8-counter breakdown (proposal-internal, proposal-external, system-internal, system-external, plus per-mode address-reviews counts) only appears with `--detail`. Rationale: the summary numbers are what a glance needs; the full breakdown is forensic depth that clutters the default view.

- **2026-05-19** — **Source of truth is orbit's `.orbit-runs/*.json` files; filesystem walks only for things JSONs don't cover.** Per-run JSONs (`review-*`, `address-reviews-*`, `archive-*`) have structured fields: `iteration`, `findings_summary`, `final_assessment`, `next_recommended`. orbit-status reads these directly. Filesystem walks supplement for things orbit doesn't emit: artifact presence (proposal.md / design.md / etc.), `tasks.md` checkbox counts, `@review:` marker scans, and file mtimes. Rationale: orbit's JSONs are explicitly structured records of every command run; re-deriving from filesystem would duplicate orbit's already-cooked output. (The earlier "asymmetry between archived-read and active-compute" framing was wrong — both read JSONs, with archived having a bonus aggregator `archive-*.json`.)

- **2026-05-19** — **`recommended_next` has a three-tier source hierarchy; v1 includes a small artifact-presence synthesis layer for tier 2.**

  **Tier 1 (preferred — read from orbit)**: surface `next_recommended` from the most recent per-change JSON in `.orbit-runs/`. Applies whenever an editorial command has emitted (review, address-reviews, audit-drift, archive).

  **Tier 2 (synthesis — v1 only)**: when orbit hasn't emitted yet (e.g., explore.md exists but no review run; proposal.md exists but no review; tasks.md with unchecked work), synthesize a recommendation from artifact presence using a small deterministic ruleset (e.g., `explore.md only → /opsx:propose`, `proposal+design+tasks but no review → /opsx:review`, `tasks unchecked with review done → /opsx:apply`).

  **Tier 3 (project-level fallback)**: when no active work, "No active workflow. Use /opsx:explore to start one."

  Rationale: orbit's editorial commands emit structured `next_recommended` fields; workflow commands (`/opsx:explore`, `/opsx:propose`, `/opsx:apply`, `/opsx:verify`) currently don't. Tier 2 closes that gap for v1. Filed as `las-sal/openspec-orbit#8` to push tier-2 logic back into orbit — if orbit implements run-summary JSONs for workflow commands, the synthesis layer in orbit-status v1 can be deleted (pure tier-1 reads everywhere). (Resolves the earlier Open question about CLI vs slash-command recommendation logic — neither synthesizes load-bearingly; tier-2 is a v1 stopgap.)

- **2026-05-19** — **Phase enum: `exploring | proposed | applying | reviewing | verified | archived`.** Inference is precedence-ordered: (1) in `openspec/changes/archive/` → `archived`. (2) Latest `.orbit-runs/*.json` command determines phase when available: `review-*` or `address-reviews-*` → `reviewing`; `archive-*` → `archived` (pending file move). (3) `tasks.md` with partial completion (some `[x]`, some `[ ]`) → `applying`. (4) `proposal.md` exists but no `tasks.md` activity → `proposed`. (5) only `explore.md` in `openspec/explore/<name>/`, no change dir yet → `exploring`. (6) `verified` reserved for when `/opsx:verify` emits run-summary JSONs (cf. `las-sal/openspec-orbit#8`). Rationale: six clean states cover the orbit lifecycle without phase-explosion; precedence ordering avoids ambiguity when multiple signals are present.

- **2026-05-19** — **`attention` is a typed structured array per change.** Shape: `[{ type, location, text?, ... }, ...]`. Closed enum of types: `unresolved_marker` (an `@review:` in any artifact), `stale_review` (artifact modified after most recent review JSON), `task_blocked` (per-task narrative noting blocker), `audit_divergence` (audit-drift findings unresolved). Each type has expected fields — `location` always required; `text` for marker-type signals; `since`/`count` for time-based signals. Rationale: closed enum makes "needs attention" semantics introspectable and filterable; structured shape lets the slash command render contextual prose for each type. Extending the enum is an orbit-status code change, not a free-form text leak from artifacts.

- **2026-05-19** — **Top-level JSON schema: `project / focus / active / exploring / recent / totals`.** `project` carries `path`, `name`, `is_orbit_project` (graceful-degradation toggle). `focus` synthesizes the "you are here" view — `summary` (one-sentence) and `recommended_next` (the tier-1/2/3 hierarchy). `active` lists changes in `openspec/changes/<name>/` not yet archived. `exploring` lists pre-change explorations in `openspec/explore/<name>/`. `recent` lists archived changes (capped, e.g. last 5 by default; `--limit N` flag). `totals` carries counts for quick shell assertions. Rationale: separating phase-major buckets (active vs exploring vs recent) lets consumers iterate without filtering; `totals` lets scripts test for emptiness without parsing arrays.

- **2026-05-19** — **Multi-change focus ranking: most-recently-touched wins; `--change <name>` overrides.** When multiple active + exploring threads exist, orbit-status picks the focal point by `last_touched` mtime (descending). User can pin focus via `orbit-status --change <name>`, in which case `focus.ranking_basis: "user_specified"`. Rationale: most-recently-touched is deterministic, predictable, and matches the implicit "what I was doing last" mental model. Refinements (weight by phase, attention severity) add surprise; v1 doesn't need them. The `--change` flag handles cases where the user wants to focus a non-most-recent thread without re-touching it.

- **2026-05-19** — **`focus` block fields for multi-change scenarios: `primary_change`, `primary_change_kind`, `ranking_basis`, `secondary_threads[]`.** `primary_change` names the focal thread. `primary_change_kind` is `"active"` or `"exploring"` so consumers know which bucket primary came from. `ranking_basis` is `"most_recently_touched"` (default) or `"user_specified"` (when `--change` was used). `secondary_threads[]` is an opinionated rendered list of non-primary threads with one-line summaries. Rationale: the focus block becomes self-contained for "what to spotlight"; consumers don't have to re-derive the spotlight + secondary view from the bucket arrays.

- **2026-05-19** — **Buckets and ranking are decoupled.** JSON buckets (`active` / `exploring` / `recent`) categorize by phase-major state; focus ranking ignores buckets and merges across them when picking primary. An exploration thread can rank as primary if it's the most recently touched. Rationale: buckets serve filtering/iteration use cases ("show me all active"); ranking serves the "what should I focus on?" question — different concerns. Conflating would force either (a) ranking exploring below active always (wrong when user just touched an exploration), or (b) merging buckets and losing the natural categorization.

- **2026-05-19** — **Plain-openspec degradation: `is_orbit_project: false` omits orbit-specific fields.** When the project has `openspec/` but no orbit overlay (no `.orbit-runs/` anywhere, no orbit skills in `.claude/`), `project.is_orbit_project` is `false`; orbit-specific keys (`review_history`, `.orbit-runs`-derived `attention` types, `recommended_next.source` tier-1 paths) are omitted from the JSON. Human view degrades to "active changes only, no review history" — phase inference still works from artifact presence and `tasks.md` checkbox counts. Rationale: orbit-status remains useful on plain-openspec projects; users get the basics (what's active, what phase, task progress) without empty/misleading orbit-fields. Detection: `is_orbit_project` is true iff any change directory contains `.orbit-runs/` OR `.claude/skills/openspec-review/` exists (orbit overlay marker).

- **2026-05-19** — **v1 surface is status-only; no subcommand framework. Flags: `--detail`, `--json`, `--change <name>`, `--limit N`.** Running `orbit-status` (or its binary `opsx-status`) produces the default status view. Flags modify presentation: `--detail` expands per-change view (review breakdown, source field, full attention text); `--json` emits machine-readable; `--change <name>` pins focus to a specific thread; `--limit N` caps `recent[]` length (default 5). No subcommands like `orbit-status iterations` for v1. Rationale: status is the load-bearing surface; subcommands can be added in v2 without breaking the v1 flag-based contract. Keeps the v1 binary small (~200 lines bash) and focused.

- **2026-05-19** — **Binary lives at `.claude/skills/openspec-status/bin/opsx-status` — colocated with the SKILL.md.** Same overlay path as the orbit SKILL files; ships via orbit's overlay. Slash command shells out via a relative path from the skill directory. Rationale: keeps the binary inside the orbit overlay (single distribution channel), avoids requiring users to manage a separate PATH installation, and establishes the "skills can ship executables" pattern in orbit (which the upstream orbit-conventions spec amendment should acknowledge as a new affordance).

- **2026-05-19** — **Four named surfaces, each matching its convention:**
  - **Project repo**: `orbit-status` (at `~/code/orbit-status/`, sibling to `~/code/openspec-orbit/`)
  - **Skill directory**: `.claude/skills/openspec-status/` (matches the existing `openspec-*` skill naming pattern in orbit's overlay; consistency with `openspec-review`, `openspec-explore`, etc.)
  - **Slash command**: `/opsx:status` (file at `.claude/commands/opsx/status.md`)
  - **Binary**: `opsx-status` (at `.claude/skills/openspec-status/bin/opsx-status`)

  Rationale: each surface has its own grammar; harmonizing forces awkward names somewhere. The relationship — project ships overlay containing skill + command + binary — is documented; names are consistent within each convention.

## Open questions

_All resolved as of 2026-05-19 — see Decisions section above._

## Considered & out

- **2026-05-19** — **Subfolder of openspec-orbit (`openspec-orbit/cli/orbit-status/`).** Rejected because (1) the overlay-as-distribution test is weaker when the project lives inside orbit's own repo (orbit's `.claude/` is right there already, can't test the install path), (2) couples release cycles (orbit-the-overlay would have to track CLI growth), (3) easier to merge inward later if needed than to extract outward.

- **2026-05-19** — **TypeScript / npm package as the v1 form.** Rejected for v1 because the infrastructure (build, npm publish, deps, semver, cross-platform handling) is heavy for a CLI that can fit in 150–300 lines of bash. The decision is path-dependent: ship bash, port to TS if real adoption signal demands cross-platform / package distribution.

- **2026-05-19** — **Slash command alone, no underlying CLI.** Rejected because the slash command would re-implement the data extraction in markdown / AI-driven logic, the two surfaces would drift, CI usage would be impossible, and the AI's value-add (interpretation) would be diluted by boring data work.

## References

- `~/code/openspec-review/` — orbit-the-overlay source; install guide; archived changes useful for grounding the phase model.
- `~/code/openspec-review/openspec/changes/archive/` — real worked examples of change file shapes per phase.
- `~/code/openspec-review/.orbit-runs/` (when populated) — emitted artifacts from review/audit/address-reviews flows; informs `.orbit-runs/` traversal logic.
- Prior-session transcript: `~/.claude/projects/-Users-sal-code-openspec-review/5a9b5216-f9f5-431a-9b2c-1f268ef2fc78.jsonl` (lines 3791–3940) — captures the design discussion that produced the Decisions above.
- `las-sal/openspec-orbit#6` — overlay-scope bug; informs install-context decisions for orbit-status as a consumer.
- `las-sal/openspec-orbit#7` — auto-invoke convention; informs how the `/opsx:status` slash command should handle "do you want me to run the CLI for you?" moments.
- `las-sal/openspec-orbit#8` — proposal that workflow commands (explore/propose/apply/verify) emit run-summary JSONs with `next_recommended`. If implemented, orbit-status drops its tier-2 synthesis layer.
