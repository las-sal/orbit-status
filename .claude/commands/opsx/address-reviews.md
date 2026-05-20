---
name: "OPSX: Address Reviews"
description: Resolve @review: markers across the repo (or external-review findings via --from-file) with pushback discipline
category: Workflow
tags: [workflow, address-reviews, orbit]
---
Resolve `@review:` markers anywhere in the repo (or ingest external-review findings from a file) by walking each through: pushback → classify → fix → ripple-flag → remove-marker.

**Primary use case**: close the cross-AI review cycle. Ingest the external-AI findings file written by `/opsx:review-external` via `--from-file`, walk each finding with pushback discipline.

**Secondary use case**: walk inline `@review:` markers scattered across the repo (markdown / source / configs) with structured pushback. Markers are removed from source on resolution.

## Input

`/opsx:address-reviews [<scope>] [--from-file <path>] [flags]`

- `<scope>` — optional. Path, pattern, or change name. Default: whole-repo scan with safe exclusions (`.git`, `node_modules`, `dist`, `build`).
- `--from-file <path>` — ingest external-review findings from a markdown file (orbit external-review format).

## Flags

```
--keep-resolved-markers          debug: don't remove markers after resolution
```

(Scope restriction is handled by the positional `<scope>` argument, which accepts a path, glob pattern, or change name. `--only` and `--list` were considered but cut from lean v1; see issue #3.)

## What it does

Invokes the `openspec-address-reviews` skill, which executes the lean v1 lifecycle:

1. **Discover** — grep for `@review:` markers in scope (or parse `--from-file` into virtual markers)
2. **Triage** — present a numbered list; user can scope to a subset
3. **Walk each sequentially**:
   - **Pushback** — verify against current state (grep / git log / file read); classify stale findings and suppress them
   - **Classify** — stale / trivial fix / decision required / unresolvable
   - **Fix** — apply trivial fix, or surface 2–4 options via `AskUserQuestion` for decisions
   - **Ripple flag** — list affected related files (no auto-cascade in v1)
   - **Remove marker** — delete from source on resolution (invariant; `--keep-resolved-markers` overrides)
4. **Report** — emit a resolution log with ✓ Resolved / ⚠ Stale / ⏸ Deferred / ✗ Escalated counts and per-marker entries
5. **Persist** — write run summary to `.orbit-runs/address-reviews-<TS>.json`

## Output

Resolution log (NOT a 3-dimension scorecard — this command resolves rather than scans):

- Summary table (✓ ⚠ ⏸ ✗ counts)
- Per-section listings: file:line, brief description, action taken, ripple-flagged files
- Final-assessment line: remaining markers in scope + suggested next step

## Marker convention

| Form | Meaning |
|---|---|
| `@review: <text>` | Needs review/decision — full lifecycle |
| `@review(escalated): <text>` | Escalated; not auto-walked unless explicitly scoped |
| `@todo: <text>` | Out of scope (known follow-up work, not a review item) |

Markdown carries the marker bare; source code and configs wrap it in the file type's comment syntax (`// @review:`, `# @review:`, `/* @review: */`).

## Execution disciplines

- **Pushback (primary)** — verify each marker against current state before fixing. Stale → remove without edit + evidence note.
- **Read-before-reference** — re-read each file before applying any fix; verify after edits.
- **Change completeness** — ripple-flag related files; v1 lists them rather than auto-cascading.

## Constraints

- **Never creates new `@review:` markers.** Only `/opsx:review --as proposal --mark` does that.
- **No auto-cascade in v1.** Ripple-flagged files are listed, not edited.

See `.claude/skills/openspec-address-reviews/SKILL.md` for full lifecycle, classification heuristics, ingest format, and worked example.
