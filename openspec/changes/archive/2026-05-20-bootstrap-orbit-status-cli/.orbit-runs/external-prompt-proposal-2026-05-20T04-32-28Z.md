# External Review: bootstrap-orbit-status-cli (iteration 1)

You are reviewing an OpenSpec change as a second pair of eyes. Your value is your independent take — be thorough; flag anything that looks wrong, inconsistent, or unclear. Don't be charitable to the authoring AI's reasoning.

## Repo

`https://github.com/las-sal/orbit-status`

## Project context (read first)

- `CLAUDE.md` — handoff orientation (if present; not present at the time this prompt was written)
- `openspec/project.md` — project goals + stack (if present; not present at the time this prompt was written)
- `*_convention.md` at repo root — naming, error handling, etc. (if present; not present at the time this prompt was written)
- `openspec/lenses/perspectives.md` — named callers worth validating from (if present; not present at the time this prompt was written)
- `openspec/lenses/critical-paths.md` — user flows worth walking end-to-end (if present; not present at the time this prompt was written)
- `openspec/changes/bootstrap-orbit-status-cli/.orbit-runs/` — iteration history; see what's already been addressed in prior cycles

This is a greenfield project (orbit-status, a status CLI for openspec-orbit projects). No archived baseline specs exist; `openspec/specs/` is empty at the time of this review.

## Cycle context

- **Iteration**: 1 (first external review for this change in proposal mode)
- **Prior internal review iterations**: 2 (review-proposal at 2026-05-19T21:12:02Z and 2026-05-20T02:57:02Z). Iter 2 used `--mark` to drop `@review:` markers; iter 1 did not.
- **Prior internal findings still open** (4 SUGGESTIONs from iter 2 not addressed by address-reviews):
  - `specs/orbit-status-recommendation/spec.md` — Multi-change tie-break on equal `last_touched` mtimes unspecified
  - `specs/orbit-status-phase-model/spec.md` — `next_unchecked` extraction logic underspecified for malformed `tasks.md` lines
  - `tasks.md` — 76 tasks across 18 groups; chunking-for-apply note recommended
  - `design.md` — "Open Questions" has 3 unresolved items at proposal time
- **Prior external findings still open**: 0 (none yet)
- **Resolved since last internal review** (6 WARNINGs, resolved via address-reviews-2026-05-20T03-51-14Z):
  - Edge case for both `explore.md` AND `changes/<name>/` existing (mid-promotion state) — added precedence preamble + scenario
  - "most recent JSON" timestamp source ambiguity — specified ISO-8601 in filename
  - "one-screen" definition — applied soft-target language ("designed to fit ~24 lines, MAY exceed, MUST NOT truncate")
  - Error paths not specified — added new "Error handling" requirement to orbit-status-output with 3 scenarios
  - `--limit N` edge cases — added scenarios for N=0 and negative N
  - Tier-2 rule 4 "task edit" definition — specified as `tasks.md` mtime

Do not push back on stale findings — pushback discipline is enforced on resolution, not review. Just flag what you observe.

## What to read for THIS review (--as proposal)

- `openspec/changes/bootstrap-orbit-status-cli/proposal.md`
- `openspec/changes/bootstrap-orbit-status-cli/design.md`
- `openspec/changes/bootstrap-orbit-status-cli/tasks.md`
- `openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-output/spec.md`
- `openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-phase-model/spec.md`
- `openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-recommendation/spec.md`
- `openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-distribution/spec.md`
- `openspec/changes/bootstrap-orbit-status-cli/explore.md` (historical record from the explore phase — 20 decisions, references to filed orbit issues `#6`–`#13`)
- `openspec/specs/<capability>/spec.md` (archived baselines — N/A for this change; `openspec/specs/` is empty)

## What to look for

