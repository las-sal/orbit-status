---
name: openspec-audit-drift
description: "Project-wide scan for drift between captured knowledge and reality across four categories (vocabulary residue, lens staleness, cross-doc consistency, archive coherence). Use standalone when something feels off; auto-invoked as Pass 6 of system-mode review and as a pre-archive sweep."
license: MIT
compatibility: Requires openspec CLI. Composes with `/opsx:review --as system` (Pass 6) and `/opsx:archive` (pre-archive sweep).
metadata:
  author: openspec-orbit
  version: "0.1"
  capability: orbit-audit-drift
---
Scan the project for drift between captured knowledge (specs, lenses, governing docs) and current reality across four categories: (1) Vocabulary residue, (2) Lens staleness, (3) Cross-doc consistency, (4) Archive coherence. Three invocation paths: **standalone** (user runs when "something feels off"), **library call** (system-mode review Pass 6 invokes internally), **pre-archive** (auto-invoked by `/opsx:archive` before completing).

Findings roll into the standard 3-dimension scorecard. The final-assessment phrasing varies by invocation context.

**Input**: Optional flags (no positional argument). Detects invocation context via caller signal (set by `/opsx:review` and `/opsx:archive` when invoking as library; absent when standalone).

## Three execution disciplines (apply throughout this command)

**Read-before-reference (authoring-time)**. Findings cite file:line. Before reporting that `BridgeServer` appears at `openspec/specs/foo/spec.md:42`, read that line. Don't grep-and-cite without verifying — false-positive vocabulary residue (e.g., the term appears in a code block discussing the rename itself) is the most common audit-drift mistake. Distinguishing "actual residue" from "documentation of the residue pattern" requires reading.

**Change completeness (modification-time)**. **Not applicable to this command in the conventional sense.** Audit-drift is scan-only; it does not modify artifacts. But: when an audit run discovers that a prior `.orbit-runs/audit-drift-*.json` summary is malformed or partial, treat the new summary as a clean rewrite — do not merge with broken prior state. The discipline is documented here for cross-command consistency.

**Pushback (review-time)**. Verify each potential finding against current state before reporting:
- **Vocabulary residue (Cat 1)**: confirm the term still appears in the file at the cited line (grep + read). Don't report a finding based on a stale grep cache.
- **Lens staleness (Cat 2)**: confirm the referenced capability is genuinely missing under `openspec/specs/` — not just under a different name.
- **Cross-doc consistency (Cat 3)**: confirm both sides of the disagreement still exist; if one side was already corrected, suppress the finding.
- **Archive coherence (Cat 4)**: confirm the ADDED requirement really is absent from baseline — not just present under a renamed name.

Suppress stale findings with an evidence note (`stale finding suppressed: <evidence>`); show in summary's `stale_suppressed` array but not in the user-facing report.

**Bias toward lower severity when uncertain.** SUGGESTION beats WARNING beats CRITICAL. The goal is signal, not volume — same false-positive bias as `/opsx:review`.

## Steps

### 1. Resolve invocation context

Detect how audit-drift was invoked:

- **Standalone** — no caller signal; emit full report with own final-assessment line.
- **Library call** — caller is `/opsx:review --as system` (Pass 6); detect via explicit caller flag or by being run as a subagent with an audit-drift-only brief. Return findings to the caller; do NOT emit a standalone final-assessment.
- **Pre-archive** — caller is `/opsx:archive`; detect via explicit caller flag. Emit findings with the pre-archive prompt phrasing.

State the resolved context at the start of internal logging (not user-facing chat for library calls): `Context: <standalone|library|pre-archive>`.

### 2. Resolve flags

| Flag | Default | Effect |
|---|---|---|
| `--fast` / `--full` / `--thorough` | `--full` | Depth. Mutually exclusive. |
| `--parallel` | off | Spawn subagents for heavy categories (esp. C3 and C4 on large repos). |
| `--focus <area>` | none | Run only one category. `vocabulary` (C1), `lenses` (C2), `docs` (C3), `archive` (C4). |
| `--since <ref>` | last 5 archived changes | Window for Category 4 archive coherence scan. Accepts git ref or `<N>` to mean last N. |
| `--strict` | off | Fail-fast on first CRITICAL. |

