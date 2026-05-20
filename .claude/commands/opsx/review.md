---
name: "OPSX: Review"
description: Editorial review of an OpenSpec change in proposal mode (pre-apply) or system mode (post-apply)
category: Workflow
tags: [workflow, review, orbit]
---
Run an editorial review of an OpenSpec change. Two modes share one command:

- **`--as proposal`** — pre-apply review of artifacts (proposal, design, spec deltas, tasks, explore.md). 9 passes.
- **`--as system`** — post-apply review of the whole product state. Wraps upstream `verify-change` as Pass 0 + adds 6 system-wide passes.

When `--as` is omitted, the mode is inferred from `tasks.md` state (unchecked → proposal; all checked + code → system; ambiguous → prompts).

**Generates findings; does not resolve them.** Use `/opsx:address-reviews` to close findings (inline `@review:` markers, paste, or `--from-file`).

## Input

`/opsx:review [<change-name>] [--as proposal|system] [flags]`

- `<change-name>` — optional. If omitted, prompts via `openspec list --json`.
- `--as proposal|system` — optional. Inferred from `tasks.md` if omitted.

## Flags

```
--fast | --full | --thorough     depth (default --full)
--parallel                       subagent parallelism for heavy passes
--focus <lens>                   rename | flip | refactor | extension | hotpath
--strict                         fail-fast on first CRITICAL
--fresh                          clean-context subagent for main work
--mark                           proposal mode only: drop @review: markers based on findings
--skip-verify                    system mode only: skip Pass 0 (verify-change)
```

## What it does

Invokes the `openspec-review` skill, which:

1. Resolves change name, mode, and flags (mode inference from `tasks.md` state when `--as` omitted)
2. Reads change artifacts via the openspec CLI (`openspec status`, `openspec instructions apply`)
3. Loads project context (`CLAUDE.md`, `project.md`, `*_convention.md`), baseline specs (`openspec/specs/`), orbit lenses (`openspec/lenses/`)
4. Checks `.orbit-runs/` for prior `review-<mode>-*.json` summaries — informs iteration tracking and stale-finding suppression
5. Runs mode-specific passes:
   - **Proposal**: Passes 1–9 (Structure & Delta, Internal Coherence, Cross-Doc, Archive Consistency, Codegen Readiness, Gap Hunt, Drift Hunt, Inline Marker Residue, Pre-Handoff Sweep)
   - **System**: Pass 0 (delegates to `/opsx:verify` via the upstream `openspec-verify-change` skill) + Passes 1–6 (Baseline Compliance, Cohesion, Surface Walk, Perspective Reviews, Critical-Path Scan, Drift/Residue via `/opsx:audit-drift`)
6. Rolls findings into the 3-dimension scorecard (Completeness / Correctness / Coherence)
7. Emits the final-assessment line (mode-specific gate text: `/opsx:apply` vs `/opsx:archive`)
8. Persists a run summary to `openspec/changes/<change-name>/.orbit-runs/review-<mode>-<TS>.json`

## Output

Standard 3-dimension scorecard report with CRITICAL / WARNING / SUGGESTION severities, file:line refs, and actionable recommendations. Mode and iteration are shown in the header. Final-assessment line uses one of the stock phrasings (see SKILL.md).

## Execution disciplines

Three disciplines apply throughout (per `orbit-conventions`):

- **Read-before-reference (authoring-time)** — read the actual definition of any specific construct cited in a finding.
- **Change completeness (modification-time)** — `--mark` writes must be applied fully across all affected artifacts, with a sweep for residue after mechanical insertion.
- **Pushback (review-time)** — verify each finding against current state before reporting. Stale findings get suppressed with evidence.

See `.claude/skills/openspec-review/SKILL.md` for full behavior, scorecard rollup, and worked examples.
