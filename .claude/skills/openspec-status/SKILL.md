---
name: openspec-status
description: "Status CLI for openspec-orbit projects. Walks an openspec/ tree and surfaces what's active, what phase each change is in, what needs attention, and where the developer is in the workflow. Shells out to the bin/opsx-status binary and interprets its JSON output for conversational presentation."
license: MIT
compatibility: Requires openspec CLI + jq. Binary ships at .claude/skills/openspec-status/bin/opsx-status.
metadata:
  author: openspec-orbit
  version: "0.1"
  capability: orbit-status
---
Surface the status of an openspec-orbit project: what's active, what phase, what needs attention, where the developer is in the workflow. The skill invokes the `opsx-status` binary (shipped at `bin/opsx-status` under this skill directory) and interprets its JSON output for conversational presentation.

**Read-only.** orbit-status never mutates state — it reads filesystem artifacts and orbit-emitted JSONs in `.orbit-runs/` and renders a "you are here" view.

## Surface

`opsx-status [--detail] [--json] [--change <name>] [--limit N]`

| Flag | Effect |
|---|---|
| `--detail` | Expanded per-change view: full review-history breakdown by mode, full attention text, `source` field in recommendations, `next_unchecked` task description |
| `--json` | Emit machine-readable JSON to stdout (suppresses human-formatted text) |
| `--change <name>` | Pin focus to a specific thread (overrides default most-recently-touched ranking; sets `focus.ranking_basis: "user_specified"`) |
| `--limit N` | Cap `recent[]` length (default 5; `N` must be non-negative integer) |

Default invocation (no flags) emits a one-screen human-readable view designed to fit ~24 terminal lines for typical projects.

## JSON schema (when `--json`)

Top-level keys (all six present in every emission):

```
{
  "project": { "path", "name", "is_orbit_project" },
  "focus": {
    "summary",
    "primary_change", "primary_change_kind",
    "ranking_basis",
    "recommended_next": { "command", "args", "reason", "source?" },
    "secondary_threads": [...]
  },
  "active":    [ ChangeRecord ],
  "exploring": [ ChangeRecord ],
  "recent":    [ ChangeRecord ],
  "totals":    { "active", "exploring", "archived" }
}
```

`ChangeRecord` fields: `name`, `phase`, `artifacts_present`, `tasks` (counts + `next_unchecked`), `review_history` (summary by default; full breakdown with `--detail`), `attention[]`, `last_touched`, `archived_at` (only on archived records).

For the full schema and source-of-truth strategy (orbit's `.orbit-runs/*.json` first, filesystem walks for what JSONs don't cover), see the canonical specs at `openspec/changes/bootstrap-orbit-status-cli/specs/` (in the orbit-status project).

## Phases

`exploring | proposed | applying | reviewing | verified | archived` — precedence-ordered inference rules; the change directory wins over a sibling `openspec/explore/` directory. See `orbit-status-phase-model` capability.

## Recommendation hierarchy

Three tiers, first applicable wins:

1. **Tier 1**: read `next_recommended` from the most recent `.orbit-runs/*.json`. Marker override fires when unresolved `@review:` markers exist.
2. **Tier 2**: synthesize from artifact presence (4 rules — see `orbit-status-recommendation` capability).
3. **Tier 3**: project-level fallback ("No active workflow. Use /opsx:explore to start one.").

## Interpretation guidance for the slash command

The `/opsx:status` slash command shells out to `opsx-status --json` and elaborates the result conversationally. The full interpretation rules live in `.claude/commands/opsx/status.md`. Key principles:

**Surface orbit's voice, don't paraphrase.** `focus.recommended_next.reason` is orbit's own recommendation (tier 1 reads it from the latest `.orbit-runs/*.json`'s `next_recommended` field; tier 2 synthesizes from artifact presence; tier 3 is the empty-project fallback). Quote `reason` verbatim. Show `command` + `args` when populated. Mention `source` under `--detail` so the user can see which tier/JSON/rule drove the recommendation.

**Attention type-aware rendering:**

| Type | Suggested follow-up |
|---|---|
| `unresolved_marker` | `/opsx:address-reviews <name>` — markers signal review-cycle work isn't done |
| `stale_review` | Fresh `/opsx:review` — artifacts moved since the last review |
| `audit_divergence` | `/opsx:audit-drift` — orbit detected drift in captured knowledge |
| `task_blocked` | Deferred to v2 (NOOP in v1) |

**Workflow inflection-point pattern (per orbit issue `#15`):** end responses with a menu of legitimate next-step options at the current cycle position, not a single suggested action. The recommendation lights up the default; alternatives are honest about what else is reasonable.

**Don't auto-invoke (per orbit issue `#7`):** surface the recommendation; let the user type the command. The slash command's job is interpretation and orientation, not execution.

**Plain-openspec degradation:** when `project.is_orbit_project` is `false`, `review_history` and `recommended_next.source` are omitted from the JSON. Don't reach for those fields; don't reference orbit-specific concepts (iteration counts, tier semantics) in the chat output.

## Implementation status

v0.1 — initial implementation of `bootstrap-orbit-status-cli` change. All four capabilities (`orbit-status-output`, `orbit-status-phase-model`, `orbit-status-recommendation`, `orbit-status-distribution`) implemented; see `openspec/changes/bootstrap-orbit-status-cli/` for the canonical specs, design rationale, and task progress. Binary at `bin/opsx-status` is ~830 lines of bash with `jq` for JSON.

## Status

v0.1 — initial implementation of `bootstrap-orbit-status-cli` change. See `openspec/changes/bootstrap-orbit-status-cli/` for the canonical specs, design rationale, and task progress.
