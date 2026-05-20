## Why

orbit-status doesn't exist yet — there's no CLI that walks an `openspec/` tree and surfaces, in one screen, what's active, what phase each change is in, what needs attention, and where the developer is in the workflow. `openspec list` enumerates changes but doesn't interpret state or recommend a next action. orbit-status fills that gap by reading orbit's already-emitted `.orbit-runs/*.json` files (where orbit's editorial commands record their own `next_recommended` field) and surfacing that as the "you are here" indicator. It also serves as a real-world test of orbit's overlay-as-distribution model — building and consuming orbit the way a downstream project does.

## What Changes

- **New CLI binary**: `opsx-status` (bash, ~200 lines), shipped at `.claude/skills/openspec-status/bin/opsx-status`
- **New slash command**: `/opsx:status` (at `.claude/commands/opsx/status.md`), a thin interpretation wrapper that invokes `opsx-status --json` and elaborates the output
- **New skill**: `.claude/skills/openspec-status/SKILL.md` documenting the status surface, flag semantics, and JSON schema
- **JSON-first contract**: `--json` emits the machine-readable schema; the human-readable default view is a rendering of the same data
- **Three-tier recommendation engine**: read `next_recommended` from the most recent `.orbit-runs/*.json` (tier 1); synthesize from artifact presence when orbit hasn't emitted yet (tier 2); project-level fallback when no active work (tier 3)
- **Flags**: `--detail` (expanded per-change view), `--json` (machine-readable), `--change <name>` (pin focus to a specific thread), `--limit N` (cap `recent[]` length)
- **Multi-change focus**: most-recently-touched thread wins by default; `--change` overrides
- **Plain-openspec graceful degradation**: works on plain `openspec/` projects without orbit overlay; orbit-specific fields omitted when `is_orbit_project: false`

## Capabilities

### New Capabilities

- `orbit-status-output`: JSON schema shape (`project / focus / active / exploring / recent / totals`) + human-readable rendering + flag surface (`--detail`, `--json`, `--change`, `--limit`).
- `orbit-status-phase-model`: phase enum (`exploring | proposed | applying | reviewing | verified | archived`), precedence-ordered inference rules, attention signal types and shape.
- `orbit-status-recommendation`: three-tier recommendation hierarchy, multi-change focus ranking, `focus` block field shape (`primary_change`, `primary_change_kind`, `ranking_basis`, `secondary_threads[]`, `recommended_next`).
- `orbit-status-distribution`: overlay-shipped binary at `.claude/skills/openspec-status/bin/`, four-surface naming (project / skill / command / binary), plain-openspec graceful degradation, detection rule for `is_orbit_project`.

### Modified Capabilities

<!-- empty: this is a greenfield change; no existing orbit-status specs to delta against -->

## Impact

- **Affected code**: new `.claude/skills/openspec-status/` (skill + `bin/`) and new `.claude/commands/opsx/status.md`.
- **Affected APIs**: none — orbit-status is read-only over orbit's existing `.orbit-runs/*.json` shape and the openspec filesystem layout.
- **Dependencies**: bash + standard POSIX tools (`stat`, `grep`, `find`); JSON parsing strategy (`jq` vs `python3`) decided in design.md.
- **Establishes precedent**: orbit's overlay can ship `bin/` executables alongside markdown skills. Follow-on work in `openspec-orbit` should note this in the `orbit-conventions` spec — out of scope for this change, but flagged for upstream.
- **No impact on existing orbit projects**: orbit-status is opt-in; only present when an orbit version including it is installed.