`--fast` runs only Categories 1 and 2; reports 3 and 4 as `skipped per --fast`.
`--focus <area>` runs only the named category; reports others as `skipped per --focus <area>`.

### 3. Load context

Read what each category needs:

- **Category 1 inputs**: archived changes' deltas at `openspec/changes/archive/*/specs/<capability>/spec.md` for RENAMED FROM and REMOVED. Target docs: non-delta'd `openspec/specs/<capability>/spec.md`, `CLAUDE.md`, `openspec/project.md`, root `*_convention.md`.
- **Category 2 inputs**: `openspec/lenses/perspectives.md`, `openspec/lenses/critical-paths.md`. Resolve against `openspec/specs/<capability>/spec.md`.
- **Category 3 inputs**: `CLAUDE.md`, `openspec/project.md`, root `*_convention.md`. Cross-reference against `openspec/specs/`.
- **Category 4 inputs**: archived changes within window (`--since` controls window). For each, its `specs/<capability>/spec.md` deltas vs the live `openspec/specs/<capability>/spec.md`.

Use the openspec CLI for change/archive listings: `openspec list --json` and direct filesystem reads under `openspec/changes/archive/`.

### 4. Category 1 — Vocabulary residue

**Build the residue pattern set.** For each archived change:

- **RENAMED requirements**: extract the FROM and TO names. The FROM name is a residue pattern (term that should no longer appear).
- **REMOVED requirements**: extract the requirement name. The name is a residue pattern.

**Grep target docs** for each residue pattern:

- `openspec/specs/<capability>/spec.md` (non-delta'd files — the ones not in the archived change's `specs/`)
- `CLAUDE.md`, `openspec/project.md`
- Root `*_convention.md`

**For each match**: read the line to confirm it's actual residue (not a code-block citation of the rename). Distinguish:

- **Genuine residue** in spec body → WARNING (file:line + rename context + recommendation to delta the file in a future change OR apply a hotfix commit).
- **Residue in governing doc** (`CLAUDE.md`, `project.md`) → CRITICAL (governing docs are followed by future implementers).
- **Documentation of the rename** in a code block or "for example" prose → NOT a finding.

### 5. Category 2 — Lens staleness

**Parse `openspec/lenses/perspectives.md`** for entries. Each perspective references a `<capability>` surface (the system area the perspective applies to).

- For each perspective's surface refs: check `openspec/specs/<capability>/` exists.
- Missing → WARNING (file:line of the perspective entry + recommendation to update or remove).

**Parse `openspec/lenses/critical-paths.md`** for flows. Each flow lists touchpoints (capabilities or tools).

- For each touchpoint: check the corresponding capability/tool exists.
- Missing → WARNING.

Empty or absent lens files → skip Category 2 with the note `lenses empty or absent; skip Category 2`.

### 6. Category 3 — Cross-doc consistency

**Extract structured claims** from `CLAUDE.md`, `openspec/project.md`, and `*_convention.md`. At minimum:

- **Named entities** — capability names, surface names, tool names, file paths mentioned
- **Quantitative claims** — port numbers, counts, version pins, size limits
- **Architectural assertions** — "X talks to Y", "X is the server, Y is the client", "X must be in place before Y"
- **Rules / conventions** — naming patterns, error formats, file-location conventions referenced in non-convention docs

**Pairwise compare** claims across docs AND against current specs (`openspec/specs/`).

- Two docs disagree on the same fact → WARNING (both file:line refs + recommendation to reconcile).
- A governing doc materially disagrees with a current spec → CRITICAL.

### 7. Category 4 — Archive coherence

**Walk archived changes within window** (default last 5; `--since <ref>` overrides):

