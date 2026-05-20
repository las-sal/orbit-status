# External Review: bootstrap-orbit-status-cli (system mode, iteration 1)

You are reviewing an OpenSpec change as a second pair of eyes. Your value is your independent take — be thorough; flag anything that looks wrong, inconsistent, or unclear. Don't be charitable to the authoring AI's reasoning. This is a **system-mode review** (post-apply) — you're reviewing the implemented system, not just artifacts.

## Repo

`https://github.com/las-sal/orbit-status`

## Project context (read first)

- `CLAUDE.md` — handoff orientation (if present; absent for this project)
- `openspec/project.md` — project goals + stack (if present; absent for this project)
- `*_convention.md` at repo root — naming, error handling, etc. (if present; absent for this project)
- `openspec/lenses/perspectives.md` — named callers worth validating from (if present; **absent** for this project — Pass 4 will skip)
- `openspec/lenses/critical-paths.md` — user flows worth walking end-to-end (if present; **absent** for this project — Pass 5 will skip)
- `openspec/changes/bootstrap-orbit-status-cli/.orbit-runs/` — iteration history; see what's already been addressed in prior cycles
- `README.md` — what orbit-status is, install path, sample outputs (States A/B/C), JSON schema reference

This is a **greenfield project** (orbit-status, a status CLI for openspec-orbit projects). No archived baseline specs exist; `openspec/specs/` is empty at the time of this review. Pass 1 (Baseline Compliance) is degenerate.

## Cycle context

- **System-mode iteration**: 1 (first external system-mode review for this change)
- **Prior proposal-mode iterations**: 5 total
  - 3 internal review-proposal runs (iter-1, iter-2 with `--mark`, iter-3 with `--fresh`)
  - 1 external review-proposal (Codex GPT-5, iter 1, 0 critical / 4 warning / 5 suggestion)
  - All 9 findings resolved via address-reviews iter-1 + iter-2 + iter-3 manual ripple/suggestion cleanup
- **Internal system-mode iterations**: 1
  - 1 internal review-system run (iter-1, **in-context — same AI authored the code**, 0 critical / 2 warning / 3 suggestion). Findings: test coverage gap (~30/45 scenarios), line-count drift, in-context anchoring noted explicitly. All resolved or tracked (test coverage tracked as `las-sal/orbit-status#1`; line-count drift fixed in design.md + SKILL.md).
