# Reference: address-reviews run-summary schema

Each `/opsx:address-reviews` invocation persists a JSON summary. Path varies:

- **Change-scoped** (when scope is a single change directory or `--from-file` points into a change's `.orbit-runs/`): `openspec/changes/<change-name>/.orbit-runs/address-reviews-<TS>.json`
- **Whole-repo / cross-change**: `openspec/.orbit-runs/address-reviews-<TS>.json`

## Schema

```json
{
  "command": "address-reviews",
  "timestamp": "<ISO-8601>",
  "source": "whole-repo" | "scope" | "from-file",
  "source_path": "<scope path or --from-file path or null>",
  "external_reviewer": "<from --from-file's Reviewer field, if applicable, else null>",
  "input_findings_summary": {
    "critical": 0,
    "warning": 0,
    "suggestion": 0
  },
  "pushback_verification": "<short note: how many findings verified against current state; how many stale>",
  "resolution_summary": {
    "resolved": 0,
    "stale_suppressed": 0,
    "deferred": 0,
    "escalated": 0
  },
  "resolutions": [
    {
      "severity": "CRITICAL" | "WARNING" | "SUGGESTION",
      "title": "<finding title>",
      "marker_source": "inline" | "external",
      "file": "<path>",
      "line": 41,
      "classification": "trivial_fix" | "decision_required" | "stale" | "unresolvable",
      "action": "<what was done — applied edit, filed as task, converted to @todo:, escalated, etc.>",
      "files_updated": ["<paths edited as part of the resolution>"],
      "ripple_flagged": ["<paths flagged for sibling consistency, not edited>"],
      "outcome": "resolved" | "stale" | "deferred" | "escalated"
    }
  ],
  "remaining_markers_in_scope": 0,
  "persisted_escalations": [
    { "file": "...", "line": 0, "title": "...", "reason": "..." }
  ],
  "next_recommended": "<suggested next command, e.g., 're-run /opsx:review --as proposal to confirm convergence'>"
}
```

## Field notes

- **`source`** distinguishes invocation paths: `whole-repo` for default scan, `scope` for positional `<scope>` argument, `from-file` for `--from-file <path>`.
- **`source_path`** carries the scope or file path; `null` for `whole-repo`.
- **`external_reviewer`** parsed from the `**Reviewer**:` field in the `--from-file` input; lets downstream tools track which AI's findings have been ingested.
- **`input_findings_summary`** counts findings by severity at the input boundary (before pushback suppression). Total findings always = sum of `resolved` + `stale_suppressed` + `deferred` + `escalated` in `resolution_summary`.
- **`pushback_verification`** is a short prose note (1-2 sentences) summarizing pushback work — "all 9 findings verified against current state; 0 stale suppressions" or "9 findings; 3 stale-suppressed with commit evidence."
- **`marker_source`** distinguishes inline `@review:` markers (grep-found) from external virtual markers (parsed from `--from-file`).
- **`classification`** is the pushback-and-classify outcome before action.
- **`outcome`** is the final disposition; aligns with the ✓ Resolved / ⚠ Stale / ⏸ Deferred / ✗ Escalated counts in the resolution log.
- **`persisted_escalations`** captures `@review(escalated):` markers deliberately left in place; mirrors the resolution log's escalated section so downstream queries don't re-parse the log.
- **`next_recommended`** is the closing suggestion shown in the final-assessment line.
