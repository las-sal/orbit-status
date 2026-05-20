---
name: openspec-address-reviews
description: "Resolve `@review:` markers anywhere in the repo (or external-review findings via `--from-file`) by walking each through pushback → classify → fix → ripple-flag → remove-marker. Use after `/opsx:review --mark` drops markers, after an external AI returns findings, or any time the repo has accumulated `@review:` annotations."
license: MIT
compatibility: Requires openspec CLI. Ingests findings files written by `/opsx:review-external`. Pairs with `/opsx:review --mark` (which writes markers).
metadata:
  author: openspec-orbit
  version: "0.1"
  capability: orbit-address-reviews
---
Resolve `@review:` markers across the repo (or external-review findings from a file) with pushback discipline. The lean v1 lifecycle: **discover → triage → walk → ripple flag → report**. Markers are removed from their source files on resolution (the marker-removal invariant) so they don't leak into canonical artifacts.

**Generates resolutions; does not generate findings.** This is the counterpart to `/opsx:review`. Primary use case: close the cross-AI review cycle by ingesting external-AI findings via `--from-file`. Secondary use case: walk repo-scanned inline `@review:` markers with structured pushback.

**Input**: Optional scope (path or pattern) and optional flags. Default: whole-repo scan with safe exclusions.

## Three execution disciplines (apply throughout this command)

**Pushback (review-time). Primary discipline for this command.** Before fixing any marker, verify the claim against current state. Procedure:

1. Identify the marker's referenced symbol, name, or concept.
2. `grep -rn` for current presence in expected locations (the file the marker is in, related files, baseline specs).
3. If the symbol is absent where the marker expects it, run `git log -S "<symbol>" --since=<window>` (default: since the marker file's last modification) to confirm intentional removal.
4. Read the relevant file's current content.
5. Compare to the marker's claim and decide: **still applies** / **already fixed** / **partially applies**.
6. On already-fixed, report the commit hash or current-content evidence as part of suppression.

Do NOT re-edit already-fixed state. Stale markers get removed without further edit, with an evidence note in the resolution log.

**Read-before-reference (authoring-time)**. When a marker resolution edits a file (trivial fix or applied decision), reference the actual current content of the file — read first. Don't assume the structure based on what the marker text describes; the file may have evolved since the marker was placed. Re-read after any edit cycle to confirm the change landed correctly.

**Change completeness (modification-time)**. When a marker's resolution touches related artifacts (e.g., resolving a spec marker has downstream design.md / proposal.md implications), surface those as **ripple-flagged files** (Step 5 below). v1 does NOT auto-cascade — the user gets a list of files to check, not silent edits. After mechanical replacement (e.g., a find-replace as part of a trivial fix), sweep for residue: doubled words, broken references, content overwrites. Known residue must not be left for a downstream review to catch.

## Steps

### 1. Discover (or ingest)

**Default — whole-repo scan**:

```bash
grep -rn --include='*' "@review:" . \
  | grep -v '/.git/' \
  | grep -v '/node_modules/' \
  | grep -v '/dist/' \
  | grep -v '/build/'
```

Safe exclusions: `.git/`, `node_modules/`, `dist/`, `build/`. Other common build dirs may be added per project (`.next/`, `target/`, etc.).

**Scoped scan — `<scope>` positional argument**:

```bash
grep -rn "@review:" <scope> | grep -v <safe-exclusions>
```

`<scope>` accepts a path, a pattern, or a change name (heuristic: if it matches `openspec/changes/<name>/` or `openspec list --json` output, scope to that directory).

**`--from-file <path>` ingest** (external review findings):

Parse the file's markdown structure into virtual markers per the parser contract at `references/external-findings-format.md`. Read that file when implementing the parser — it specifies the exact expected format (produced by `/opsx:review-external`), the virtual-marker construction rules, and the strict/lenient split for malformed input handling.

Virtual markers walk the same lifecycle as inline markers, with one exception: **the marker-removal step (Step 3d below) is a no-op for virtual markers** — there's no source-file marker text to delete.

### 2. Triage

Present discovered markers (or parsed virtual markers) as a numbered list:

```
Found 12 markers in scope:

  1. openspec/changes/foo/proposal.md:41 — "@review: should this be five or four?"
  2. openspec/changes/foo/design.md:159  — "@review: 9 vs 8 after merge"
  3. src/api/auth.ts:88                   — "// @review: token TTL configurable per env?"
  ...
 12. (external) proposal.md:33            — [CRITICAL] orbit-conventions bullet omits three disciplines
```

Mark external-sourced entries explicitly (`(external)` prefix). Use **AskUserQuestion** to let the user scope:

- Walk all (default)
- Walk a subset (e.g., "1-3, 7, 9-12")
- Walk only critical (when `--from-file` source provides severities)
- Cancel

### 3. Walk each marker

For every marker in the chosen scope, execute the lifecycle below sequentially.

#### 3a. Apply pushback (primary discipline above)

Run the verification procedure. Determine: still applies / already fixed / partially applies.

#### 3b. Classify

Apply heuristics in order:

1. **stale** — pushback determined the issue is already resolved at HEAD. Skip directly to 3d (remove + log as ⚠ Stale).
2. **trivial fix** — single-line edit or a few-line localized edit with one obvious correct answer (no design implication, no scope question, no ambiguity in intent). Proceed to 3c without `AskUserQuestion`.
3. **decision required** — resolution requires ambiguity resolution, a design choice between defensible alternatives, a scope decision, or has implications beyond the immediate location. Surface 2–4 concrete options via **AskUserQuestion** (not open-ended).
4. **unresolvable** — resolution needs information not currently available (deferred decision, future capability, blocked on external input). Default: file as a task in `tasks.md` (proceed to 3d with action "filed as task"). Alternatives via **AskUserQuestion**: convert to `@todo: <content>`, escalate to `@review(escalated): <content with explanation>`.

#### 3c. Apply the fix

- **trivial fix**: apply the edit. Re-read the file after to confirm.
- **decision required**: apply the user's chosen option.
- **unresolvable (default)**: append a task to `openspec/changes/<change>/tasks.md` (or repo-level `TODO.md` if no change context); task text is the marker's content + ripple-flag context.
- **unresolvable (`@todo:` or `@review(escalated):`)**: replace the marker text in place (do NOT remove — the new form persists as future signal).

#### 3d. Remove the marker (invariant)

Unless `--keep-resolved-markers` is set, delete the original `@review: <text>` from its source file:

- **Markdown**: remove the marker text. If it was the only content on a line, remove the line.
- **Source code (C-style)**: remove just the marker text. If the comment now contains only whitespace or the comment delimiters (`//`, `/* */`), remove the whole comment.
- **Source code (hash)**: same as C-style for `# @review:` comments.
- **External (virtual marker)**: no-op — there's no source text to remove. Log as resolved.

For `unresolvable` conversions (`@todo:` / `@review(escalated):`), the marker is **transformed** in place rather than removed; this is still considered "resolution" for log purposes.

`--keep-resolved-markers` flag: skip the removal step entirely. Debug use only — markers persist after resolution.

#### 3e. Ripple flag (no auto-cascade in v1)

If the resolution edited a normative artifact (proposal, design, spec, tasks, explore.md), compute potentially-affected related files:

- Sibling specs in the same change directory
- `CLAUDE.md`, `openspec/project.md`, root `*_convention.md`
- `openspec/lenses/perspectives.md`, `openspec/lenses/critical-paths.md`

**Do NOT flag**: baseline specs at `openspec/specs/<capability>/` (that's `/opsx:apply` + `sync-specs` territory), source code (same reason), `.git/` and build dirs.

The ripple-flagged files are listed in the resolution log entry, NOT auto-edited. v1 design choice — user re-runs the command or fixes manually.

### 4. (Internal — Step 3 runs inside this loop)

Iteration. After all markers in scope have walked Step 3, proceed to reporting.

### 5. Report — emit the resolution log

Resolution log is NOT a 3-dimension scorecard. Output structure:

```
## Address-reviews report

Source: <whole-repo | scope <path> | --from-file <path>>
Markers found: <N>
Markers walked: <M> (subset specified: <yes/no>)

### Summary

| Status        | Count |
|---------------|-------|
| ✓ Resolved    | 5     |
| ⚠ Stale       | 2     |
| ⏸ Deferred    | 1     |
| ✗ Escalated   | 1     |

### ✓ Resolved
- **openspec/changes/foo/proposal.md:41** — `@review: five or four?`
  Action: applied trivial fix (`five` → `four` + added explicit list).
  Ripple: design.md, README.md flagged for sibling consistency.

- **src/api/auth.ts:88** — `// @review: token TTL configurable per env?`
  Action: applied user-selected option B (env-var override with default).
  Ripple: src/api/auth.test.ts flagged.

### ⚠ Stale
- **openspec/changes/foo/design.md:159** — `@review: 9 vs 8 after merge`
  Evidence: already corrected in commit abc1234. Marker removed without edit.

### ⏸ Deferred (filed as tasks / converted)
- **openspec/changes/foo/proposal.md:88** — `@review: caching scope`
  Action: filed as task `tasks.md` 10.5; marker removed.

### ✗ Escalated
- **openspec/changes/foo/design.md:204** — `@review: blocking on legal decision re: data retention`
  Action: converted to `@review(escalated): blocking on legal decision re: data retention (escalated 2026-05-18 — see explore.md)`.

### Final assessment

0 unresolved inline markers remaining in scope.
1 escalated marker deliberately persisted.
Suggested next: re-run /opsx:review --as proposal to confirm clean baseline.
```

The final-assessment line summarizes remaining-in-scope markers (0 if clean) plus any deliberately persisted escalations, and suggests the next command.

### 6. Persist the run summary

Write JSON to:

- **Change-scoped** (when scope is a single change directory or `--from-file` points into a change's `.orbit-runs/`): `openspec/changes/<change-name>/.orbit-runs/address-reviews-<TS>.json`
- **Whole-repo / cross-change**: `openspec/.orbit-runs/address-reviews-<TS>.json`

Full schema (fields, types, semantics) lives at `references/run-summary-schema.md` — read that file when composing the summary.

## Marker syntax across file types

The command recognizes these marker forms uniformly:

| Context | Form |
|---|---|
| Markdown | `@review: <text>` (bare) |
| C-style code (TS/JS/Go/Rust/C/C++/Java) | `// @review: <text>` or `/* @review: <text> */` |
| Hash-comment files (Python/Ruby/shell/YAML/TOML) | `# @review: <text>` |

Adjacent forms (same discovery grep, different semantics):

| Marker | Meaning | Handled by this command? |
|---|---|---|
| `@review: <text>` | Needs review/decision | Yes — full lifecycle |
| `@review(escalated): <text>` | Escalated, awaiting human | Yes — listed in resolution log; NOT auto-walked unless explicitly scoped |
| `@todo: <text>` | Known follow-up work, NOT a review item | No — out of scope |

## Constraints

- **Never write new `@review:` markers.** Only `/opsx:review --as proposal --mark` does that. address-reviews can transform markers (e.g., to `@todo:` or `@review(escalated):`) but never creates fresh `@review:` markers.
- **No auto-cascade in v1.** Ripple-flagged files are listed, not edited. v2 may add `--cascade` (issue #3).

## Worked example (--from-file ingest, iter 5 of bootstrap-openspec-orbit)

```
## Address-reviews report

Source: --from-file openspec/changes/bootstrap-openspec-orbit/.orbit-runs/external-proposal-2026-05-18T14-35-23Z.md
External reviewer: Claude Opus 4.7 (fresh-context in-session subagent — iter 5)
Input findings: 0 CRITICAL / 4 WARNING / 5 SUGGESTION
Markers walked: 9 (all)
Pushback verification: all 9 verified against current state; 0 stale suppressions.

### Summary

| Status        | Count |
|---------------|-------|
| ✓ Resolved    | 9     |
| ⚠ Stale       | 0     |
| ⏸ Deferred    | 0     |
| ✗ Escalated   | 0     |

### ✓ Resolved
- **proposal.md:41** — [WARNING] "five new SKILL.md + command body pairs" should be four.
  Action: trivial fix — changed "five" to "four" + added explicit list.
  Ripple: design.md, README.md flagged.

- **design.md:159** — [WARNING] "9 capability specs" should be 8 after merge.
  Action: trivial fix — changed 9 to 8 with parenthetical merge context.

- **sketches/review.md:3** — [WARNING] corrupted filenames (sed residue from rename).
  Action: trivial fix — restored proper filenames.

- (6 more, all trivial fix or applied decision)

### Final assessment

0 unresolved external findings.
Suggested next: re-run /opsx:review --as proposal to confirm convergence.

Run summary: openspec/changes/bootstrap-openspec-orbit/.orbit-runs/address-reviews-2026-05-18T14-43-41Z.json
```

## Graceful degradation

- **No markers found** → emit `No @review: markers in scope. Nothing to do.` and exit clean.
- **`--from-file` path missing** → fail clearly with usage; don't fall back to repo scan.
- **`--from-file` parse failure** → emit format guidance; do not act on partial parse.
- **No `tasks.md` in change context** → unresolvable-default-file-as-task falls back to creating a root-level `TODO.md` entry with a note.
- **Marker found in a baseline spec** (`openspec/specs/<capability>/`) → warn that this is unusual; baseline specs should not carry markers; still walk it per user choice but flag in the log.
