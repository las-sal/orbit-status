# orbit-status

A status CLI for [openspec-orbit](https://github.com/las-sal/openspec-orbit) projects. Walks an `openspec/` tree (plus `.orbit-runs/` when present) and surfaces, in one screen: what's active, what phase each change is in, what needs attention, and where the developer is in the workflow.

orbit-status is the first non-markdown executable orbit ships. It reads orbit's already-emitted run-summary JSONs in `.orbit-runs/` as the source of truth, supplemented by filesystem walks for what orbit doesn't emit (artifact presence, task progress, marker scans). The slash command `/opsx:status` invokes the binary and elaborates the output conversationally.

> **Status**: v0.1 — initial implementation. The `bootstrap-orbit-status-cli` change in `openspec/changes/` is the canonical spec, design, and task record. See [Project provenance](#project-provenance) below for the full development arc.

---

## Quick start

```bash
# 1. Install upstream openspec (if not already)
npx @fission-ai/openspec@latest init --tools claude

# 2. (Optional but recommended) Enable the expanded workflow profile
openspec config profile      # interactive picker — choose 'expanded'
openspec update              # writes the additional workflow commands

# 3. Overlay openspec-orbit (which ships orbit-status)
git clone https://github.com/las-sal/openspec-orbit /tmp/orbit
cp -r /tmp/orbit/.claude/. .claude/
rm -rf /tmp/orbit

# 4. Verify orbit-status is on disk
ls .claude/skills/openspec-status/bin/opsx-status

# 5. Run it
.claude/skills/openspec-status/bin/opsx-status
```

> **On the openspec install dance**: the `openspec config profile` step is currently interactive (no non-interactive flag for the expanded profile in v1.3.1). See [orbit issue #6](https://github.com/las-sal/openspec-orbit/issues/6) for the install-guide cleanup work and the rationale.

## Dependencies

| Tool | Required | Install |
|---|---|---|
| `bash` | yes | preinstalled on macOS/Linux |
| `jq` | yes | `brew install jq` (macOS), `apt install jq` (Debian/Ubuntu), [other](https://stedolan.github.io/jq/download/) |
| `openspec` CLI | for projects using openspec; not strictly required for orbit-status to run | `npx @fission-ai/openspec@latest` |

orbit-status uses `jq` for all JSON parsing and emission. There is no fallback in v1; the binary exits with code 2 and clear install guidance if `jq` is missing.

## Usage

```
opsx-status [--detail] [--json] [--change <name>] [--limit N]
```

| Flag | Effect |
|---|---|
| `--detail` | Expanded per-change view: full review-history breakdown by mode, full attention text, `source` field in recommendations, `next_unchecked` task description |
| `--json` | Emit machine-readable JSON to stdout (suppresses human-formatted text). Top-level keys: `project`, `focus`, `active`, `exploring`, `recent`, `totals`. |
| `--change <name>` | Pin focus to a specific thread (overrides default most-recently-touched ranking; sets `focus.ranking_basis: "user_specified"`) |
| `--limit N` | Cap `recent[]` length (default 5; `N` must be a non-negative integer) |
| `--help`, `-h` | Show help |
| `--version` | Show version |

### Exit codes

- `0` — Success
- `1` — Operational error (no `openspec/`, `--change` names a missing thread, `--limit` negative)
- `2` — Dependency error (`jq` not on PATH)

## Sample output

### State A — archived bootstrap (tier-3 fallback)

Running `opsx-status` against `~/code/openspec-review` (the canonical openspec-orbit working tree) after the `bootstrap-openspec-orbit` change was archived:

```
~/code/openspec-review (orbit project)

No active workflow. Use /opsx:explore to start one.

Recently archived: 1 total (showing up to 5)
  bootstrap-openspec-orbit · archived 2026-05-18
```

The recommendation engine's tier-3 fallback fires when no active or exploring threads exist project-wide.

### State B — mid-apply (this very project, during chunk-3 implementation)

Running `opsx-status` against `~/code/orbit-status` itself, mid-implementation of `bootstrap-orbit-status-cli`:

```
~/code/orbit-status (orbit project)

You are applying bootstrap-orbit-status-cli.
  44/79 tasks · 5 attention

Next: /opsx:apply bootstrap-orbit-status-cli
  "Partial tasks; continue applying."
```

Phase inference resolves to `applying` via rule 3 (mixed `[x]` and `[ ]` in `tasks.md`). The 5 attention entries are real `stale_review` signals — artifacts edited since the last review pass.

Under `--detail`, the view expands:

```
~/code/orbit-status (orbit project)

You are applying bootstrap-orbit-status-cli.
  44/79 tasks · 5 attention
  next: Assemble top-level keys: project, focus, active, exploring, recent, totals

  attention:
    [stale_review] design.md (modified 2026-05-20T12:43:08Z)
    [stale_review] tasks.md (modified 2026-05-20T14:08:31Z)
    [stale_review] specs/orbit-status-phase-model/spec.md ...
    [stale_review] specs/orbit-status-recommendation/spec.md ...
    [stale_review] specs/orbit-status-output/spec.md ...

  review history: 6 iteration(s) · 15 finding(s) resolved
    proposal: 3 internal + 1 external
    system: 0 internal + 0 external
    address-reviews: 2 proposal + 0 system

Next: /opsx:apply bootstrap-orbit-status-cli
  "Partial tasks; continue applying."
  (source: tier-2 (rule 4: in-apply))
```

### State C — multi-change project

A hypothetical project with several active threads:

```
~/code/some-project (orbit project)

3 threads active. Primary: add-detail-flag (applying).
  3/7 tasks · 1 attention

Next: /opsx:apply add-detail-flag
  "Continue applying tasks (4 of 7). Re-review when chunk complete."

Other active:
  add-json-output      proposed · awaiting review
  add-iterations-cli   exploring · 4 decisions
```

Multi-change ranking picks primary by most-recently-touched mtime, with lexicographic name tie-break. `--change <name>` overrides.

## JSON schema

`--json` emits all six top-level keys, every invocation:

```jsonc
{
  "project": {
    "path": "/abs/path",
    "name": "project-name",
    "is_orbit_project": true
  },
  "focus": {
    "summary": "You are applying X.",
    "primary_change": "X",
    "primary_change_kind": "active",            // or "exploring"
    "ranking_basis": "most_recently_touched",   // or "user_specified"
    "recommended_next": {
      "command": "/opsx:apply",
      "args": "X",
      "reason": "<verbatim from orbit's JSON, or tier-2 synthesis>",
      "source": "tier-2 (rule 4: in-apply)"     // only under --detail on orbit projects
    },
    "secondary_threads": [
      { "name": "Y", "kind": "active", "phase": "proposed", "summary": "..." }
    ]
  },
  "active":    [ ChangeRecord ],
  "exploring": [ ChangeRecord ],
  "recent":    [ ChangeRecord ],
  "totals":    { "active": N, "exploring": N, "archived": N }
}
```

`ChangeRecord` per-change fields: `name`, `phase`, `artifacts_present`, `tasks` (`{total, completed, unchecked, next_unchecked?}`), `review_history` (summary by default; full breakdown with `--detail`), `attention[]`, `last_touched`, `archived_at` (only on archived records in `recent[]`).

On **plain-openspec projects** (no orbit overlay), `review_history` is omitted from `ChangeRecord` and `recommended_next.source` is omitted even under `--detail`. The CLI handles this gracefully; downstream consumers should treat orbit-specific fields as optional.

## Phases

| Phase | Inferred when |
|---|---|
| `exploring` | `openspec/explore/<name>/explore.md` exists, no change directory |
| `proposed` | `proposal.md` exists, no `[x]` in `tasks.md` (or `tasks.md` absent) |
| `applying` | `tasks.md` has both `[x]` and `[ ]` |
| `reviewing` | Most recent `.orbit-runs/*.json` is a review or address-reviews JSON, and that JSON is newer than `tasks.md` mtime |
| `verified` | Reserved for future `/opsx:verify` run-summary emissions |
| `archived` | Change directory is under `openspec/changes/archive/` |

Precedence is strict — first matching condition wins. Full rules in `openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-phase-model/spec.md`.

## Recommendation engine

Three-tier source hierarchy:

1. **Tier 1**: read `next_recommended` from the latest `.orbit-runs/*.json`. orbit's own recommendation wins. Marker override fires when unresolved `@review:` markers exist (suggests `/opsx:address-reviews` instead).
2. **Tier 2**: synthesize from artifact presence using a 4-rule precedence ordering (explore-only → propose; proposal-only → propose; unchecked tasks → review; partial tasks → apply).
3. **Tier 3**: project-level fallback ("No active workflow. Use /opsx:explore to start one.").

Full rules in `openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-recommendation/spec.md`.

## Attention signals

`attention[]` per change is a typed structured array with a closed enum of types:

| Type | Triggered by | Suggested follow-up |
|---|---|---|
| `unresolved_marker` | `@review:` at start of line in artifact | `/opsx:address-reviews <name>` |
| `stale_review` | Artifact mtime newer than latest `review-*.json` | Fresh `/opsx:review` |
| `audit_divergence` | Findings in latest `audit-drift-*.json` (orbit-only) | `/opsx:audit-drift` |
| `task_blocked` | (v2 — not yet emitted) | — |

## Tests

```bash
tests/run.sh
```

The test runner builds ephemeral fixtures under `mktemp` and exercises 96 assertions across the four capability specs plus schema validation against six fixture shapes (`empty-orbit`, `plain-openspec`, `exploring-only`, `mid-apply`, `with-archive`, `with-marker`). Comprehensive scenario-by-scenario coverage is tracked as `orbit-status#1`; v0.1 covers the load-bearing paths plus three regression tests (W1/W2/W3) added during the external system review cycle.

## Project provenance

`orbit-status` was bootstrapped via the full openspec-orbit workflow as a dogfooding test of orbit itself. The development arc is in the git history:

1. `initial: empty scaffold`
2. `install: orbit overlay from las-sal/openspec-orbit`
3. `add: bootstrap-orbit-status-cli change (proposal mode complete)`
4. `External review (proposal, iter 1)` — *by Codex GPT-5*
5. `close: iter-1 external review cycle`
6. `apply: chunk 1 (scaffold + project detection)`
7. `apply: chunk 2 (inventory + parsing)`
8. `apply: chunk 3 (phase + attention + recommendation engine + focus ranking)`
9. `apply: chunk 4 (output polish + plain-openspec degradation)`
10. `apply: chunk 5 (integration + docs + tests)`
11. `close: iter-1 system review cycle` — anchoring-aware in-context review
12. `External review (system, iter 1)` — *by Codex GPT-5; surfaced 3 real bugs the in-context review missed*
13. `close: iter-1 external system review cycle` — W1/W2/W3 + a side-effect bug fixed with regression tests
14. `apply: group 18 manual validation complete — 79/79 tasks done`
15. `archive: bootstrap-orbit-status-cli` *(this README's final pre-archive update)*

The dogfooding surfaced 10 issues filed against openspec-orbit (`#6` through `#15`), covering overlay scope, terminal-prompt accuracy, dynamic next-step recommendations, address-reviews cascade-by-default, and workflow inflection-point UX. See `openspec/changes/bootstrap-orbit-status-cli/explore.md` for the design record and `openspec/changes/bootstrap-orbit-status-cli/.orbit-runs/` for the review history.

## Related projects

- **[openspec-orbit](https://github.com/las-sal/openspec-orbit)** — the overlay that ships orbit-status alongside its editorial review machinery
- **[Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec)** — upstream openspec CLI; orbit-status is read-only over its filesystem layout

## License

MIT.