1. **Structure & Delta Integrity** — required artifacts present; ADDED/MODIFIED/REMOVED/RENAMED valid; `openspec validate` would pass.
2. **Internal Coherence** — proposal aligns with design aligns with specs aligns with tasks. Count/label consistency. No scope creep.
3. **Cross-Doc Coherence** — `CLAUDE.md`, `project.md`, `*_convention.md` still accurate after this change. (None of these files exist for this project; pass 3 is mostly a no-op except for `explore.md` ↔ specs/design alignment, which IS a useful cross-doc check here.)
4. **Archive Consistency** — ADDED don't contradict baseline; RENAMED FROM names exist; REMOVED not still referenced. (No archived baseline for this change; pass 4 is a no-op.)
5. **Codegen Readiness** — no implicit requirements; no decisions left to codegen; no ambiguity. Two implementers should produce equivalent code from the specs alone.
6. **Gap Hunt** — could a fresh AI implement this from these specs alone? Unstated assumptions? Error paths? State transitions? Edge cases? Concurrency? Resource limits?
7. **Drift Hunt** — old vocabulary lingering; consistency with `*_convention.md`. (Greenfield; little drift surface, but check for internal vocabulary consistency: `orbit-status` vs `opsx-status` vs `/opsx:status` are intentionally different per the "Four named surfaces" decision — verify the change uses each consistently in its appropriate context.)
8. **Inline Review Marker Residue** — any `@review:` markers still present in the artifacts (must be addressed before apply)? (Iter-1 address-reviews resolved all 6 marked findings; sweep to confirm clean.)
9. **Pre-Handoff Sweep** — anything else before shipping? Awkward wording, inconsistent capitalization, examples that don't match prose, stale TODO/FIXME, etc.

## Output format — write to:

`openspec/changes/bootstrap-orbit-status-cli/.orbit-runs/external-proposal-<TS>.md`

(Where `<TS>` is today's timestamp in ISO format. Pick a fresh timestamp so this file doesn't overwrite prior reviews.)

Use this exact markdown structure:

```markdown
# External Review: bootstrap-orbit-status-cli (iteration 1)

**Reviewer**: <your model name>
**Date**: <YYYY-MM-DD>

## CRITICAL

### <Finding title>
**File**: <path>:<line>
**Description**: <what's wrong + specific recommendation>

(For each additional CRITICAL finding, repeat the `### <Title>` + `**File**:` + `**Description**:` triple. Use `None.` as a single-word body if there are no findings at this severity.)

## WARNING

### <Finding title>
**File**: <path>:<line>
**Description**: <what's wrong + specific recommendation>

(Same shape as CRITICAL. Use `None.` if no findings.)

## SUGGESTION

### <Finding title>
**File**: <path>:<line>
**Description**: <what's wrong + specific recommendation>

(Same shape. Use `None.` if no findings.)

## Notes

<Optional: overall impression, broader concerns. Omit the whole `## Notes` section if you have nothing to add.>
```

If your environment doesn't support file writes (chat-only interface), output the markdown directly and the user will save it.

## After completing the review

1. **Output the full findings markdown in chat** — in addition to writing the findings file, output the COMPLETE findings markdown in this chat. Same content as the file: every severity section (`## CRITICAL` / `## WARNING` / `## SUGGESTION`), every `### Title` entry, every `**File**:` and `**Description**:` field. Do NOT abbreviate or summarize — the chat output is the immediately-visible read for the user (they should be able to evaluate every finding without opening the file). The file remains the canonical record for `--from-file` parsing.

2. **Commit and push the findings file** (if your environment supports git):

   ```bash
   git add openspec/changes/bootstrap-orbit-status-cli/.orbit-runs/external-proposal-<TS>.md
   git commit -m "External review (proposal, iter 1): bootstrap-orbit-status-cli

   <one-line summary: severity counts + headline finding if any>"
   git push
   ```

If you don't have git access, just output the findings markdown in this chat (per the chat-only fallback above) and the user will commit it manually.
