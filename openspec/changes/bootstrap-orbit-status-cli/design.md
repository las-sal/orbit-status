## Context

orbit-status is the first non-markdown executable orbit ships. It sits between the filesystem state of an openspec/orbit project and the developer's mental model of "what should I do next?" Its existence is motivated by the observation that orbit's editorial commands (`/opsx:review`, `/opsx:address-reviews`, `/opsx:audit-drift`, `/opsx:archive`) already emit structured run-summary JSONs to `.orbit-runs/` — including their own `next_recommended` field. orbit-status surfaces what orbit already says, rather than re-deriving state from filesystem patterns.

This change also serves as the consumer-side test of orbit's overlay-as-distribution model. The project lives at `~/code/orbit-status/`, consumes orbit as a downstream project would, and exercises the install path end-to-end. Bugs discovered during the bootstrap (`las-sal/openspec-orbit#6`, `#7`, `#8`) are filed upstream and explicitly out of scope for this change.

## Goals / Non-Goals

**Goals:**

- One-screen "you are here" status for orbit/openspec projects, oriented around the developer's workflow position.
- Use orbit's own `.orbit-runs/*.json` as source of truth for review history, findings, and recommendations.
- Graceful degradation on plain-openspec projects (no orbit overlay installed) — fewer fields, same basic value.
- JSON-first contract: human view is a rendering of the same data the slash command consumes.
- Shell-runnable; usable from CI / scripts without an AI in the loop.

**Non-Goals:**

- Mutations of any kind. orbit-status is read-only.
- Subcommands beyond `status` for v1. Flags only.
- Cross-platform binary distribution. Bash + POSIX tools; Windows users use WSL.
- Pretty TUI, interactive prompts, or `--watch` mode.
- Re-deriving anything orbit already emits via run-summary JSONs.

## Decisions

### Implementation language: bash + `jq`

The CLI is a bash script (~200 lines target) using `jq` for JSON parsing. Rationale: zero build infrastructure, ~10ms startup, native composability with shell pipelines, runs in CI without setup. `jq` is widely available on dev machines and CI runners; install guidance ships in the README.

Alternative considered: TypeScript/npm package. Rejected for v1 — heavy infrastructure (build, npm publish, semver, cross-platform) for a CLI that fits in 200 lines. Reconsider if real adoption demands cross-platform/package distribution.

Alternative considered: `python3` instead of `jq`. Rejected — wider semantic surface but slower startup; `jq` is the right granularity for the task. Could add `python3` fallback if `jq` portability bites.

### Source of truth: orbit's `.orbit-runs/*.json`

For every signal orbit emits (iteration counts, findings, recommendations, audit results), orbit-status reads the JSON. Per-run JSONs (`review-*`, `address-reviews-*`, `audit-drift-*`, `archive-*`) have structured fields (`iteration`, `findings_summary`, `final_assessment`, `next_recommended`).

Filesystem walks fill in only what orbit doesn't emit:

- Artifact presence (proposal.md, design.md, tasks.md, specs/, explore.md)
- `tasks.md` checkbox counts (parsed via `grep`)
- `@review:` marker scans (parsed via `grep` across artifacts)
- File mtimes for "last touched" / "stale_review" detection

Alternative considered: re-derive everything from filesystem. Rejected — duplicates orbit's already-cooked output; risks drift between orbit's mental model and orbit-status's heuristics; brittle to artifact format changes.

### Three-tier recommendation hierarchy

`focus.recommended_next` is sourced by tier:

1. **Tier 1 (read from orbit)**: if `.orbit-runs/*.json` exists for the focal change, read the most recent JSON's `next_recommended` field verbatim. orbit's own recommendation wins.
2. **Tier 2 (synthesis, v1 only)**: if no `.orbit-runs/` for the change, synthesize from artifact presence using a small deterministic ruleset.
3. **Tier 3 (project-level fallback)**: if no active work at all, default to `"No active workflow. Use /opsx:explore to start one."`

Tier 2 synthesis ruleset (precedence-ordered):

| Artifact state | Recommendation |
|---|---|
| only `explore.md` in `openspec/explore/<name>/` | `/opsx:propose <name>` |
| `proposal.md` exists but no `tasks.md` | `/opsx:propose <name>` (continue artifact generation) |
| `tasks.md` with all `[ ]` unchecked, no review JSON | `/opsx:review <name>` |
| `tasks.md` with partial checkboxes, no review since last task | `/opsx:apply <name>` |
| review JSON exists but unresolved `@review:` markers in artifacts | `/opsx:address-reviews <name>` |

Rationale: tier 1 keeps orbit-status maximally thin over orbit's voice. Tier 2 is a documented v1 stopgap; `las-sal/openspec-orbit#8` proposes that workflow commands emit run-summary JSONs upstream, which would eliminate tier 2. Tier 3 covers the empty-project case.

### Phase inference: precedence-ordered

Phase enum: `exploring | proposed | applying | reviewing | verified | archived`.

Inference precedence (first match wins):

1. Change directory is under `openspec/changes/archive/` → `archived`.
2. Most recent `.orbit-runs/*.json` command type:
   - `archive-*` → `archived` (pending file move)
   - `review-*` or `address-reviews-*` → `reviewing`
3. `tasks.md` with any `[x]` and any `[ ]` → `applying`.
4. `proposal.md` exists, `tasks.md` absent or all `[ ]` → `proposed`.
5. Only `explore.md` exists in `openspec/explore/<name>/` (no change directory) → `exploring`.
6. `verified` is reserved for when `/opsx:verify` emits run-summary JSONs (cf. `las-sal/openspec-orbit#8`).

