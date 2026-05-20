# External Review: bootstrap-orbit-status-cli (system mode, iteration 1)

**Reviewer**: GPT-5 Codex
**Date**: 2026-05-20

## CRITICAL

None.

## WARNING

### Latest run selection sorts by command prefix instead of embedded timestamp
**File**: .claude/skills/openspec-status/bin/opsx-status:285
**Description**: `list_orbit_runs` pipes full `.orbit-runs/*.json` paths through plain `sort`, and `latest_orbit_run` then takes `tail -1`. That sorts by the whole filename, including command prefixes, not by the ISO timestamp embedded in the filename as required by the phase and recommendation specs. In this repo's own run history, `opsx-status --json --detail` selects `.orbit-runs/review-system-2026-05-20T14-43-09Z.json` even though `.orbit-runs/address-reviews-2026-05-20T14-50-11Z.json` is later, because `review-*` sorts after `address-reviews-*`. The result is a stale `focus.recommended_next` that still talks about addressing the internal system review's two warnings instead of the later address-reviews close-out recommendation. Parse the timestamp suffix from each run basename, sort on that normalized timestamp across all command types, and add a regression fixture with mixed `review-*` and `address-reviews-*` prefixes.

### Phase freshness uses JSON file mtime instead of the run timestamp
**File**: .claude/skills/openspec-status/bin/opsx-status:480
**Description**: `infer_phase` compares `mtime_epoch "$latest"` to `tasks.md` mtime, but the spec says rule 2 is based on the JSON's embedded timestamp/filename timestamp being newer than `tasks.md`. Filesystem mtimes are not stable provenance: a clone, copy, checkout, or touch can make an old review JSON file newer than `tasks.md` on disk. I reproduced this with `review-system-2026-05-20T09-00-00Z.json`, `tasks.md` touched at 10:00, and the JSON file mtime touched at 11:00; the CLI emitted phase `reviewing` and recommended `/opsx:archive work stale` instead of falling through to the partial-task `applying` state. Parse the run timestamp from the filename or validated JSON field for freshness comparisons, then compare that semantic run time to the artifact mtime.

### Default human summary omits last-touched time
**File**: .claude/skills/openspec-status/bin/opsx-status:1080
**Description**: The output spec requires the default primary-change summary line to cover task progress, attention counts, and last-touched relative time. The human renderer currently builds the primary line only from `ptasks` and `pattn`, so a normal default view can show `75/79 tasks` or `75/79 tasks + 1 attention` without any touched-time segment. That makes the default view drift from the documented contract and weakens the "what was I doing last?" workflow orientation. Include a relative time derived from `primary_record.last_touched` in the primary line, and cover the default human output in tests so this does not regress silently.

## SUGGESTION

None.

## Notes

No baseline specs exist in `openspec/specs/`, so Pass 1 had no baseline to check against. `openspec/lenses/perspectives.md` and `openspec/lenses/critical-paths.md` are absent, so Passes 4 and 5 were skipped as instructed. Validation run during this review: `git pull` (already up to date), `openspec validate bootstrap-orbit-status-cli --strict`, `bash -n .claude/skills/openspec-status/bin/opsx-status tests/run.sh`, and `tests/run.sh` (93 passed, 0 failed). Drift checks for the 1186-line claim, 4-rule tier-2 wording, `/opsx:verify` wording, and the "Applying-ing" residue did not surface additional findings.
