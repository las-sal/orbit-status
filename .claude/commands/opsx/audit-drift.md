---
name: "OPSX: Audit Drift"
description: Project-wide scan for drift between captured knowledge and reality across four categories
category: Workflow
tags: [workflow, audit, drift, orbit]
---
Scan the project for drift between captured knowledge (specs, lenses, governing docs) and current reality. Four scan categories:

1. **Vocabulary residue** — renamed/removed terms lingering in non-delta'd specs and governing docs
2. **Lens staleness** — entries in `openspec/lenses/` referencing surfaces/capabilities that no longer exist
3. **Cross-doc consistency** — different docs describing the same thing inconsistently (or contradicting current specs)
4. **Archive coherence** — recently archived changes whose `sync-specs` step missed updates

## Input

`/opsx:audit-drift [flags]`

No positional arguments. Invocation context is detected automatically.

## Flags

```
--fast | --full | --thorough     depth (default --full)
--parallel                       subagent parallelism for heavy categories
--focus <area>                   vocabulary | lenses | docs | archive
--since <ref>                    window for Category 4 (default last 5 archives)
--strict                         fail-fast on first CRITICAL
```

## Invocation contexts

Three ways audit-drift runs, each with slightly different output framing:

1. **Standalone** — user invokes when "something feels off." Emits full report with own final-assessment line.
2. **Library call** — `/opsx:review --as system` Pass 6 invokes internally. Findings fold into the review report's Coherence dimension; no standalone final-assessment.
3. **Pre-archive** — `/opsx:archive` auto-invokes before completing. Critical findings trigger a three-way prompt (address now / proceed / abort). Opt-out via `/opsx:archive --skip-audit`.

## What it does

Invokes the `openspec-audit-drift` skill, which:

1. Resolves invocation context (standalone / library / pre-archive) and flags
2. Loads required context per category (archived deltas, lenses, governing docs, baseline specs)
3. Runs the four categories (or a subset per `--fast` or `--focus`)
4. Rolls findings into the 3-dimension scorecard:
   - Category 4 → Completeness
   - Categories 1 and 2 → Correctness
   - Category 3 → Coherence
5. Emits a final-assessment line whose phrasing depends on invocation context
6. Persists a run summary to `.orbit-runs/audit-drift-<TS>.json` (change-scoped or `openspec/.orbit-runs/` for standalone)

## Output

Standard 3-dimension scorecard report grouped by Category and Dimension; CRITICAL / WARNING / SUGGESTION findings with file:line refs and actionable recommendations. Final-assessment line uses one of the context-specific stock phrasings (see SKILL.md).

## Execution disciplines

- **Read-before-reference** — verify every cited file:line by reading the line; distinguish genuine vocabulary residue from documentation of the residue pattern.
- **Change completeness** — N/A in the conventional sense (audit-drift is scan-only); documented for cross-command consistency.
- **Pushback** — verify each potential finding against current state; suppress stale findings with evidence.

See `.claude/skills/openspec-audit-drift/SKILL.md` for full category logic, scorecard rollup, and worked example.