Rationale: six clean states cover the lifecycle; precedence ordering avoids ambiguity when multiple signals are present.

### Attention as typed structured array

Shape: `[{ type, location, text?, since?, count? }, ...]`.

Closed enum of types:

- `unresolved_marker` — `@review:` text found in an artifact (fields: `location`, `text`)
- `stale_review` — artifact modified after most recent review JSON (fields: `location`, `since`)
- `task_blocked` — `tasks.md` line tagged with a blocker note (fields: `location`, `text`)
- `audit_divergence` — `.orbit-runs/audit-drift-*.json` reports unresolved findings (fields: `location`, `count`)

Closed enum makes "needs attention" introspectable and filterable. Extending the enum requires a code change in orbit-status, preventing free-form text leak from artifacts into the attention surface.

### Top-level JSON schema

```
{
  "project": { "path", "name", "is_orbit_project" },
  "focus": {
    "summary",
    "primary_change",
    "primary_change_kind",        // "active" | "exploring"
    "ranking_basis",              // "most_recently_touched" | "user_specified"
    "recommended_next": { "command", "args", "reason", "source" },
    "secondary_threads": [...]    // non-primary, ranked
  },
  "active":    [ ChangeRecord ],  // changes in openspec/changes/<name>/
  "exploring": [ ChangeRecord ],  // pre-change explorations in openspec/explore/<name>/
  "recent":    [ ChangeRecord ],  // archived changes, capped via --limit
  "totals":    { "active", "exploring", "archived" }
}
```

`ChangeRecord` per-change fields: `name`, `phase`, `artifacts_present`, `tasks` (counts + `next_unchecked`), `review_history` (summary by default; full breakdown with `--detail`), `attention[]`, `last_touched`.

### Multi-change focus ranking

When multiple active + exploring threads exist, primary is picked by `last_touched` mtime (descending). The `--change <name>` flag overrides ranking, setting `focus.ranking_basis: "user_specified"`. Buckets (`active` / `exploring` / `recent`) and ranking are decoupled: an exploration can rank as primary if it's the most recently touched.

Rationale: most-recently-touched is deterministic, predictable, and matches "what was I doing last?" Refinements (weight by phase, attention severity) would add surprise; v1 doesn't need them.

### Plain-openspec graceful degradation

`project.is_orbit_project` is `true` iff any change directory contains `.orbit-runs/` OR `.claude/skills/openspec-review/` exists (orbit overlay marker).

When `is_orbit_project: false`:

- `review_history` is omitted from `ChangeRecord`
- `attention` types `unresolved_marker` and `stale_review` still emit (artifact-based); `audit_divergence` is suppressed (no audit JSONs to read)
- `recommended_next.source` field is omitted (tier 1 unreachable; tier 2 / tier 3 still apply)
- Human view drops the "(orbit project)" tag and the "review history" line per change

### Binary install location

`.claude/skills/openspec-status/bin/opsx-status` — colocated with the SKILL.md. Ships via orbit's overlay (single distribution channel). Slash command shells out via a path relative to the skill directory.

This establishes the precedent that orbit's overlay can ship `bin/` executables alongside markdown skills. A follow-on note in `orbit-conventions` is needed upstream — flagged in proposal Impact, out of scope here.

### Four-surface naming

- **Project**: `orbit-status` (repo at `~/code/orbit-status/`)
- **Skill directory**: `.claude/skills/openspec-status/` (matches `openspec-*` overlay convention)
- **Slash command**: `/opsx:status` (file at `.claude/commands/opsx/status.md`)
- **Binary**: `opsx-status` (at `bin/opsx-status` under the skill directory)

Each surface follows its own convention; harmonizing would force awkward names somewhere.

## Risks / Trade-offs

- **Tier-2 synthesis drift**: v1 synthesis rules may diverge from orbit's evolving semantics as orbit adds workflow commands or changes their behavior. → Mitigation: filed `las-sal/openspec-orbit#8` to push tier-2 logic back into orbit; v2 deletes the synthesis layer once upstream emits the data.
- **`jq` as a hard dependency**: limits portability to environments without it. → Mitigation: `jq` is widely available; install guidance in README; could add `python3` fallback in v2.
- **"Most-recently-touched" ranking is naive**: a tangential edit to an old change can promote it to primary. → Mitigation: `--change` flag overrides; refine heuristic in v2 (weight by phase, attention).
- **JSON schema is public contract**: changes break downstream consumers (slash command, CI). → Mitigation: v1 schema documented in spec; schema-breaking changes increment major version.
- **First overlay binary sets precedent**: orbit-conventions spec must acknowledge `bin/` directories under skills. → Mitigation: separate upstream PR; this change documents the pattern locally without modifying orbit's own specs.

## Migration Plan

Greenfield change — no migration. Once shipped:

- v0.1 ships from `~/code/orbit-status/` with full v1 feature set.
- Upstream merge into orbit overlay can happen anytime after `openspec-orbit#6` (overlay-scope fix) lands — orbit-status's install instructions assume the corrected overlay flow.

## Open Questions

- **Exact `stale_review` mtime granularity**: artifact mtime > most recent `review-*.json` mtime — what's the buffer? Probably "any modification after the review JSON was written counts," but a minutes-grained tolerance might prevent noise from co-occurring edits. Defer to apply.
- **`jq` portability cliff**: if real-world adoption hits environments without `jq`, decide between (a) requiring users to install it, (b) shipping a `python3` fallback path, (c) embedding a minimal JSON parser in bash (unlikely). Defer until evidence.
- **Should `recent[]` include an `--all` flag**: default cap is 5 with `--limit N`; do we want `--limit 0` or `--all` to surface every archive? Probably yes — small change, useful for audit. Decide during apply.