- List archived changes at `openspec/changes/archive/<YYYY-MM-DD>-<name>/` (upstream's dated archive form) ordered by archive date.
- Take the first N (or all since `<ref>`).

**For each archived change**, compare its spec deltas to live baseline:

- **ADDED requirement** in archived delta but **not present** in `openspec/specs/<capability>/spec.md` → CRITICAL (`sync-specs` propagation failure).
- **REMOVED requirement** in archived delta but **still present** in baseline → CRITICAL.
- **RENAMED FROM** name still appearing in baseline (the rename didn't propagate) → WARNING.

### 8. Apply scorecard rollup

| Dimension | Categories contributing |
|---|---|
| **Completeness** | Category 4 (Archive coherence) |
| **Correctness** | Category 1 (Vocabulary residue), Category 2 (Lens staleness) |
| **Coherence** | Category 3 (Cross-doc consistency) |

### 9. Emit the final assessment

Stock phrasings, context-specific:

| Context | State | Phrasing |
|---|---|---|
| standalone | ≥1 CRITICAL | `X critical issue(s) found.` (no gate mentioned) |
| standalone | Only WARNING/SUGGESTION | `No critical issues. Y warning(s) to consider.` |
| standalone | All clear | `No drift detected.` |
| pre-archive | ≥1 CRITICAL | `X critical issue(s) found. Address before /opsx:archive?` (prompt, not gate) |
| pre-archive | Only WARNING/SUGGESTION | `No critical drift. Y warning(s) to consider. Ready to archive (with noted drift).` |
| pre-archive | All clear | `No drift detected. Ready to archive.` |
| library | any | No standalone final-assessment emitted; findings handed to caller (folded into review report's Coherence dimension). |

### 10. Persist the run summary

Write JSON to:

- **Change-scoped** (library or pre-archive contexts): `openspec/changes/<change-name>/.orbit-runs/audit-drift-<TS>.json`
- **Standalone** (no change context): `openspec/.orbit-runs/audit-drift-<TS>.json` (create `openspec/.orbit-runs/` if needed)

Full schema (fields, types, semantics) lives at `references/run-summary-schema.md` — read that file when composing the summary.

## Output format

Header (`## Audit-drift report` + `Context: <standalone|library|pre-archive>` + depth + flags) → `### Summary` scorecard table grouped by Category and Dimension → `### Findings` grouped by severity (CRITICAL/WARNING/SUGGESTION; each finding `**[Category N] file:line** — title` then `Recommendation: ...`) → `### Stale findings suppressed` (when applicable) → `### Final assessment` (context-specific phrasing; omitted when library context) → `Run summary: <path>` line.

## Worked example (standalone, full depth)

```
## Audit-drift report

Context: standalone
Depth: full
Flags: none

### Summary

| Category | Critical | Warning | Suggestion |
|----------|----------|---------|------------|
| 1 — Vocabulary residue | 0 | 2 | 0 |
| 2 — Lens staleness     | 0 | 1 | 0 |
| 3 — Cross-doc          | 1 | 0 | 0 |
| 4 — Archive coherence  | 0 | 0 | 0 |

Scorecard rollup:

| Dimension    | Critical | Warning | Suggestion |
|--------------|----------|---------|------------|
| Completeness | 0        | 0       | 0          |
| Correctness  | 0        | 3       | 0          |
| Coherence    | 1        | 0       | 0          |

### Findings

#### CRITICAL
- **[Category 3] CLAUDE.md:14** — Claims "all surface tools live under `tools/`"; current spec `openspec/specs/surface-tools/spec.md:8` says they live under `surface/`.
  Recommendation: update CLAUDE.md to match the spec (the spec is canonical).

#### WARNING
- **[Category 1] openspec/specs/host-lifecycle/spec.md:23** — Stale `BridgeServer` reference (renamed to `HostLifecycle` in 2026-03 archived change `rename-bridge-server`).
  Recommendation: delta this file in a future change OR apply a hotfix commit replacing the term.
- **[Category 1] openspec/specs/host-lifecycle/spec.md:71** — Same stale `BridgeServer` reference.
  Recommendation: same as above; both occurrences in this spec.
- **[Category 2] openspec/lenses/perspectives.md:8** — Perspective "API client" references `<api-server>` capability; no `openspec/specs/api-server/` exists.
  Recommendation: rename the surface ref to match the current capability name OR remove the perspective if obsolete.

### Final assessment

1 critical issue(s) found.

Run summary: openspec/.orbit-runs/audit-drift-2026-05-18T15-04-11Z.json
```

## Graceful degradation

- **No `openspec/changes/archive/`** → Category 4 skipped with `no archived changes; skip Category 4`.
- **Empty lenses files** → Category 2 skipped with note.
- **No project/governance docs** (`CLAUDE.md`, `project.md` absent) → Category 3 doc-vs-doc skipped; spec-only checks remain.
- **`--focus <area>` with non-existent target** (e.g., `--focus lenses` but lenses absent) → command exits gracefully with `<focus area> unavailable; nothing to scan`.
