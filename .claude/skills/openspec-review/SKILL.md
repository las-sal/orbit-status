---
name: openspec-review
description: "Editorial review of an OpenSpec change in either proposal mode (pre-apply, 9 passes over artifacts) or system mode (post-apply, verify-change + 6 system-wide passes). Use when the user wants a second-pair-of-eyes pass before applying or archiving."
license: MIT
compatibility: Requires openspec CLI. System-mode Pass 0 invokes upstream `openspec-verify-change` skill. System-mode Pass 6 invokes orbit's `openspec-audit-drift` skill.
metadata:
  author: openspec-orbit
  version: "0.1"
  capability: orbit-review
---
Run an editorial review of an OpenSpec change. Two modes: `--as proposal` reviews pre-implementation artifacts (9 passes); `--as system` reviews the whole product state after apply (verify-change as Pass 0 + 6 system-wide passes). Both modes share the 3-dimension scorecard (Completeness / Correctness / Coherence), the severity ladder (CRITICAL / WARNING / SUGGESTION), pushback discipline, and `.orbit-runs/` persistence. They differ on which passes run, which gate the final-assessment references (`/opsx:apply` vs `/opsx:archive`), and a few mode-specific flags (`--mark` for proposal, `--skip-verify` for system).

**Generates findings; does not resolve them.** Resolution flows through `/opsx:address-reviews` (inline `@review:` markers or `--from-file` external findings) or by the user replying directly to the report.

**Input**: Optional change name and optional `--as proposal|system` mode flag plus secondary flags. If change name omitted, prompt via `AskUserQuestion` over `openspec list --json`. If mode omitted, infer from `tasks.md` state (see Step 3).

## Three execution disciplines (apply throughout this command)

These three disciplines are embedded in every orbit command as a self-contained reminder. They bracket the authoring lifecycle (authoring-time / modification-time / review-time) and combine with the per-command behavior below. Intentional text duplication across SKILL.md files is the price for self-contained reliability.

**Read-before-reference (authoring-time)**. When you author a finding that names a specific construct — a function, type, interface, field, file path, spec requirement name, CLI flag, capability name — read the actual definition first. Use `Read`, `grep`, or `openspec instructions` as appropriate. Do NOT assume the shape based on common patterns or training-data conventions. A finding that says `"foo.ts:42 declares getUser() returning Promise<User>"` must be backed by an actual file read; otherwise the recommendation is unverifiable and the user has no way to trust the report. If you can't verify the reference, downgrade the severity or omit the finding.

**Change completeness (modification-time)**. The `--mark` flag (proposal mode) modifies artifacts by writing `@review:` markers based on findings. When `--mark` runs, apply the markers fully across all affected artifacts in one pass. After mechanical insertion, sweep for residue (markers landed in the wrong place; markers that overwrite existing content; doubled markers). Do NOT leave the user to clean up partial marker placement. For the non-`--mark` path this discipline rarely applies (review is read-only), but if a stale `.orbit-runs/` file or partial prior run is discovered, clean it before persisting the new summary.

**Pushback (review-time)**. **Primary discipline for this command.** Before reporting a finding, verify it against current state. Use `grep`, file inspection, or `git log` to confirm the issue still applies. Stale findings (issue already fixed) get suppressed with an explanatory note (`stale finding suppressed: <evidence>`) and not surfaced in the user-facing report. Do NOT re-flag already-fixed state. When prior `.orbit-runs/review-<mode>-*.json` summaries exist, compare to surface only what's new or unresolved.

## Steps

### 1. Resolve the change

If a change name is provided, use it. Otherwise:
- Run `openspec list --json` to get available changes.
- Use the **AskUserQuestion tool** to let the user select.
- Mark changes with incomplete tasks as `(In Progress)`.

Always announce `Using change: <name> --as <mode>` at the start of the report header.

### 2. Resolve the mode

Mode comes from the `--as proposal|system` flag if specified. If omitted, infer:

1. Read `openspec/changes/<name>/tasks.md`.
2. Count `- [ ]` (unchecked) vs `- [x]` (checked) boxes.
3. **All unchecked** → infer `proposal`.
4. **All checked + repo has code changes since the change was proposed** (use `git log --oneline -- openspec/changes/<name>/` and `git diff` heuristics) → infer `system`.
5. **Mixed or ambiguous** → use `AskUserQuestion` to ask the user which mode to run.

State the resolved mode and how it was resolved in the report header (`Mode: proposal (inferred from 12 unchecked tasks)`).

### 3. Resolve flags

