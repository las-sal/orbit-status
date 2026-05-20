# External Review: bootstrap-orbit-status-cli (iteration 1)

**Reviewer**: Codex GPT-5
**Date**: 2026-05-20

## CRITICAL

None.

## WARNING

### Tier-1 string recommendations do not define required command/args
**File**: openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-recommendation/spec.md:7
**Description**: Tier 1 says to read the most recent JSON's `next_recommended` string verbatim, while line 11 requires `recommended_next` to include structured `command`, `args`, and `reason`. The concrete address-reviews JSON in this change has a prose `next_recommended` with two alternatives ("Re-run /opsx:review..." or "proceed to /opsx:apply..."), so an implementer cannot deterministically populate one command/args pair without inventing parsing or priority rules. Specify whether orbit-status should put the verbatim string only in `reason` and leave/derive command fields by a documented rule, require upstream JSON to emit a structured recommendation, or change the schema for tier-1 recommendations.

### Phase precedence contradicts the mid-apply scenario
**File**: openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-phase-model/spec.md:18
**Description**: Rule 2 says the most recent `.orbit-runs/*.json` command type determines phase whenever such JSON exists, before rule 3 can consider partial `tasks.md`. But the "Partial tasks.md triggers applying" scenario expects `applying` when partial tasks exist and no JSON is newer than the `tasks.md` mtime. Under the written precedence, an older `review-*.json` still wins and the change remains `reviewing`. Add the freshness condition to rule 2, move the partial-task rule ahead of stale review JSONs, or otherwise state exactly when task progress supersedes the previous review run.

### Tier-2 review-marker rule is unreachable under the tier definition
**File**: openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-recommendation/spec.md:8
**Description**: Tier 2 only fires when no `.orbit-runs/` exists for the focal change, but tier-2 rule 5 requires a review JSON to exist before recommending `/opsx:address-reviews`. Those conditions cannot both be true, so the unresolved-marker path is not implementable as written. Either narrow Tier 1 to "most recent JSON contains usable `next_recommended`", move unresolved-marker handling into Tier 1 fallback behavior, or delete/replace rule 5.

### recent[] ordering depends on undefined archived_at data
**File**: openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-output/spec.md:61
**Description**: The output spec orders `recent[]` by `archived_at` descending, but the documented `ChangeRecord` fields in design.md only include `last_touched` and do not define `archived_at` or its source. Archived directories may have a dated name, an `archive-*.json` timestamp, and filesystem mtimes, and different choices can produce different ordering. Define `archived_at` as a required field for recent records and specify its source/fallback order.

## SUGGESTION

### Equal last_touched tie-break is still unspecified
**File**: openspec/changes/bootstrap-orbit-status-cli/specs/orbit-status-recommendation/spec.md:41
**Description**: Multi-change focus ranking is deterministic only until two threads have the same `last_touched` timestamp, which can happen on coarse filesystems, scripted fixture setup, or bulk generated changes. Add a tie-break such as lexicographic change name after mtime descending so tests and implementations do not depend on shell `find` order.

### next_unchecked extraction needs a parse rule
**File**: openspec/changes/bootstrap-orbit-status-cli/tasks.md:31
**Description**: `next_unchecked` is required under `--detail`, but neither the task nor the specs define how to extract it from malformed, nested, wrapped, or non-numbered checkbox lines. Add a small rule, for example "first line matching `^- \[ \] [0-9]+(\.[0-9]+)* (.+)$`; skip malformed unchecked lines", or explicitly allow any unchecked Markdown task line.

### Malformed JSON handling is specified but not represented in implementation tasks
**File**: openspec/changes/bootstrap-orbit-status-cli/tasks.md:35
**Description**: The output spec now requires malformed `.orbit-runs/*.json` files to warn and be treated as absent, but the JSON-ingestion task group only covers listing/sorting/extracting fields. The address-reviews summary also flagged this ripple. Add an implementation task for parse-failure handling so apply/codegen does not miss the non-fatal warning behavior.

### Large task list could use apply chunk boundaries
**File**: openspec/changes/bootstrap-orbit-status-cli/tasks.md:1
**Description**: The proposal has 76 tasks across 18 groups. That is manageable, but applying it in one pass risks partial implementation or shallow tests. Add a short preamble naming natural chunks, such as scaffold, inventory/parsing, phase/recommendation engine, rendering, distribution docs, and validation fixtures.

### Design open questions should be explicitly accepted or resolved
**File**: openspec/changes/bootstrap-orbit-status-cli/design.md:167
**Description**: The design still carries three Open Questions at proposal time, including stale-review mtime granularity and whether `recent[]` needs an `--all` flag. If these are intentional apply-time decisions, mark them as deferred/non-blocking with expected defaults; otherwise resolve them before implementation so codegen does not make hidden product decisions.

## Notes

`openspec validate bootstrap-orbit-status-cli --strict` passes. I also swept for `@review:` marker residue; only explanatory/spec scenario mentions remain, not inline review markers.