- **Total address-reviews iterations**: 3
- **Prior external findings still open**: 0
- **Prior internal findings still open**: 0
- **Resolved since iter-1 internal system review**: 5 findings (W1 test coverage → orbit-status#1; W2 line-count drift → fixed both files; S1/S2/S3 informational)

**Anchoring caveat the iter-1 internal review explicitly flagged**: the in-context AI wrote all 1186 lines of `.claude/skills/openspec-status/bin/opsx-status` plus the 528-line test suite, then reviewed it in-context. That review's finding S3 recommended exactly this external pass to catch what anchoring suppressed. **Your job is to be the fresh eyes that finds what in-context attention missed.**

Do not push back on stale findings — pushback discipline is enforced on resolution, not review. Just flag what you observe.

## What to read for THIS review (--as system)

- `openspec/changes/bootstrap-orbit-status-cli/proposal.md`
- `openspec/changes/bootstrap-orbit-status-cli/design.md`
- `openspec/changes/bootstrap-orbit-status-cli/tasks.md`
- `openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-output/spec.md`
- `openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-phase-model/spec.md`
- `openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-recommendation/spec.md`
- `openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-distribution/spec.md`
- **Implementation**: `.claude/skills/openspec-status/bin/opsx-status` (1186 lines bash; the heart of the system)
- **Skill markdown**: `.claude/skills/openspec-status/SKILL.md` (flag surface, JSON schema, interpretation rules)
- **Slash command**: `.claude/commands/opsx/status.md` (interpretation guidance for `/opsx:status`)
- **Tests**: `tests/run.sh` (~528 lines bash, 93 passing assertions, 6 fixture shapes)
- **README**: `README.md` (user-facing docs, sample outputs)
- **Commit range**: `git log 9cc2eb5..HEAD` (the full development arc; ~11 commits from initial scaffold through close of iter-1 system review)

## What to look for (system mode — 7 passes)

0. **verify-change-style structural check** — tasks done (75/79; 4 are explicit user-driven validation per group 18 — acceptable), spec coverage (every requirement traced to implementation site), design adherence (single-file bash + jq preserved; line count exceeded original estimate — see design.md for rationale). Run your own independent verification, don't just trust the iter-1 internal review.

1. **Baseline Compliance** — does this change break any archived `openspec/specs/` requirement? **DEGENERATE** for this project (greenfield, no baseline). Skip with note: "no baseline to check against."

2. **Cohesion** — callers/dependents the change touched. Walk:
   - `.claude/commands/opsx/status.md` references the binary at `.claude/skills/openspec-status/bin/opsx-status` — verify path and instruction-to-shell-out are correct
   - `.claude/skills/openspec-status/SKILL.md` documents the binary surface — verify accuracy (flags, JSON schema, exit codes)
   - `README.md` references the binary and documents install path — verify it's actionable

3. **Surface Walk** — every CLI flag / public function / capability surface in `openspec/specs/` still coherent? Capabilities ARE surfaces; don't redefine them. Check each of:
   - `orbit-status-output` (8 requirements / 18 scenarios) — `--detail`, `--json`, `--change`, `--limit`, error handling, archived_at, next_unchecked, default human view
   - `orbit-status-phase-model` (3 requirements / 10 scenarios) — phase enum closed, inference precedence, attention typed array
   - `orbit-status-recommendation` (4 requirements / 9 scenarios) — 3-tier hierarchy, tier-2 ruleset, multi-change ranking, focus block field shape
   - `orbit-status-distribution` (4 requirements / 8 scenarios) — install location, is_orbit_project detection, plain-openspec degradation, four-surface naming

4. **Perspective Reviews** — `openspec/lenses/perspectives.md` absent; **skip** with note: "no perspectives defined; skip Pass 4."

5. **Critical-Path Scan** — `openspec/lenses/critical-paths.md` absent; **skip** with note: "no critical paths defined; skip Pass 5."

6. **Drift / Residue** — vocabulary residue, stale references, archive-coherence misses. Specifically check:
   - Line-count claims now reflect reality (1186 lines)? (iter-1 internal review fixed this; verify no stragglers)
   - `verify-change` vs `/opsx:verify` references — should distinguish the upstream skill name from the orbit slash command
   - Tier-2 ruleset references — should consistently say "4 rules" (not "5") after the address-reviews resolution that moved marker handling to tier 1
   - "Applying-ing" template bug — fixed in chunk 3; verify no residue in any docs

## Specific areas worth extra attention

Given this is the first external system-mode review and the iter-1 internal review explicitly flagged in-context anchoring, the following are likely to surface fresh issues:

1. **Bash code quality** — 1186 lines is non-trivial for a single bash file. Look for: function naming consistency, error path handling, edge cases in argument parsing, jq subprocess overhead, cross-platform issues (BSD vs GNU `stat` is handled but other tools may differ).

2. **Spec-vs-implementation drift** — the iter-1 internal review traced every requirement to an implementation site but did so in-context. A fresh independent walk could surface scenarios the spec asserts but the code doesn't actually implement.

3. **JSON schema robustness** — the schema is documented in README + SKILL.md + spec; the actual JSON emitted should match. Run the binary against a few fixtures and check the JSON output's structural agreement with the documented schema.

4. **Test coverage trade-offs** — `orbit-status#1` tracks the ~15 untested scenarios. Independent assessment: are the right scenarios tested? Is the coverage gap defensible for v0.1, or are some untested scenarios actually load-bearing?

5. **README accuracy** — does the README correctly describe how to install, run, and interpret the output? Try following the quick-start instructions and see if anything is missing or misleading.

6. **Cohesion between layers** — the slash command markdown describes interpretation rules; the SKILL.md describes the surface; the binary implements the behavior. Do these three layers fully agree, or are there inconsistencies?

## Output format — write to:

`openspec/changes/bootstrap-orbit-status-cli/.orbit-runs/external-system-<TS>.md`

(Where `<TS>` is today's timestamp in ISO format. Pick a fresh timestamp so this file doesn't overwrite prior reviews.)

Use this exact markdown structure:

```markdown
# External Review: bootstrap-orbit-status-cli (system mode, iteration 1)

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
   git add openspec/changes/bootstrap-orbit-status-cli/.orbit-runs/external-system-<TS>.md
   git commit -m "External review (system, iter 1): bootstrap-orbit-status-cli

   <one-line summary: severity counts + headline finding if any>"
   git push
   ```

If you don't have git access, just output the findings markdown in this chat (per the chat-only fallback above) and the user will commit it manually.