| Flag | Default | Effect |
|---|---|---|
| `--fast` / `--full` / `--thorough` | `--full` | Depth. Mutually exclusive. `--thorough` is partially specified (see issue #2); fall back to `--full` if unclear. |
| `--parallel` | off | Spawn subagents for heavy passes. Proposal: parallelize Passes 2, 4, 6. System: parallelize Passes 2, 3, 4, 5. |
| `--focus <lens>` | none | Emphasize specific passes (additive — does not skip others). See "Special-case lenses" below. |
| `--strict` | off | Fail-fast on first CRITICAL. Useful for CI-like runs. |
| `--fresh` | off | Spawn a clean-context subagent for the main pass work. Useful when current conversation has accumulated anchoring. |
| `--mark` | off, proposal only | After report, write `@review: <text>` markers at each finding's file:line. See "Mark writer". |
| `--skip-verify` | off, system only | Skip Pass 0 (verify-change). Use when verify-change was run separately. |

If a flag is specified for the wrong mode (e.g., `--mark` in system mode or `--skip-verify` in proposal mode), accept it silently and emit a one-line note in the report (`Note: --mark writes to source files is v2 — see issue #3; ignored for v1 system-mode runs.`).

### 4. Load context

Use the openspec CLI as source of truth:

```bash
openspec status --change "<name>" --json
openspec instructions apply --change "<name>" --json
```

From the returned `contextFiles`, read every artifact: `proposal`, `design`, `tasks`, all paths under `specs`. Also read:
- `openspec/changes/<name>/explore.md` if present
- `openspec/changes/<name>/sketches/` if present
- Project context: `CLAUDE.md` (root), `openspec/project.md`, any `*_convention.md` at project root
- Baseline: `openspec/specs/*/spec.md`
- Orbit lenses: `openspec/lenses/perspectives.md`, `openspec/lenses/critical-paths.md` (system mode primarily; proposal mode uses for cross-doc checks)

System mode also reads:
- `git diff <change-start>..HEAD` (estimate `<change-start>` from `git log` against `openspec/changes/<name>/`)
- Code paths around the change (cohesion + surface walks)

### 5. Inspect prior runs

Check `openspec/changes/<name>/.orbit-runs/` for prior `review-<mode>-*.json` summaries:

- Count matching the current mode → iteration number (1 if none).
- Load the most-recent matching summary to identify open vs resolved findings since last run.
- This data fuels the iteration note (Step 8) AND the pushback discipline (suppress findings already resolved).

### 6. Run passes

Run the mode-specific pass set sequentially (or in parallel for the marked passes when `--parallel` is on). For each pass:

1. Apply the read-before-reference discipline to every cited construct.
2. Apply the pushback discipline against current state.
3. Emit findings tagged CRITICAL / WARNING / SUGGESTION with file:line + actionable recommendation.

#### Proposal-mode passes (9)

```
PASS                                  WHAT IT CHECKS
─────────────────────────────────────────────────────────────────────
1. Structure & Delta Integrity        artifacts present; delta sections valid;
                                       openspec validate passes
2. Internal Coherence                 proposal/design/specs/tasks align;
                                       counts consistent; no scope creep
3. Cross-Doc Coherence                CLAUDE.md / project.md / *_convention.md
                                       still accurate after this change
4. Archive Consistency                ADDED don't contradict baseline; RENAMED
                                       FROM exists; REMOVED not still referenced
5. Codegen Readiness                  no implicit requirements; no ambiguity;
                                       no decisions left to codegen
6. Gap Hunt (generative completeness) could a fresh AI implement this from
                                       these specs alone? unstated assumptions?
                                       error paths? state transitions?
7. Drift Hunt                         old vocabulary lingering; consistency
                                       with *_convention.md
8. Inline Review Marker Residue       any @review: markers still present?
                                       (CRITICAL — must address before apply)
9. Pre-Handoff Sweep                  small things missed on first read
```

**Pass 1 — Structure & Delta Integrity**. Run `openspec validate "<name>"`; confirm required artifacts present; check delta sections (ADDED/MODIFIED/REMOVED/RENAMED Requirements) follow openspec format. CRITICAL on validate failure; WARNING on delta-section anomalies; SUGGESTION on cosmetic issues.

**Pass 2 — Internal Coherence**. Compare proposal / design / specs / tasks: scope alignment, design-to-requirement mapping, requirement-to-task coverage, count consistency, no scope creep. CRITICAL when a spec requirement has no task; WARNING on count/label disagreement.

**Pass 3 — Cross-Doc Coherence**. Will `CLAUDE.md`, `openspec/project.md`, `*_convention.md` files still be accurate post-apply? Look for renamed concepts referenced under old names, new capabilities missing from project context, conventions contradicting deltas. WARNING for stale post-apply context; SUGGESTION for enrichment.

**Pass 4 — Archive Consistency**. ADDED requirements don't conflict with archived baseline; RENAMED FROM names exist in archive; REMOVED requirements aren't still referenced. CRITICAL on direct contradiction; WARNING on dangling references.

**Pass 5 — Codegen Readiness**. Per requirement: precise enough that two implementers produce the same code? Inputs/outputs/side effects stated? Hidden assumptions ("the obvious path", "the usual default") made explicit? WARNING for ambiguity that could split implementations.

**Pass 6 — Gap Hunt (generative completeness)**. Per requirement in spec deltas, probe: (a) unstated assumptions an implementer would have to invent? (b) error/edge-case paths specified, not just happy paths? (c) state transitions explicit, including invalid ones? (d) "X SHALL do Y" — Y precise enough? Cite file:line + the specific gap; suggest concrete spec additions.

**Pass 7 — Drift Hunt**. Search artifacts for old vocabulary the change is replacing. Grep change directory AND project docs (`*_convention.md`, `project.md`, `CLAUDE.md`). CRITICAL when a delta itself uses old vocab; WARNING when project docs do.

**Pass 8 — Inline Review Marker Residue**. Grep change directory for `@review:` markers. **Actual unresolved markers** in artifact content → CRITICAL (must address before applying). **Documentation appearances** inside fenced code blocks, inline-code spans, or explicit "example" prose contexts → NOT findings. When ambiguous, classify as CRITICAL.

**Pass 9 — Pre-Handoff Sweep**. Final read asking "what would I be embarrassed to ship?" — awkward wording, stale TODO/FIXMEs in artifacts, inconsistent capitalization, examples that don't match prose. Almost always SUGGESTION.

##### `--fast` subset (proposal mode)

When `--fast` is set, run only Passes 1, 7, 8. Report remaining passes as `skipped per --fast`.

#### System-mode passes (0–6)

```
PASS                                  WHAT IT CHECKS
─────────────────────────────────────────────────────────────────────
0. verify-change (delegated upstream) tasks done; spec coverage; design
                                       adhered (full verify-change findings)
1. Baseline Compliance                does this change break archived
                                       baseline requirements?
2. Cohesion                           callers/dependents outside the tasks —
                                       signature drift, ripple effects
3. Surface Walk                       every CLI/MCP/HTTP surface still
                                       coherent? (surfaces derived from specs)
4. Perspective Reviews                from each registered caller-perspective
                                       in lenses/perspectives.md
5. Critical-Path Scan                 each flow in lenses/critical-paths.md,
                                       walked end-to-end
6. Drift / Residue                    calls /opsx:audit-drift as a library
```

**Pass 0 — verify-change delegation**. Invoke upstream `openspec-verify-change` via `/opsx:verify <change-name>`. Fold its findings into the scorecard: task-completion + spec-coverage → Completeness; requirement-implementation-mapping + scenario-coverage → Correctness; design-adherence + code-pattern-consistency → Coherence. If `--skip-verify` set, omit Pass 0 with note `Pass 0: skipped per --skip-verify`.

**Pass 1 — Baseline Compliance**. Read every requirement in archived `openspec/specs/*/spec.md` (not just deltas). Does the change break any baseline behavior? CRITICAL on violation; WARNING on regression risk.

**Pass 2 — Cohesion**. Files the change touched (from `git diff` + tasks list). Walk callers/dependents not in the change's tasks for signature drift, semantic shifts, new side effects. CRITICAL when downstream clearly broken; WARNING for contract drift.

**Pass 3 — Surface Walk**. Enumerate surfaces from `openspec/specs/<capability>/spec.md` — **capabilities ARE surfaces**; do not redefine them in lenses. Check each (CLI flags / subcommand names, HTTP routes, MCP tool names, public function signatures) remains coherent after the change. CRITICAL when a surface was removed unintentionally; WARNING for inconsistencies.

**Pass 4 — Perspective Reviews**. If `openspec/lenses/perspectives.md` exists and is non-empty: for each named perspective, simulate typical call patterns from that caller's POV. Flag SUGGESTION/WARNING when interactions are awkward, inconsistent, or surprising from that POV. If the file is empty or absent, skip Pass 4 with the note `no perspectives defined; skip Pass 4`.

**Pass 5 — Critical-Path Scan**. If `openspec/lenses/critical-paths.md` exists and is non-empty: for each named flow, walk the code end-to-end checking for breakage, regression, or drift. CRITICAL for path breakage; WARNING for regression risk. If absent, skip with `no critical paths defined; skip Pass 5`.

**Pass 6 — Drift / Residue**. Invoke `/opsx:audit-drift` as a library function (via the orbit-audit-drift skill). Fold its findings into the report under the Coherence dimension. Audit-drift handles its own scorecard and severity assignment; preserve those.

##### `--fast` subset (system mode)

When `--fast` is set, run Passes 0, 1, 6. Report remaining as `skipped per --fast`. Combining `--fast --skip-verify` runs only Passes 1 and 6.

### 7. Apply scorecard rollup

Roll every pass's findings into the 3-dimension scorecard.

#### Proposal-mode mapping

| Dimension | Passes contributing |
|---|---|
| **Completeness** | 1 (Structure & Delta), 5 (Codegen Readiness), 6 (Gap Hunt) |
| **Correctness** | 2 (Internal Coherence), 4 (Archive Consistency) |
| **Coherence** | 3 (Cross-Doc), 7 (Drift Hunt), 8 (Inline Marker Residue), 9 (Pre-Handoff) |

#### System-mode mapping

| Dimension | Passes contributing |
|---|---|
| **Completeness** | Pass 0 (verify-change completeness portion: task-completion + spec-coverage), Pass 5 (critical-paths existence) |
| **Correctness** | Pass 0 (verify-change correctness portion: requirement-implementation-mapping + scenario-coverage), Pass 1 (Baseline), Pass 2 (Cohesion), Pass 5 (critical-paths working) |
| **Coherence** | Pass 0 (verify-change coherence portion: design-adherence + code-pattern-consistency), Pass 3 (Surface Walk), Pass 4 (Perspective Reviews), Pass 6 (Drift/Residue from audit-drift) |

### 8. Generate the iteration note

If `.orbit-runs/` has prior summaries matching this mode:

- Compare current findings to the most-recent matching prior run.
- Count how many findings repeat (same file:line + same severity + similar title).
- Emit a one-sentence note in the report: `Note: N of these findings appeared in the last run on <date>. M new this run.`

If no prior matching summaries: emit `First <mode>-mode run for this change.` or omit the iteration note entirely.

### 9. Emit the final assessment

Stock phrasings, mode-specific gate text:

| Mode | State | Phrasing |
|---|---|---|
| proposal | ≥1 CRITICAL | `X critical issue(s) found. Fix before /opsx:apply.` |
| proposal | Only WARNING/SUGGESTION | `No critical issues. Y warning(s) to consider. Ready to apply (with noted improvements).` |
| proposal | All clear | `All checks passed. Ready to apply.` |
| system | ≥1 CRITICAL | `X critical issue(s) found. Fix before /opsx:archive.` |
| system | Only WARNING/SUGGESTION | `No critical issues. Y warning(s) to consider. Ready to archive (with noted improvements).` |
| system | All clear | `All checks passed. Ready to archive.` |

### 10. Persist the run summary

Write JSON to `openspec/changes/<name>/.orbit-runs/review-<mode>-<TS>.json` with ISO-8601 timestamp (e.g., `review-proposal-2026-05-18T14-35-23Z.json`). The full schema (fields, types, semantics) lives at `references/run-summary-schema.md` — read that file when composing the summary. Create `.orbit-runs/` if it doesn't exist; commit-worthy (do not gitignore).

### 11. (Optional) `--mark` writer (proposal mode only)

If `--mark` is set and the mode is `proposal`:

For each finding with severity CRITICAL or WARNING (skip SUGGESTION by default):
- Locate the finding's `file:line`.
- Insert a `@review: <finding title — recommendation>` marker at that line.
  - In markdown: append after existing content on the line, or as a sibling line if structure prevents inline insertion.
  - In code: wrap in the file's comment syntax (e.g., `// @review: …`, `# @review: …`).
- After insertion, sweep the modified artifacts for double-insertion or content overwrites; the change-completeness discipline applies.

In system mode, `--mark` is accepted but ignored with the note `--mark writes to source files is v2 — see issue #3; ignored for v1 system-mode runs.`

### 12. `--parallel` execution

If `--parallel` is set:

- Proposal mode: spawn subagents for Passes 2 (Internal Coherence), 4 (Archive Consistency), 6 (Gap Hunt). Run Passes 1, 3, 5, 7, 8, 9 in the main context.
- System mode: spawn subagents for Passes 2 (Cohesion), 3 (Surface Walk), 4 (Perspectives), 5 (Critical Paths). Run Passes 0, 1, 6 in the main context.

Each subagent gets a focused brief (the pass description + the relevant context files). Merge findings into the unified report. Subagents inherit the three execution disciplines.

### 13. `--focus` lens

Lens-specific emphasis (additive — does NOT skip other passes):

| Lens | Mode | Passes emphasized | Why |
|---|---|---|---|
| `rename` | proposal | 7 (Drift), 3 (Cross-Doc), 4 (Archive) | renames leak old names |
| `flip` | proposal | 2 (Internal Coherence on direction), 5 (Codegen Readiness) | direction must be unambiguous |
| `refactor` | both | proposal: 4, 7, 3; system: 2, 6 | old shape ripples into callers/docs |
| `extension` | proposal | 6 (Gap Hunt) | coverage must match existing depth |
| `hotpath` | system | 5 (Critical-Path Scan) | landed work touched perf/race-sensitive paths |

When `--focus <lens>` is set, run all passes but apply elevated rigor (more probes, longer cite chains) to the listed ones.

## Special cases

### Graceful degradation

- **Proposal mode, no `openspec/specs/` baseline** → Pass 4 skipped (`no baseline to check against`); other passes proceed normally.
- **Proposal mode, no `*_convention.md` and no `project.md`** → Pass 3 lens-driven cross-checks skipped; rest of Pass 3 (`CLAUDE.md` checks) still runs.
- **System mode, empty `openspec/lenses/`** → Passes 4 and 5 skipped; Pass 3 still runs against capabilities derived from `openspec/specs/`.
- **System mode, `verify-change` unavailable** → Pass 0 fails with a note; continue with Passes 1–6 and downgrade the assessment to `unable to delegate Pass 0; partial review`.
- **Missing `tasks.md`** → use `AskUserQuestion` for mode rather than inferring.

### Pushback bias

When uncertain, prefer the lower severity. SUGGESTION beats WARNING beats CRITICAL. Pushback against the bias to over-flag — the goal is signal, not volume.

### Read-before-reference enforcement

Every finding that cites a specific file:line must be backed by an actual read of that line. If the citation is inferred (e.g., "I think this is around line 50 of design.md"), either read first or downgrade to a less specific finding ("design.md mentions <topic> but does not specify <X>" — searchable, but no false-precision line number).

## Output format

Header (`## Review: <name> --as <mode>` + mode/iteration/depth lines + optional iteration note) → `### Summary` scorecard table → `### Findings` grouped by severity (CRITICAL/WARNING/SUGGESTION; each finding `**[Pass N] file:line** — title` then `Recommendation: ...`) → `### Stale findings suppressed` (when applicable) → `### Final assessment` (stock phrasing) → `Run summary: <path>` line. See the worked example below for the canonical shape.

## Worked example (proposal mode, partial)

```markdown
## Review: bootstrap-openspec-orbit --as proposal

Mode: proposal (inferred from 102 unchecked tasks)
Iteration: 6 (continuing proposal-mode run)
Depth: full
Note: 3 of these findings appeared in the last run on 2026-05-18. 6 new this run.

### Summary

| Dimension    | Critical | Warning | Suggestion |
|--------------|----------|---------|------------|
| Completeness | 0        | 1       | 2          |
| Correctness  | 0        | 1       | 1          |
| Coherence    | 0        | 2       | 2          |

### Findings

#### CRITICAL
None.

#### WARNING
- **[Pass 2] proposal.md:41** — "five new SKILL.md + command body pairs" — count should be four after iter-4 merge.
  Recommendation: change "five" to "four" and list the four pairs explicitly.

- **[Pass 7] sketches/review.md:3** — corrupted filenames "proposal-mode review.md" + "system-mode review.md" (sed residue).
  Recommendation: restore `sketches/review-proposal.md` + `sketches/review-system.md`.

- **[Pass 4] design.md:159** — "9 capability specs" — should be 8 after merge.
  Recommendation: change "9" to "8" and add the merge context parenthetically.

- **[Pass 3] proposal.md:33** — orbit-conventions capability bullet omits the three disciplines.
  Recommendation: extend the bullet to mention pushback / change-completeness / read-before-reference.

#### SUGGESTION
- **[Pass 9] explore.md:189** — scenario count "5" should be "6" for change-completeness discipline.
- **[Pass 9] explore.md:204** — scenario count "8" should be "9" for read-before-reference discipline.
- **[Pass 5] orbit-review-external/spec.md** — "Recommended-session note" requirement is filed under the wrong parent requirement.
  Recommendation: move it past the prompt-content scenarios.
- (4 more) …

### Stale findings suppressed
None.

### Final assessment

No critical issues. 4 warning(s) to consider. Ready to apply (with noted improvements).

Run summary: openspec/changes/bootstrap-openspec-orbit/.orbit-runs/review-proposal-2026-05-18T14-43-41Z.json
```

